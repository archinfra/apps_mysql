# StatefulSet PVC reconciliation extensions. Loaded after rendering modules.

apply_mysql_manifests() {
  require_manifest_file "${MYSQL_MANIFEST}"

  local desired_storage_size="${STORAGE_SIZE}"
  local existing_template_size=""
  existing_template_size="$(kubectl get statefulset -n "${NAMESPACE}" "${STS_NAME}" \
    -o 'jsonpath={.spec.volumeClaimTemplates[0].spec.resources.requests.storage}' 2>/dev/null || true)"

  if [[ -n "${existing_template_size}" ]]; then
    # volumeClaimTemplates is immutable on an existing StatefulSet. Render the
    # existing template size and handle an explicitly requested PVC expansion
    # against the PVC object itself after the StatefulSet reconcile succeeds.
    STORAGE_SIZE="${existing_template_size}"
  fi

  render_manifest "${MYSQL_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
  STORAGE_SIZE="${desired_storage_size}"

  if [[ -z "${existing_template_size}" || "${STORAGE_SIZE_EXPLICIT}" != "true" ]]; then
    return 0
  fi

  local pvc_name current_pvc_size
  pvc_name="data-${STS_NAME}-0"
  current_pvc_size="$(kubectl get pvc -n "${NAMESPACE}" "${pvc_name}" \
    -o 'jsonpath={.spec.resources.requests.storage}' 2>/dev/null || true)"

  if [[ -z "${current_pvc_size}" ]]; then
    warn "未找到 PVC/${pvc_name}，跳过显式存储扩容"
    return 0
  fi

  if [[ "${current_pvc_size}" == "${desired_storage_size}" ]]; then
    return 0
  fi

  log "请求扩容 PVC/${pvc_name}: ${current_pvc_size} -> ${desired_storage_size}"
  if ! kubectl patch pvc -n "${NAMESPACE}" "${pvc_name}" --type=merge \
    -p "{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"${desired_storage_size}\"}}}}" >/dev/null; then
    die "PVC/${pvc_name} 调整到 ${desired_storage_size} 失败。Kubernetes PVC 不支持缩容；扩容还要求 StorageClass.allowVolumeExpansion=true。"
  fi

  success "PVC/${pvc_name} 已提交扩容请求: ${desired_storage_size}"
}

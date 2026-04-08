docker_login() {
  log "登录镜像仓库 ${REGISTRY_ADDR}"
  if echo "${REGISTRY_PASS}" | docker login "${REGISTRY_ADDR}" -u "${REGISTRY_USER}" --password-stdin >/dev/null 2>&1; then
    success "镜像仓库登录成功"
  else
    warn "镜像仓库登录失败，继续尝试后续流程"
  fi
}


payload_signature() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$0" | awk '{print $1}'
    return 0
  fi

  cksum "$0" | awk '{print $1 "-" $2}'
}


payload_start_offset() {
  if [[ -n "${PAYLOAD_OFFSET:-}" ]]; then
    printf '%s' "${PAYLOAD_OFFSET}"
    return 0
  fi

  local marker_line payload_offset skip_bytes byte_hex
  marker_line="$(awk '/^__PAYLOAD_BELOW__$/ { print NR; exit }' "$0")"
  [[ -n "${marker_line}" ]] || die "未找到载荷标记"
  payload_offset="$(( $(head -n "${marker_line}" "$0" | wc -c | tr -d ' ') + 1 ))"

  skip_bytes=0
  while :; do
    byte_hex="$(dd if="$0" bs=1 skip="$((payload_offset + skip_bytes - 1))" count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    case "${byte_hex}" in
      0a|0d)
        skip_bytes=$((skip_bytes + 1))
        ;;
      "")
        die "载荷边界异常，未找到有效的压缩数据"
        ;;
      *)
        break
        ;;
    esac
  done

  PAYLOAD_OFFSET="$((payload_offset + skip_bytes))"
  printf '%s' "${PAYLOAD_OFFSET}"
}


payload_extract_entries() {
  local destination="$1"
  shift

  local payload_offset
  payload_offset="$(payload_start_offset)"
  tail -c +"${payload_offset}" "$0" | tar -xz -C "${destination}" "$@" >/dev/null 2>&1
}


payload_signature_file() {
  printf '%s/.payload-signature' "${WORKDIR}"
}


payload_cache_ready() {
  local expected_signature="$1"
  local signature_file
  signature_file="$(payload_signature_file)"

  [[ -f "${signature_file}" ]] || return 1
  [[ "$(cat "${signature_file}")" == "${expected_signature}" ]] || return 1
  [[ -f "${IMAGE_JSON}" ]] || return 1
}


ensure_image_archive_available() {
  local tar_name="$1"
  local tar_path="${IMAGE_DIR}/${tar_name}"

  if [[ -f "${tar_path}" ]]; then
    return 0
  fi

  log "按需解压镜像归档 ${tar_name}"
  payload_extract_entries "${WORKDIR}" "./images/${tar_name}" || die "解压镜像归档失败: ${tar_name}"
  [[ -f "${tar_path}" ]] || die "解压后仍未找到镜像归档 ${tar_name}"
}


docker_image_exists() {
  docker image inspect "$1" >/dev/null 2>&1
}


resolve_target_image_tag() {
  local source_tag="$1"
  local suffix="${source_tag#*/kube4/}"

  if [[ "${suffix}" == "${source_tag}" ]]; then
    suffix="${source_tag##*/}"
  fi

  printf '%s/%s' "${REGISTRY_REPO}" "${suffix}"
}


prepare_images() {
  [[ "${SKIP_IMAGE_PREPARE}" == "true" ]] && {
    warn "已按要求跳过镜像导入与推送"
    return 0
  }

  section "准备离线镜像"
  docker_login

  local count=0
  while IFS= read -r item; do
    [[ -n "${item}" ]] || continue

    local tar_name image_tag target_tag tar_path
    tar_name="$(jq -r '.tar' <<<"${item}")"
    image_tag="$(jq -r '.tag // .pull' <<<"${item}")"
    target_tag="$(resolve_target_image_tag "${image_tag}")"
    tar_path="${IMAGE_DIR}/${tar_name}"

    image_needed_for_current_action "${image_tag}" || continue

    if docker_image_exists "${target_tag}"; then
      log "复用本地镜像 ${target_tag}"
    else
      if docker_image_exists "${image_tag}"; then
        log "复用本地镜像 ${image_tag}"
      else
        ensure_image_archive_available "${tar_name}"
        log "导入镜像归档 ${tar_name}"
        docker load -i "${tar_path}" >/dev/null
      fi

      if [[ "${target_tag}" != "${image_tag}" ]]; then
        log "重打标签 ${image_tag} -> ${target_tag}"
        docker tag "${image_tag}" "${target_tag}"
      fi
    fi

    log "推送镜像 ${target_tag}"
    docker push "${target_tag}" >/dev/null
    count=$((count + 1))
  done < <(jq -c '.[]' "${IMAGE_JSON}")

  (( count > 0 )) || die "载荷中未发现可导入的镜像归档"
  success "已准备 ${count} 个镜像归档"
}


ensure_namespace() {
  if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    return 0
  fi
  log "创建命名空间 ${NAMESPACE}"
  kubectl create namespace "${NAMESPACE}" >/dev/null
}


render_optional_block() {
  local feature_name="$1"
  local enabled="$2"

  awk \
    -v start_marker="#__${feature_name}_START__" \
    -v end_marker="#__${feature_name}_END__" \
    -v enabled="${enabled}" '
      {
        marker=$0
        sub(/^[[:space:]]+/, "", marker)
      }
      marker == start_marker { skip=(enabled != "true"); next }
      marker == end_marker { skip=0; next }
      !skip { print }
    '
}


render_feature_blocks() {
  local file_path="$1"
  local nodeport_enabled="${NODEPORT_ENABLED}"

  cat "${file_path}" \
    | render_optional_block "FEATURE_MONITORING" "${MONITORING_ENABLED}" \
    | render_optional_block "FEATURE_SERVICE_MONITOR" "${SERVICE_MONITOR_ENABLED}" \
    | render_optional_block "FEATURE_FLUENTBIT" "${FLUENTBIT_ENABLED}" \
    | render_optional_block "FEATURE_NODEPORT" "${nodeport_enabled}"
}


render_manifest() {
  local file_path="$1"
  render_feature_blocks "${file_path}" | template_replace
}


apply_mysql_manifests() {
  require_manifest_file "${MYSQL_MANIFEST}"
  render_manifest "${MYSQL_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_monitoring_addon_manifests() {
  require_manifest_file "${MONITORING_ADDON_MANIFEST}"
  render_manifest "${MONITORING_ADDON_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


cleanup_disabled_optional_resources() {
  if [[ "${MONITORING_ENABLED}" != "true" ]]; then
    kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${METRICS_SERVICE_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${SERVICE_MONITOR_ENABLED}" != "true" ]] && cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${FLUENTBIT_ENABLED}" != "true" ]]; then
    kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${FLUENTBIT_CONFIGMAP}" >/dev/null 2>&1 || true
  fi

  delete_legacy_backup_resources
}


extract_payload() {
  section "解压安装载荷"
  local expected_signature signature_file
  expected_signature="$(payload_signature)"
  signature_file="$(payload_signature_file)"

  if payload_cache_ready "${expected_signature}"; then
    success "复用已解压载荷缓存"
    return 0
  fi

  rm -rf "${WORKDIR}"
  mkdir -p "${WORKDIR}" "${IMAGE_DIR}" "${MANIFEST_DIR}"

  log "正在解压元数据到 ${WORKDIR}"
  payload_extract_entries "${WORKDIR}" "./manifests" "./images/image.json" || die "解压载荷元数据失败"

  [[ -f "${IMAGE_JSON}" ]] || die "缺少 image.json"

  printf '%s\n' "${expected_signature}" > "${signature_file}"
  success "载荷元数据解压完成"
}


image_needed_for_current_action() {
  local image_tag="$1"

  case "${ACTION}" in
    install)
      if [[ "${image_tag}" == */mysql:* || "${image_tag}" == */busybox:* ]]; then
        return 0
      fi
      if [[ "${MONITORING_ENABLED}" == "true" && "${image_tag}" == */mysqld-exporter:* ]]; then
        return 0
      fi
      if [[ "${FLUENTBIT_ENABLED}" == "true" && "${image_tag}" == */fluent-bit:* ]]; then
        return 0
      fi
      return 1
      ;;
    addon-install)
      if addon_selected monitoring && [[ "${image_tag}" == */mysql:* || "${image_tag}" == */mysqld-exporter:* ]]; then
        return 0
      fi
      return 1
      ;;
    benchmark)
      if [[ "${image_tag}" == */mysql:* || "${image_tag}" == */sysbench:* ]]; then
        return 0
      fi
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}


template_replace() {
  sed \
    -e "s#__APP_NAME__#${APP_NAME}#g" \
    -e "s#__NAMESPACE__#${NAMESPACE}#g" \
    -e "s#__MYSQL_REPLICAS__#${MYSQL_REPLICAS}#g" \
    -e "s#__STORAGE_CLASS__#${STORAGE_CLASS}#g" \
    -e "s#__STORAGE_SIZE__#${STORAGE_SIZE}#g" \
    -e "s#__MYSQL_ROOT_PASSWORD__#${MYSQL_ROOT_PASSWORD}#g" \
    -e "s#__SERVICE_NAME__#${SERVICE_NAME}#g" \
    -e "s#__STS_NAME__#${STS_NAME}#g" \
    -e "s#__AUTH_SECRET__#${AUTH_SECRET}#g" \
    -e "s#__PROBE_CONFIGMAP__#${PROBE_CONFIGMAP}#g" \
    -e "s#__INIT_CONFIGMAP__#${INIT_CONFIGMAP}#g" \
    -e "s#__MYSQL_CONFIGMAP__#${MYSQL_CONFIGMAP}#g" \
    -e "s#__NODEPORT_SERVICE_NAME__#${NODEPORT_SERVICE_NAME}#g" \
    -e "s#__NODE_PORT__#${NODE_PORT}#g" \
    -e "s#__METRICS_SERVICE_NAME__#${METRICS_SERVICE_NAME}#g" \
    -e "s#__METRICS_PORT__#${METRICS_PORT}#g" \
    -e "s#__SERVICE_MONITOR_NAME__#${SERVICE_MONITOR_NAME}#g" \
    -e "s#__SERVICE_MONITOR_INTERVAL__#${SERVICE_MONITOR_INTERVAL}#g" \
    -e "s#__SERVICE_MONITOR_SCRAPE_TIMEOUT__#${SERVICE_MONITOR_SCRAPE_TIMEOUT}#g" \
    -e "s#__ADDON_EXPORTER_DEPLOYMENT_NAME__#${ADDON_EXPORTER_DEPLOYMENT_NAME}#g" \
    -e "s#__ADDON_EXPORTER_SERVICE_NAME__#${ADDON_EXPORTER_SERVICE_NAME}#g" \
    -e "s#__ADDON_EXPORTER_SECRET__#${ADDON_EXPORTER_SECRET}#g" \
    -e "s#__ADDON_EXPORTER_USERNAME__#${ADDON_EXPORTER_USERNAME}#g" \
    -e "s#__ADDON_EXPORTER_PASSWORD__#${ADDON_EXPORTER_PASSWORD}#g" \
    -e "s#__ADDON_MONITORING_TARGET__#${ADDON_MONITORING_TARGET}#g" \
    -e "s#__ADDON_SERVICE_MONITOR_NAME__#${ADDON_SERVICE_MONITOR_NAME}#g" \
    -e "s#__FLUENTBIT_CONFIGMAP__#${FLUENTBIT_CONFIGMAP}#g" \
    -e "s#__MYSQL_SLOW_QUERY_TIME__#${MYSQL_SLOW_QUERY_TIME}#g" \
    -e "s#__MYSQL_HOST__#${MYSQL_HOST}#g" \
    -e "s#__MYSQL_PORT__#${MYSQL_PORT}#g" \
    -e "s#__MYSQL_USER__#${MYSQL_USER}#g" \
    -e "s#__MYSQL_AUTH_SECRET__#${MYSQL_AUTH_SECRET}#g" \
    -e "s#__MYSQL_PASSWORD_KEY__#${MYSQL_PASSWORD_KEY}#g" \
    -e "s#__MYSQL_IMAGE__#${MYSQL_IMAGE}#g" \
    -e "s#__MYSQL_EXPORTER_IMAGE__#${MYSQL_EXPORTER_IMAGE}#g" \
    -e "s#__FLUENTBIT_IMAGE__#${FLUENTBIT_IMAGE}#g" \
    -e "s#__BUSYBOX_IMAGE__#${BUSYBOX_IMAGE}#g" \
    -e "s#__SYSBENCH_IMAGE__#${SYSBENCH_IMAGE}#g" \
    -e "s#__BENCHMARK_JOB_NAME__#${BENCHMARK_JOB_NAME:-mysql-benchmark}#g" \
    -e "s#__BENCHMARK_CONCURRENCY__#${BENCHMARK_THREADS}#g" \
    -e "s#__BENCHMARK_THREADS__#${BENCHMARK_THREADS}#g" \
    -e "s#__BENCHMARK_TIME__#${BENCHMARK_TIME}#g" \
    -e "s#__BENCHMARK_WARMUP_TIME__#${BENCHMARK_WARMUP_TIME}#g" \
    -e "s#__BENCHMARK_WARMUP_ROWS__#${BENCHMARK_WARMUP_ROWS}#g" \
    -e "s#__BENCHMARK_TABLES__#${BENCHMARK_TABLES}#g" \
    -e "s#__BENCHMARK_TABLE_SIZE__#${BENCHMARK_TABLE_SIZE}#g" \
    -e "s#__BENCHMARK_DB__#${BENCHMARK_DB}#g" \
    -e "s#__BENCHMARK_RAND_TYPE__#${BENCHMARK_RAND_TYPE}#g" \
    -e "s#__BENCHMARK_KEEP_DATA__#${BENCHMARK_KEEP_DATA}#g" \
    -e "s#__BENCHMARK_PROFILE__#${BENCHMARK_PROFILE}#g"
}


require_manifest_file() {
  local file_path="$1"
  [[ -f "${file_path}" ]] || die "当前产物包缺少必需 manifest: ${file_path}"
}


apply_benchmark_job() {
  require_manifest_file "${BENCHMARK_MANIFEST}"
  render_manifest "${BENCHMARK_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}

delete_pvcs_if_requested() {
  [[ "${DELETE_PVC}" == "true" ]] || return 0

  log "删除 StatefulSet/${STS_NAME} 关联 PVC"
  mapfile -t pvcs < <(kubectl get pvc -n "${NAMESPACE}" -o name | grep "^persistentvolumeclaim/data-${STS_NAME}-" || true)
  if [[ ${#pvcs[@]} -eq 0 ]]; then
    return 0
  fi
  kubectl delete -n "${NAMESPACE}" "${pvcs[@]}" >/dev/null || true
}


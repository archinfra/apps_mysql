ensure_namespace() {
  if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    return 0
  fi
  log "创建命名空间 ${NAMESPACE}"
  kubectl create namespace "${NAMESPACE}" >/dev/null
}


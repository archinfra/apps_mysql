namespace_exists() {
  kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1
}


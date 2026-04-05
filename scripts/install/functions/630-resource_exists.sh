resource_exists() {
  local kind="$1"
  local name="$2"
  kubectl get "${kind}" "${name}" -n "${NAMESPACE}" >/dev/null 2>&1
}


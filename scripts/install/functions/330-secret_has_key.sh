secret_has_key() {
  local secret_name="$1"
  local key_name="$2"
  kubectl get secret -n "${NAMESPACE}" "${secret_name}" -o "jsonpath={.data.${key_name}}" >/dev/null 2>&1
}


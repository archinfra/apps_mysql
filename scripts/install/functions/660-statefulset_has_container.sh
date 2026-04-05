statefulset_has_container() {
  local container_name="$1"
  local containers
  containers="$(kubectl get statefulset "${STS_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[*].name}' 2>/dev/null || true)"
  [[ " ${containers} " == *" ${container_name} "* ]]
}


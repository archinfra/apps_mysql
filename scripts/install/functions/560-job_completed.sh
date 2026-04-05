job_completed() {
  local job_name="$1"
  kubectl get job -n "${NAMESPACE}" "${job_name}" -o "jsonpath={range .status.conditions[*]}{.type}={.status}{'\n'}{end}" 2>/dev/null \
    | grep -q '^Complete=True$'
}


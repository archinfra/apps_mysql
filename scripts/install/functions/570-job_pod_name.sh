job_pod_name() {
  local job_name="$1"
  kubectl get pod -n "${NAMESPACE}" -l "job-name=${job_name}" -o "jsonpath={.items[0].metadata.name}" 2>/dev/null || true
}


job_pod_summary() {
  local pod_name="$1"
  kubectl get pod -n "${NAMESPACE}" "${pod_name}" \
    -o "jsonpath={.status.phase}{' | init='}{range .status.initContainerStatuses[*]}{.name}:{.ready}:{.state.waiting.reason}{.state.terminated.reason}{' '}{end}{'| main='}{range .status.containerStatuses[*]}{.name}:{.ready}:{.state.waiting.reason}{.state.terminated.reason}{' '}{end}" 2>/dev/null || true
}


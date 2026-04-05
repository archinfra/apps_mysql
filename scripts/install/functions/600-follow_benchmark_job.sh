follow_benchmark_job() {
  local job_name="$1"
  local pod_name="" last_summary="" last_prepare_logs="" last_benchmark_logs=""

  while true; do
    if job_completed "${job_name}" || job_failed "${job_name}"; then
      return 0
    fi

    pod_name="$(job_pod_name "${job_name}")"
    if [[ -n "${pod_name}" ]]; then
      local summary prepare_logs benchmark_logs
      summary="$(job_pod_summary "${pod_name}")"
      if [[ -n "${summary}" && "${summary}" != "${last_summary}" ]]; then
        log "压测 Pod 状态 ${pod_name} ${summary}"
        last_summary="${summary}"
      fi

      prepare_logs="$(kubectl logs -n "${NAMESPACE}" "pod/${pod_name}" -c mysql-prepare --tail=10 2>/dev/null || true)"
      if [[ -n "${prepare_logs}" && "${prepare_logs}" != "${last_prepare_logs}" ]]; then
        echo "${prepare_logs}"
        last_prepare_logs="${prepare_logs}"
      fi

      benchmark_logs="$(kubectl logs -n "${NAMESPACE}" "pod/${pod_name}" -c mysql-benchmark --tail=10 2>/dev/null || true)"
      if [[ -n "${benchmark_logs}" && "${benchmark_logs}" != "${last_benchmark_logs}" ]]; then
        echo "${benchmark_logs}"
        last_benchmark_logs="${benchmark_logs}"
      fi
    fi

    sleep 5
  done
}
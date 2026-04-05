create_benchmark_job() {
  local benchmark_job_name="mysql-benchmark-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建压测 Job ${benchmark_job_name}" >&2
  BENCHMARK_JOB_NAME="${benchmark_job_name}" render_manifest "${BENCHMARK_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${benchmark_job_name}"
}


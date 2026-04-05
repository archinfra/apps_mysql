wait_for_job() {
  local job_name="$1"
  local job_mode="${2:-generic}"
  local timeout_value progress_pid=""

  timeout_value="$(job_wait_timeout "${job_mode}")"

  log "等待 Job/${job_name} 完成"
  if [[ "${job_mode}" == "benchmark" ]]; then
    echo "压测目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
    echo "压测账号                : ${MYSQL_USER}"
    echo "压测 Profile            : ${BENCHMARK_PROFILE}"
    echo "压测并发                : ${BENCHMARK_THREADS}"
    echo "压测时长(秒)            : ${BENCHMARK_TIME}"
    echo "Warmup(秒)              : ${BENCHMARK_WARMUP_TIME}"
    echo "压测表数                : ${BENCHMARK_TABLES}"
    echo "每表数据量              : ${BENCHMARK_TABLE_SIZE}"
    echo "实时日志命令            : kubectl logs -n ${NAMESPACE} -f job/${job_name}"
    echo "状态观察命令            : kubectl get pod -n ${NAMESPACE} -l job-name=${job_name} -w"
    echo "等待超时                : ${timeout_value}"
    follow_benchmark_job "${job_name}" &
    progress_pid=$!
  fi

  if kubectl wait --for=condition=complete "job/${job_name}" -n "${NAMESPACE}" --timeout="${timeout_value}" >/dev/null 2>&1; then
    stop_background_task "${progress_pid}"
    success "Job/${job_name} 已完成"
    return 0
  fi

  stop_background_task "${progress_pid}"
  if job_failed "${job_name}"; then
    warn "Job/${job_name} 执行失败，输出日志如下"
    kubectl logs -n "${NAMESPACE}" "job/${job_name}" --tail=-1 || true
    local pod_name
    pod_name="$(job_pod_name "${job_name}")"
    if [[ -n "${pod_name}" ]]; then
      echo
      kubectl describe pod -n "${NAMESPACE}" "${pod_name}" || true
    fi
    return 1
  fi

  if [[ "${job_mode}" == "benchmark" ]]; then
    warn "压测在等待上限 ${timeout_value} 内未结束，但 Job 仍可能在运行"
    echo "继续查看日志            : kubectl logs -n ${NAMESPACE} -f job/${job_name}"
    echo "继续查看状态            : kubectl get pod -n ${NAMESPACE} -l job-name=${job_name} -w"
    kubectl get job -n "${NAMESPACE}" "${job_name}" || true
    local pod_name
    pod_name="$(job_pod_name "${job_name}")"
    if [[ -n "${pod_name}" ]]; then
      kubectl get pod -n "${NAMESPACE}" "${pod_name}" -o wide || true
    fi
    return 1
  fi

  warn "Job/${job_name} 未正常完成，输出日志如下"
  kubectl logs -n "${NAMESPACE}" "job/${job_name}" --tail=-1 || true
  return 1
}


wait_for_statefulset_ready() {
  log "等待 StatefulSet/${STS_NAME} 就绪"
  kubectl rollout status "statefulset/${STS_NAME}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}"
}


mysql_pod_name() {
  echo "${STS_NAME}-0"
}


wait_for_mysql_ready() {
  local pod_name
  pod_name="$(mysql_pod_name)"

  log "等待 Pod/${pod_name} Ready"
  kubectl wait --for=condition=ready "pod/${pod_name}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}" >/dev/null

  log "等待 MySQL 接受连接"
  local retries=60
  local attempt
  for (( attempt=1; attempt<=retries; attempt++ )); do
    if kubectl exec -n "${NAMESPACE}" "${pod_name}" -- env MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysqladmin -uroot ping >/dev/null 2>&1; then
      success "MySQL 已就绪"
      return 0
    fi
    sleep 5
  done

  die "MySQL 在超时时间内未就绪"
}


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


job_wait_timeout() {
  local job_mode="${1:-generic}"
  local profile_count prepare_buffer cleanup_buffer safety_buffer total_seconds data_points

  if [[ "${job_mode}" != "benchmark" || "${WAIT_TIMEOUT_EXPLICIT}" == "true" ]]; then
    printf '%s' "${WAIT_TIMEOUT}"
    return 0
  fi

  case "${BENCHMARK_PROFILE}" in
    standard)
      profile_count=3
      ;;
    *)
      profile_count=1
      ;;
  esac

  data_points=$((BENCHMARK_TABLES * BENCHMARK_TABLE_SIZE))
  prepare_buffer=$(((data_points + 1499) / 1500))
  if (( prepare_buffer < 120 )); then
    prepare_buffer=120
  fi
  cleanup_buffer=120
  safety_buffer=180
  total_seconds=$((profile_count * (BENCHMARK_TIME + BENCHMARK_WARMUP_TIME) + prepare_buffer + cleanup_buffer + safety_buffer))
  if (( total_seconds < 1800 )); then
    total_seconds=1800
  fi

  printf '%ss' "${total_seconds}"
}

job_failed() {
  local job_name="$1"
  kubectl get job -n "${NAMESPACE}" "${job_name}" -o "jsonpath={range .status.conditions[*]}{.type}={.status}{'\n'}{end}" 2>/dev/null \
    | grep -q '^Failed=True$'
}


job_completed() {
  local job_name="$1"
  kubectl get job -n "${NAMESPACE}" "${job_name}" -o "jsonpath={range .status.conditions[*]}{.type}={.status}{'\n'}{end}" 2>/dev/null \
    | grep -q '^Complete=True$'
}


job_pod_name() {
  local job_name="$1"
  kubectl get pod -n "${NAMESPACE}" -l "job-name=${job_name}" -o "jsonpath={.items[0].metadata.name}" 2>/dev/null || true
}


job_pod_summary() {
  local pod_name="$1"
  kubectl get pod -n "${NAMESPACE}" "${pod_name}" \
    -o "jsonpath={.status.phase}{' | init='}{range .status.initContainerStatuses[*]}{.name}:{.ready}:{.state.waiting.reason}{.state.terminated.reason}{' '}{end}{'| main='}{range .status.containerStatuses[*]}{.name}:{.ready}:{.state.waiting.reason}{.state.terminated.reason}{' '}{end}" 2>/dev/null || true
}


stop_background_task() {
  local task_pid="${1:-}"
  if [[ -n "${task_pid}" ]] && kill -0 "${task_pid}" >/dev/null 2>&1; then
    kill "${task_pid}" >/dev/null 2>&1 || true
    wait "${task_pid}" >/dev/null 2>&1 || true
  fi
}


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

ensure_report_dir() {
  mkdir -p "${REPORT_DIR}"
}


write_report() {
  local report_name="$1"
  local body="$2"
  ensure_report_dir
  local report_path="${REPORT_DIR}/${report_name}"
  printf '%s\n' "${body}" > "${report_path}"
  echo "${report_path}"
}


resource_exists() {
  local kind="$1"
  local name="$2"
  kubectl get "${kind}" "${name}" -n "${NAMESPACE}" >/dev/null 2>&1
}


namespace_exists() {
  kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1
}


require_namespace_exists() {
  namespace_exists || die "未找到命名空间 ${NAMESPACE}"
}


statefulset_has_container() {
  local container_name="$1"
  local containers
  containers="$(kubectl get statefulset "${STS_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[*].name}' 2>/dev/null || true)"
  [[ " ${containers} " == *" ${container_name} "* ]]
}


ensure_statefulset_exists() {
  kubectl get statefulset "${STS_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1 || die "未找到 StatefulSet/${STS_NAME}，请先确认 MySQL 已存在"
}


sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}


ensure_addon_exporter_user() {
  local exporter_user exporter_password
  exporter_user="$(sql_escape "${ADDON_EXPORTER_USERNAME}")"
  exporter_password="$(sql_escape "${ADDON_EXPORTER_PASSWORD}")"

  section "补齐监控账号"
  mysql_exec "CREATE USER IF NOT EXISTS '${exporter_user}'@'%' IDENTIFIED BY '${exporter_password}';"
  mysql_exec "GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${exporter_user}'@'%';"
  mysql_exec "FLUSH PRIVILEGES;"
  success "监控账号已就绪"
}


delete_external_monitoring_resources() {
  kubectl delete deployment -n "${NAMESPACE}" --ignore-not-found "${ADDON_EXPORTER_DEPLOYMENT_NAME}" >/dev/null 2>&1 || true
  kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${ADDON_EXPORTER_SERVICE_NAME}" >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "${ADDON_EXPORTER_SECRET}" >/dev/null 2>&1 || true
}


current_mysql_password() {
  if [[ -n "${MYSQL_PASSWORD}" ]]; then
    printf '%s' "${MYSQL_PASSWORD}"
    return 0
  fi

  kubectl get secret -n "${NAMESPACE}" "${MYSQL_AUTH_SECRET}" -o "jsonpath={.data.${MYSQL_PASSWORD_KEY}}" | base64 -d
}


mysql_exec() {
  local sql="$1"
  local password runner_name
  password="$(current_mysql_password)"
  runner_name="mysql-client-$(date +%s)-$RANDOM"

  kubectl run "${runner_name}" \
    -n "${NAMESPACE}" \
    --image="${MYSQL_IMAGE}" \
    --restart=Never \
    --env="MYSQL_PWD=${password}" \
    --env="MYSQL_HOST=${MYSQL_HOST}" \
    --env="MYSQL_PORT=${MYSQL_PORT}" \
    --env="MYSQL_USER=${MYSQL_USER}" \
    --env="SQL_QUERY=${sql}" \
    --command -- /bin/sh -lc \
    'mysql --host="${MYSQL_HOST}" --port="${MYSQL_PORT}" --protocol=TCP --user="${MYSQL_USER}" -Nse "$SQL_QUERY"' >/dev/null

  if ! kubectl wait -n "${NAMESPACE}" --for=jsonpath='{.status.phase}'=Succeeded "pod/${runner_name}" --timeout="${WAIT_TIMEOUT}" >/dev/null 2>&1; then
    kubectl logs -n "${NAMESPACE}" "pod/${runner_name}" --tail=-1 || true
    kubectl delete pod -n "${NAMESPACE}" --ignore-not-found "${runner_name}" >/dev/null 2>&1 || true
    die "临时 MySQL 客户端 Pod/${runner_name} 执行失败"
  fi

  local result
  result="$(kubectl logs -n "${NAMESPACE}" "pod/${runner_name}" --tail=-1 || true)"
  kubectl delete pod -n "${NAMESPACE}" --ignore-not-found "${runner_name}" >/dev/null 2>&1 || true
  printf '%s' "${result}"
}

preflight_mysql_connection() {
  local phase="${1:-预检 MySQL 连接}"

  section "${phase}"
  mysql_exec "SELECT 1;" >/dev/null
  success "MySQL 连接预检通过"
}


secret_has_key() {
  local secret_name="$1"
  local key_name="$2"
  kubectl get secret -n "${NAMESPACE}" "${secret_name}" -o "jsonpath={.data.${key_name}}" >/dev/null 2>&1
}


runtime_action_requires_explicit_mysql_auth() {
  [[ "${ACTION}" == "benchmark" ]]
}


prepare_runtime_auth_secret() {
  action_needs_mysql_auth || return 0

  if [[ -n "${MYSQL_PASSWORD}" ]]; then
    kubectl create secret generic "${MYSQL_AUTH_SECRET}" \
      -n "${NAMESPACE}" \
      --from-literal="${MYSQL_PASSWORD_KEY}=${MYSQL_PASSWORD}" \
      --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    return 0
  fi

  if secret_has_key "${MYSQL_AUTH_SECRET}" "${MYSQL_PASSWORD_KEY}"; then
    return 0
  fi

  if runtime_action_requires_explicit_mysql_auth; then
    die "当前动作要求显式提供可用的 MySQL 凭据，请传 --mysql-password，或提供已存在的 --mysql-auth-secret/--mysql-password-key"
  fi

  if [[ "${MYSQL_ROOT_PASSWORD_EXPLICIT}" == "true" && "${MYSQL_AUTH_SECRET}" == "${AUTH_SECRET}" && "${MYSQL_PASSWORD_KEY}" == "mysql-root-password" ]]; then
    warn "未找到 Secret/${MYSQL_AUTH_SECRET}，将使用显式传入的 --root-password 创建"
    kubectl create secret generic "${MYSQL_AUTH_SECRET}" \
      -n "${NAMESPACE}" \
      --from-literal="${MYSQL_PASSWORD_KEY}=${MYSQL_ROOT_PASSWORD}" \
      --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    return 0
  fi

  die "命名空间 ${NAMESPACE} 中未找到 Secret/${MYSQL_AUTH_SECRET} 的键 ${MYSQL_PASSWORD_KEY}，请显式传 --mysql-password，或指定正确的 --mysql-auth-secret/--mysql-password-key"
}


prompt_missing_values() {
  :
}


validate_environment() {
  command -v kubectl >/dev/null 2>&1 || die "未找到 kubectl"

  if action_needs_image_prepare && [[ "${SKIP_IMAGE_PREPARE}" != "true" ]]; then
    command -v docker >/dev/null 2>&1 || die "未找到 docker"
  fi
}


validate_inputs() {
  [[ "${NODEPORT_ENABLED}" =~ ^(true|false)$ ]] || die "--nodeport-enabled 仅支持 true 或 false"

  if [[ "${ACTION}" != "addon-status" ]]; then
    [[ "${MYSQL_REPLICAS}" =~ ^[0-9]+$ ]] || die "mysql 副本数必须是数字"
    if [[ "${NODEPORT_ENABLED}" == "true" ]]; then
      [[ "${NODE_PORT}" =~ ^[0-9]+$ ]] || die "nodePort 必须是数字"
      (( NODE_PORT >= 30000 && NODE_PORT <= 32767 )) || die "nodePort 必须在 30000-32767 之间"
    fi
  fi

  [[ "${MYSQL_PORT}" =~ ^[0-9]+$ ]] || die "MySQL 端口必须是数字"
  [[ "${BENCHMARK_THREADS}" =~ ^[0-9]+$ ]] || die "压测线程数必须是数字"
  [[ "${BENCHMARK_TIME}" =~ ^[0-9]+$ ]] || die "压测时长必须是数字"
  [[ "${BENCHMARK_WARMUP_TIME}" =~ ^[0-9]+$ ]] || die "压测 warmup 时长必须是数字"
  [[ "${BENCHMARK_WARMUP_ROWS}" =~ ^[0-9]+$ ]] || die "压测 warmup 数据量必须是数字"
  [[ "${BENCHMARK_TABLES}" =~ ^[0-9]+$ ]] || die "压测表数必须是数字"
  [[ "${BENCHMARK_TABLE_SIZE}" =~ ^[0-9]+$ ]] || die "压测单表数据量必须是数字"
  [[ "${MYSQL_SLOW_QUERY_TIME}" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "慢查询阈值必须是数字"
  [[ "${BENCHMARK_PROFILE}" =~ ^(standard|oltp-point-select|oltp-read-only|oltp-read-write)$ ]] || die "benchmark-profile 仅支持 standard、oltp-point-select、oltp-read-only、oltp-read-write"

  validate_action_feature_gates
}


mysql_auth_source_summary() {
  if [[ -n "${MYSQL_PASSWORD}" ]]; then
    echo "显式密码参数"
  else
    echo "Secret/${MYSQL_AUTH_SECRET}:${MYSQL_PASSWORD_KEY}"
  fi
}


print_plan() {
  section "执行计划"
  echo "动作                    : ${ACTION}"
  echo "产物包                  : $(package_profile_label)"
  echo "命名空间                : ${NAMESPACE}"
  echo "等待超时                : ${WAIT_TIMEOUT}"

  case "${ACTION}" in
    install)
      echo "StatefulSet             : ${STS_NAME}"
      echo "服务名                  : ${SERVICE_NAME}"
      echo "NodePort 开关           : ${NODEPORT_ENABLED}"
      if [[ "${NODEPORT_ENABLED}" == "true" ]]; then
        echo "NodePort 服务名         : ${NODEPORT_SERVICE_NAME}"
        echo "NodePort                : ${NODE_PORT}"
      fi
      echo "副本数                  : ${MYSQL_REPLICAS}"
      echo "StorageClass            : ${STORAGE_CLASS}"
      echo "存储大小                : ${STORAGE_SIZE}"
      echo "镜像前缀                : ${REGISTRY_REPO}"
      echo "监控 exporter           : ${MONITORING_ENABLED}"
      echo "ServiceMonitor          : ${SERVICE_MONITOR_ENABLED}"
      echo "Fluent Bit sidecar      : ${FLUENTBIT_ENABLED}"
      echo "慢日志阈值(秒)           : ${MYSQL_SLOW_QUERY_TIME}"
      echo "业务影响                : install 会整体对齐 StatefulSet，配置变化时可能触发滚动更新"
      ;;
    addon-install|addon-uninstall)
      echo "Addon 列表              : ${ADDONS}"
      echo "业务影响                : 默认只新增或删除外置资源，不修改 MySQL StatefulSet"
      if addon_selected monitoring; then
        echo "监控目标                : ${ADDON_MONITORING_TARGET}"
        echo "监控账号                : ${ADDON_EXPORTER_USERNAME}"
        echo "建账认证来源            : $(mysql_auth_source_summary)"
      fi
      ;;
    benchmark)
      echo "执行模式                : 工程化压测 Job"
      echo "压测目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
      echo "压测账号                : ${MYSQL_USER}"
      echo "认证来源                : $(mysql_auth_source_summary)"
      echo "压测模型                : ${BENCHMARK_PROFILE}"
      echo "压测线程数              : ${BENCHMARK_THREADS}"
      echo "正式压测时长(秒)        : ${BENCHMARK_TIME}"
      echo "Warmup 时长(秒)         : ${BENCHMARK_WARMUP_TIME}"
      echo "Warmup 数据量/表        : ${BENCHMARK_WARMUP_ROWS}"
      echo "压测表数                : ${BENCHMARK_TABLES}"
      echo "正式数据量/表           : ${BENCHMARK_TABLE_SIZE}"
      echo "压测数据库              : ${BENCHMARK_DB}"
      echo "随机分布                : ${BENCHMARK_RAND_TYPE}"
      echo "保留测试数据            : ${BENCHMARK_KEEP_DATA}"
      echo "报告目录                : ${REPORT_DIR}"
      echo "自动等待超时            : $(job_wait_timeout benchmark)"
      ;;
  esac
}


confirm_plan() {
  [[ "${AUTO_YES}" == "true" ]] && return 0
  print_plan
  echo
  echo -ne "${YELLOW}确认继续执行？[y/N]:${NC} "
  read -r answer
  [[ "${answer}" =~ ^[Yy]$ ]] || die "用户取消执行"
}

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


apply_resource_profile() {
  case "${RESOURCE_PROFILE,,}" in
    low)
      RESOURCE_PROFILE="low"
      MYSQL_REQUEST_CPU="200m"
      MYSQL_REQUEST_MEM="512Mi"
      MYSQL_LIMIT_CPU="500m"
      MYSQL_LIMIT_MEM="1Gi"
      MYSQL_EXPORTER_REQUEST_CPU="50m"
      MYSQL_EXPORTER_REQUEST_MEM="64Mi"
      MYSQL_EXPORTER_LIMIT_CPU="100m"
      MYSQL_EXPORTER_LIMIT_MEM="128Mi"
      FLUENTBIT_REQUEST_CPU="50m"
      FLUENTBIT_REQUEST_MEM="64Mi"
      FLUENTBIT_LIMIT_CPU="100m"
      FLUENTBIT_LIMIT_MEM="128Mi"
      MYSQL_INIT_REQUEST_CPU="20m"
      MYSQL_INIT_REQUEST_MEM="32Mi"
      MYSQL_INIT_LIMIT_CPU="100m"
      MYSQL_INIT_LIMIT_MEM="64Mi"
      ;;
    mid|midd|middle|medium)
      RESOURCE_PROFILE="mid"
      MYSQL_REQUEST_CPU="500m"
      MYSQL_REQUEST_MEM="1Gi"
      MYSQL_LIMIT_CPU="1"
      MYSQL_LIMIT_MEM="2Gi"
      MYSQL_EXPORTER_REQUEST_CPU="100m"
      MYSQL_EXPORTER_REQUEST_MEM="128Mi"
      MYSQL_EXPORTER_LIMIT_CPU="200m"
      MYSQL_EXPORTER_LIMIT_MEM="256Mi"
      FLUENTBIT_REQUEST_CPU="100m"
      FLUENTBIT_REQUEST_MEM="128Mi"
      FLUENTBIT_LIMIT_CPU="200m"
      FLUENTBIT_LIMIT_MEM="256Mi"
      MYSQL_INIT_REQUEST_CPU="50m"
      MYSQL_INIT_REQUEST_MEM="64Mi"
      MYSQL_INIT_LIMIT_CPU="200m"
      MYSQL_INIT_LIMIT_MEM="128Mi"
      ;;
    high)
      RESOURCE_PROFILE="high"
      MYSQL_REQUEST_CPU="1"
      MYSQL_REQUEST_MEM="2Gi"
      MYSQL_LIMIT_CPU="2"
      MYSQL_LIMIT_MEM="4Gi"
      MYSQL_EXPORTER_REQUEST_CPU="200m"
      MYSQL_EXPORTER_REQUEST_MEM="256Mi"
      MYSQL_EXPORTER_LIMIT_CPU="500m"
      MYSQL_EXPORTER_LIMIT_MEM="512Mi"
      FLUENTBIT_REQUEST_CPU="200m"
      FLUENTBIT_REQUEST_MEM="256Mi"
      FLUENTBIT_LIMIT_CPU="500m"
      FLUENTBIT_LIMIT_MEM="512Mi"
      MYSQL_INIT_REQUEST_CPU="100m"
      MYSQL_INIT_REQUEST_MEM="128Mi"
      MYSQL_INIT_LIMIT_CPU="300m"
      MYSQL_INIT_LIMIT_MEM="256Mi"
      ;;
    *)
      die "resource-profile 仅支持 low|mid|midd|high"
      ;;
  esac
}


validate_environment() {
  command -v kubectl >/dev/null 2>&1 || die "未找到 kubectl"

  if action_needs_image_prepare && [[ "${SKIP_IMAGE_PREPARE}" != "true" ]]; then
    command -v docker >/dev/null 2>&1 || die "未找到 docker"
  fi
}


validate_inputs() {
  apply_resource_profile

  [[ "${NODEPORT_ENABLED}" =~ ^(true|false)$ ]] || die "--nodeport-enabled 只支持 true 或 false"
  [[ "${DATA_PROTECTION_ENABLED}" =~ ^(true|false)$ ]] || die "--enable-data-protection / --disable-data-protection only accepts boolean switches"

  if [[ "${ACTION}" != "addon-status" ]]; then
    [[ "${MYSQL_REPLICAS}" =~ ^[0-9]+$ ]] || die "mysql 副本数必须是数字"
    if [[ "${NODEPORT_ENABLED}" == "true" ]]; then
      [[ "${NODE_PORT}" =~ ^[0-9]+$ ]] || die "nodePort 必须是数字"
      (( NODE_PORT >= 30000 && NODE_PORT <= 32767 )) || die "nodePort 必须位于 30000-32767 之间"
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

  if [[ "${DATA_PROTECTION_ENABLED}" == "true" ]]; then
    [[ -n "${BACKUP_NAMESPACE}" ]] || die "--backup-namespace cannot be empty"
    [[ -n "${BACKUP_ADDON_NAME}" ]] || die "--backup-addon-name cannot be empty"
    [[ -n "${BACKUP_SOURCE_NAME}" ]] || die "--backup-source-name cannot be empty"
    [[ -n "${BACKUP_POLICY_NAME}" ]] || die "--backup-policy-name cannot be empty"
    [[ -n "${BACKUP_AUTH_SECRET}" ]] || die "--backup-auth-secret cannot be empty"
    [[ -n "${BACKUP_PRIMARY_STORAGE_NAME}" ]] || die "--backup-storage-name cannot be empty"
    [[ -n "${BACKUP_RETENTION_REF}" ]] || die "--backup-retention-ref cannot be empty"
    [[ -n "${BACKUP_SCHEDULE}" ]] || die "--backup-schedule cannot be empty"
  fi

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
      echo "Resource profile        : ${RESOURCE_PROFILE}"
      echo "存储大小                : ${STORAGE_SIZE}"
      echo "镜像前缀                : ${REGISTRY_REPO}"
      echo "监控 exporter           : ${MONITORING_ENABLED}"
      echo "ServiceMonitor          : ${SERVICE_MONITOR_ENABLED}"
      echo "Fluent Bit sidecar      : ${FLUENTBIT_ENABLED}"
      echo "Data protection         : ${DATA_PROTECTION_ENABLED}"
      if [[ "${DATA_PROTECTION_ENABLED}" == "true" ]]; then
        echo "Backup namespace        : ${BACKUP_NAMESPACE}"
        echo "Backup source           : ${BACKUP_SOURCE_NAME}"
        echo "Backup policy           : ${BACKUP_POLICY_NAME}"
        echo "Primary backup storage  : ${BACKUP_PRIMARY_STORAGE_NAME}"
        if [[ -n "${BACKUP_SECONDARY_STORAGE_NAME}" ]]; then
          echo "Secondary backup store  : ${BACKUP_SECONDARY_STORAGE_NAME}"
        fi
        echo "Backup retention        : ${BACKUP_RETENTION_REF}"
        echo "Backup schedule         : ${BACKUP_SCHEDULE}"
        if [[ -n "${BACKUP_NOTIFICATION_REF}" ]]; then
          echo "Backup notification     : ${BACKUP_NOTIFICATION_REF}"
        fi
        if [[ -n "${BACKUP_DATABASE}" ]]; then
          echo "Backup database         : ${BACKUP_DATABASE}"
        fi
      fi
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

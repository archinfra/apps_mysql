parse_args() {
  if [[ $# -eq 0 ]]; then
    ACTION="help"
    HELP_TOPIC="overview"
    return 0
  fi

  case "$1" in
    help)
      ACTION="help"
      shift
      if [[ $# -gt 0 ]]; then
        HELP_TOPIC="$1"
        shift
      fi
      [[ $# -eq 0 ]] || die "help 仅支持一个主题参数"
      return 0
      ;;
    -h|--help)
      ACTION="help"
      HELP_TOPIC="overview"
      shift
      [[ $# -eq 0 ]] || die "--help 不接受其他参数，请使用 help <主题>"
      return 0
      ;;
  esac

  while [[ $# -gt 0 ]]; do
    case "$1" in
      install|uninstall|status|addon-install|addon-uninstall|addon-status|benchmark)
        ACTION="$1"
        shift
        ;;
      -n|--namespace)
        NAMESPACE="$2"
        shift 2
        ;;
      --mysql-replicas)
        MYSQL_REPLICAS="$2"
        shift 2
        ;;
      --storage-class)
        STORAGE_CLASS="$2"
        shift 2
        ;;
      --storage-size)
        STORAGE_SIZE="$2"
        shift 2
        ;;
      --resource-profile)
        RESOURCE_PROFILE="$2"
        shift 2
        ;;
      --root-password)
        MYSQL_ROOT_PASSWORD="$2"
        MYSQL_ROOT_PASSWORD_EXPLICIT="true"
        shift 2
        ;;
      --auth-secret)
        AUTH_SECRET="$2"
        shift 2
        ;;
      --service-name)
        SERVICE_NAME="$2"
        shift 2
        ;;
      --addons)
        ADDONS="$2"
        shift 2
        ;;
      --sts-name)
        STS_NAME="$2"
        shift 2
        ;;
      --nodeport-service-name)
        NODEPORT_SERVICE_NAME="$2"
        shift 2
        ;;
      --node-port)
        NODE_PORT="$2"
        shift 2
        ;;
      --nodeport-enabled)
        NODEPORT_ENABLED="$2"
        shift 2
        ;;
      --enable-nodeport)
        NODEPORT_ENABLED="true"
        shift
        ;;
      --disable-nodeport)
        NODEPORT_ENABLED="false"
        shift
        ;;
      --registry)
        REGISTRY_REPO="$2"
        REGISTRY_ADDR="${2%%/*}"
        MYSQL_IMAGE="${REGISTRY_REPO}/mysql:8.0.45"
        MYSQL_EXPORTER_IMAGE="${REGISTRY_REPO}/mysqld-exporter:v0.15.1"
        FLUENTBIT_IMAGE="${REGISTRY_REPO}/fluent-bit:3.0.7"
        BUSYBOX_IMAGE="${REGISTRY_REPO}/busybox:v1"
        SYSBENCH_IMAGE="${REGISTRY_REPO}/sysbench:1.0.20-oe2403sp1"
        shift 2
        ;;
      --mysql-host)
        MYSQL_HOST="$2"
        MYSQL_HOST_EXPLICIT="true"
        shift 2
        ;;
      --mysql-port)
        MYSQL_PORT="$2"
        shift 2
        ;;
      --mysql-user)
        MYSQL_USER="$2"
        shift 2
        ;;
      --mysql-password)
        MYSQL_PASSWORD="$2"
        MYSQL_PASSWORD_EXPLICIT="true"
        shift 2
        ;;
      --mysql-auth-secret)
        MYSQL_AUTH_SECRET="$2"
        MYSQL_AUTH_SECRET_EXPLICIT="true"
        shift 2
        ;;
      --mysql-password-key)
        MYSQL_PASSWORD_KEY="$2"
        MYSQL_PASSWORD_KEY_EXPLICIT="true"
        shift 2
        ;;
      --enable-monitoring)
        MONITORING_ENABLED="true"
        shift
        ;;
      --disable-monitoring)
        MONITORING_ENABLED="false"
        shift
        ;;
      --enable-service-monitor)
        SERVICE_MONITOR_ENABLED="true"
        shift
        ;;
      --disable-service-monitor)
        SERVICE_MONITOR_ENABLED="false"
        shift
        ;;
      --enable-fluentbit)
        FLUENTBIT_ENABLED="true"
        shift
        ;;
      --disable-fluentbit)
        FLUENTBIT_ENABLED="false"
        shift
        ;;
      --mysql-slow-query-time)
        MYSQL_SLOW_QUERY_TIME="$2"
        shift 2
        ;;
      --exporter-user)
        ADDON_EXPORTER_USERNAME="$2"
        shift 2
        ;;
      --exporter-password)
        ADDON_EXPORTER_PASSWORD="$2"
        shift 2
        ;;
      --monitoring-target)
        ADDON_MONITORING_TARGET="$2"
        ADDON_MONITORING_TARGET_EXPLICIT="true"
        shift 2
        ;;
      --wait-timeout)
        WAIT_TIMEOUT="$2"
        WAIT_TIMEOUT_EXPLICIT="true"
        shift 2
        ;;
      --skip-image-prepare)
        SKIP_IMAGE_PREPARE="true"
        shift
        ;;
      --delete-pvc)
        DELETE_PVC="true"
        shift
        ;;
      --report-dir)
        REPORT_DIR="$2"
        shift 2
        ;;
      --benchmark-concurrency|--benchmark-threads)
        BENCHMARK_CONCURRENCY="$2"
        BENCHMARK_THREADS="$2"
        shift 2
        ;;
      --benchmark-iterations)
        BENCHMARK_ITERATIONS="$2"
        shift 2
        ;;
      --benchmark-queries)
        BENCHMARK_QUERIES="$2"
        shift 2
        ;;
      --benchmark-warmup-rows)
        BENCHMARK_WARMUP_ROWS="$2"
        shift 2
        ;;
      --benchmark-warmup-time)
        BENCHMARK_WARMUP_TIME="$2"
        shift 2
        ;;
      --benchmark-time)
        BENCHMARK_TIME="$2"
        shift 2
        ;;
      --benchmark-tables)
        BENCHMARK_TABLES="$2"
        shift 2
        ;;
      --benchmark-table-size)
        BENCHMARK_TABLE_SIZE="$2"
        shift 2
        ;;
      --benchmark-db)
        BENCHMARK_DB="$2"
        shift 2
        ;;
      --benchmark-rand-type)
        BENCHMARK_RAND_TYPE="$2"
        shift 2
        ;;
      --benchmark-keep-data)
        BENCHMARK_KEEP_DATA="true"
        shift
        ;;
      --benchmark-profile)
        BENCHMARK_PROFILE="$2"
        shift 2
        ;;
      --benchmark-host)
        MYSQL_HOST="$2"
        MYSQL_HOST_EXPLICIT="true"
        shift 2
        ;;
      --benchmark-port)
        MYSQL_PORT="$2"
        shift 2
        ;;
      --benchmark-user)
        MYSQL_USER="$2"
        shift 2
        ;;
      -y|--yes)
        AUTO_YES="true"
        shift
        ;;
      *)
        die "未知参数: $1"
        ;;
    esac
  done
}


normalize_addons() {
  local raw="${ADDONS:-}"
  local normalized=()
  local item trimmed current exists

  [[ -n "${raw}" ]] || die "动作 ${ACTION} 需要提供 --addons，例如 --addons monitoring,service-monitor"

  if [[ "${raw}" == "all" ]]; then
    raw="monitoring,service-monitor"
  fi

  IFS=',' read -r -a items <<<"${raw}"
  for item in "${items[@]}"; do
    trimmed="$(trim_string "${item}")"
    [[ -n "${trimmed}" ]] || continue

    case "${trimmed}" in
      monitoring|service-monitor)
        exists="false"
        for current in "${normalized[@]}"; do
          if [[ "${current}" == "${trimmed}" ]]; then
            exists="true"
            break
          fi
        done
        [[ "${exists}" == "true" ]] || normalized+=("${trimmed}")
        ;;
      *)
        die "不支持的 addon: ${trimmed}，当前仅支持 monitoring, service-monitor"
        ;;
    esac
  done

  (( ${#normalized[@]} > 0 )) || die "--addons 未提供有效内容"
  ADDONS="$(IFS=,; echo "${normalized[*]}")"
}


addon_selected() {
  local addon_name="$1"
  [[ ",${ADDONS}," == *",${addon_name},"* ]]
}


action_needs_image_prepare() {
  case "${ACTION}" in
    install|addon-install|benchmark)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}


action_needs_mysql_auth() {
  [[ "${ACTION}" == "benchmark" ]]
}


resolve_mysql_runtime_defaults() {
  local default_host="${STS_NAME}-0.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"

  if [[ -z "${MYSQL_HOST}" ]]; then
    MYSQL_HOST="${default_host}"
  fi

  if [[ -z "${MYSQL_AUTH_SECRET}" ]]; then
    if [[ "${MYSQL_PASSWORD_EXPLICIT}" == "true" ]]; then
      MYSQL_AUTH_SECRET="${MYSQL_RUNTIME_SECRET}"
    else
      MYSQL_AUTH_SECRET="${AUTH_SECRET}"
    fi
  fi

  if [[ -z "${MYSQL_PASSWORD_KEY}" ]]; then
    if [[ "${MYSQL_AUTH_SECRET}" == "${AUTH_SECRET}" ]]; then
      MYSQL_PASSWORD_KEY="mysql-root-password"
    else
      MYSQL_PASSWORD_KEY="password"
    fi
  fi

  if [[ -z "${ADDON_MONITORING_TARGET}" ]]; then
    ADDON_MONITORING_TARGET="${MYSQL_HOST}:${MYSQL_PORT}"
  fi

  if [[ "${BENCHMARK_TIME}" == "180" && "${BENCHMARK_ITERATIONS}" != "3" ]]; then
    BENCHMARK_TIME="$((BENCHMARK_ITERATIONS * 60))"
  fi
}


cluster_supports_service_monitor() {
  kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1
}


resolve_feature_dependencies() {
  resolve_mysql_runtime_defaults

  if [[ "${MONITORING_ENABLED}" != "true" && "${SERVICE_MONITOR_ENABLED}" == "true" ]]; then
    warn "monitoring 已关闭，因此自动关闭 ServiceMonitor"
    SERVICE_MONITOR_ENABLED="false"
  fi

  if [[ "${ACTION}" == "addon-install" || "${ACTION}" == "addon-uninstall" ]]; then
    normalize_addons
    SERVICE_MONITOR_ENABLED="false"

    if addon_selected service-monitor && ! addon_selected monitoring && [[ "${ACTION}" == "addon-install" ]]; then
      warn "service-monitor 依赖 monitoring，已自动补齐 monitoring"
      ADDONS="monitoring,${ADDONS}"
      normalize_addons
    fi

    if addon_selected monitoring && ! addon_selected service-monitor && [[ "${ACTION}" == "addon-uninstall" ]]; then
      ADDONS="${ADDONS},service-monitor"
      normalize_addons
    fi

    if addon_selected service-monitor; then
      SERVICE_MONITOR_ENABLED="true"
    fi
  fi
}


validate_action_feature_gates() {
  package_profile_supports_action "${ACTION}" || die "当前产物包(${PACKAGE_PROFILE})不支持动作 ${ACTION}，可用动作: $(package_profile_supported_actions_text)"

  case "${ACTION}" in
    addon-install|addon-uninstall)
      [[ -n "${ADDONS}" ]] || die "动作 ${ACTION} 需要提供 --addons"
      local addon_name
      IFS=',' read -r -a requested_addons <<< "${ADDONS}"
      for addon_name in "${requested_addons[@]}"; do
        addon_name="$(trim_string "${addon_name}")"
        [[ -n "${addon_name}" ]] || continue
        package_profile_supports_addon "${addon_name}" || die "当前产物包(${PACKAGE_PROFILE})不支持 addon ${addon_name}"
      done
      ;;
  esac
}

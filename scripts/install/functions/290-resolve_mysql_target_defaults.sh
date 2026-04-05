resolve_mysql_target_defaults() {
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

  if [[ -z "${MYSQL_TARGET_NAME}" ]]; then
    if [[ "${MYSQL_HOST_EXPLICIT}" == "true" ]]; then
      MYSQL_TARGET_NAME="$(sanitize_target_name "${MYSQL_HOST}")"
    else
      MYSQL_TARGET_NAME="${STS_NAME}"
    fi
  fi

  if [[ -z "${ADDON_MONITORING_TARGET}" ]]; then
    ADDON_MONITORING_TARGET="${MYSQL_HOST}:${MYSQL_PORT}"
  fi

  if [[ -z "${BENCHMARK_HOST}" ]]; then
    BENCHMARK_HOST="${MYSQL_HOST}"
  fi
  if [[ -z "${BENCHMARK_PORT}" ]]; then
    BENCHMARK_PORT="${MYSQL_PORT}"
  fi
  if [[ -z "${BENCHMARK_USER}" ]]; then
    BENCHMARK_USER="${MYSQL_USER}"
  fi

  if [[ "${BENCHMARK_TIME}" == "180" && "${BENCHMARK_ITERATIONS}" != "3" ]]; then
    BENCHMARK_TIME="$((BENCHMARK_ITERATIONS * 60))"
  fi
}
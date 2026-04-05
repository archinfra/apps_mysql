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
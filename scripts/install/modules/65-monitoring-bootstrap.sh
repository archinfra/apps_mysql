# Monitoring bootstrap extensions loaded after 60-runtime.sh.
# This override keeps existing PVC upgrades safe when embedded mysqld-exporter
# switches from root credentials to the dedicated least-privilege account.

validate_single_instance_mode() {
  if [[ "${ACTION}" == "install" && "${MYSQL_REPLICAS}" != "1" ]]; then
    die "apps_mysql v1.6.0 当前只支持单实例交付；--mysql-replicas 必须为 1。多副本 StatefulSet 不等于 MySQL HA。"
  fi
}


ensure_embedded_exporter_user() {
  [[ "${MONITORING_ENABLED}" == "true" ]] || return 0

  local pod_name root_password exporter_user exporter_password sql
  pod_name="$(mysql_pod_name)"
  root_password="$(kubectl get secret -n "${NAMESPACE}" "${AUTH_SECRET}" -o 'jsonpath={.data.mysql-root-password}' | base64 --decode)"
  exporter_user="$(sql_escape "${ADDON_EXPORTER_USERNAME}")"
  exporter_password="$(sql_escape "${ADDON_EXPORTER_PASSWORD}")"

  sql="CREATE USER IF NOT EXISTS '${exporter_user}'@'%' IDENTIFIED BY '${exporter_password}'; ALTER USER '${exporter_user}'@'%' IDENTIFIED BY '${exporter_password}' WITH MAX_USER_CONNECTIONS 3; GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${exporter_user}'@'%'; FLUSH PRIVILEGES;"

  log "确保内嵌 mysqld-exporter 低权限账号存在"
  kubectl exec -n "${NAMESPACE}" "${pod_name}" -- \
    env MYSQL_PWD="${root_password}" mysql -uroot -Nse "${sql}" >/dev/null
  success "mysqld-exporter 监控账号已就绪"
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
    local root_password
    root_password="$(kubectl get secret -n "${NAMESPACE}" "${AUTH_SECRET}" -o 'jsonpath={.data.mysql-root-password}' 2>/dev/null | base64 --decode || true)"
    if [[ -n "${root_password}" ]] && kubectl exec -n "${NAMESPACE}" "${pod_name}" -- env MYSQL_PWD="${root_password}" mysqladmin -uroot ping >/dev/null 2>&1; then
      ensure_embedded_exporter_user
      success "MySQL 已就绪"
      return 0
    fi
    sleep 5
  done

  die "MySQL 在超时时间内未就绪"
}

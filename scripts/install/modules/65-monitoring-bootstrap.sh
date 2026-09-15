# Runtime/bootstrap extensions loaded after 60-runtime.sh.

validate_single_instance_mode() {
  if [[ "${ACTION}" == "install" && "${MYSQL_REPLICAS}" != "1" ]]; then
    die "apps_mysql v1.6.0 仅支持单实例交付；--mysql-replicas 必须为 1。多副本 StatefulSet 不等于 MySQL HA。"
  fi

  if [[ -z "${ADDON_EXPORTER_PASSWORD}" ]]; then
    ADDON_EXPORTER_PASSWORD="$(generate_mysql_password)"
  fi
}


generate_mysql_password() {
  if [[ -r /dev/urandom ]]; then
    od -An -N24 -tx1 /dev/urandom | tr -d ' \n'
    return 0
  fi
  printf 'mysql-%s-%s' "$(date +%s)" "$RANDOM$RANDOM"
}


ensure_install_root_password() {
  [[ "${ACTION}" == "install" ]] || return 0

  if [[ "${MYSQL_ROOT_PASSWORD_EXPLICIT}" == "true" && -n "${MYSQL_ROOT_PASSWORD}" ]]; then
    return 0
  fi

  local existing=""
  existing="$(kubectl get secret -n "${NAMESPACE}" "${AUTH_SECRET}" -o 'jsonpath={.data.mysql-root-password}' 2>/dev/null | base64 --decode || true)"
  if [[ -n "${existing}" ]]; then
    MYSQL_ROOT_PASSWORD="${existing}"
    log "复用 Secret/${AUTH_SECRET} 中已有 root 密码"
    return 0
  fi

  MYSQL_ROOT_PASSWORD="$(generate_mysql_password)"
  warn "未显式提供 --root-password，已自动生成随机 root 密码并写入 Secret/${AUTH_SECRET}"
}


apply_mysql_runtime_config() {
  require_manifest_file "${MYSQL_RUNTIME_CONFIG_MANIFEST}"
  section "Apply MySQL 8.4 Runtime Configuration"
  render_manifest "${MYSQL_RUNTIME_CONFIG_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f - >/dev/null
  success "MySQL runtime ConfigMap 已对齐"
}


cleanup_legacy_local_users() {
  local pod_name root_password
  pod_name="$(mysql_pod_name)"
  root_password="$(kubectl get secret -n "${NAMESPACE}" "${AUTH_SECRET}" -o 'jsonpath={.data.mysql-root-password}' | base64 --decode)"

  kubectl exec -n "${NAMESPACE}" "${pod_name}" -- env MYSQL_PWD="${root_password}" mysql -uroot -Nse \
    "DROP USER IF EXISTS 'localroot'@'localhost'; DROP USER IF EXISTS 'mysqlhealthchecker'@'localhost'; FLUSH PRIVILEGES;" >/dev/null 2>&1 || true
}


reconcile_remote_root_user() {
  local pod_name root_password root_host escaped_password escaped_host sql
  pod_name="$(mysql_pod_name)"
  root_password="$(kubectl get secret -n "${NAMESPACE}" "${AUTH_SECRET}" -o 'jsonpath={.data.mysql-root-password}' | base64 --decode)"
  root_host="${ROOT_REMOTE_HOST}"
  escaped_password="$(sql_escape "${root_password}")"
  escaped_host="$(sql_escape "${root_host}")"

  if [[ "${REMOTE_ROOT_ENABLED}" == "true" ]]; then
    if [[ "${MYSQL_NATIVE_PASSWORD_ENABLED}" == "true" ]]; then
      sql="CREATE USER IF NOT EXISTS 'root'@'${escaped_host}' IDENTIFIED WITH mysql_native_password BY '${escaped_password}'; ALTER USER 'root'@'${escaped_host}' IDENTIFIED WITH mysql_native_password BY '${escaped_password}'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'${escaped_host}' WITH GRANT OPTION;"
    else
      sql="CREATE USER IF NOT EXISTS 'root'@'${escaped_host}' IDENTIFIED BY '${escaped_password}'; ALTER USER 'root'@'${escaped_host}' IDENTIFIED BY '${escaped_password}'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'${escaped_host}' WITH GRANT OPTION;"
    fi

    if [[ "${root_host}" != "%" ]]; then
      sql+=" DROP USER IF EXISTS 'root'@'%';"
    fi
    sql+=" FLUSH PRIVILEGES;"

    log "对齐远程 root 账号 root@${root_host}"
    kubectl exec -n "${NAMESPACE}" "${pod_name}" -- env MYSQL_PWD="${root_password}" mysql -uroot -Nse "${sql}" >/dev/null
    success "远程 root 账号已按交付策略对齐"
    return 0
  fi

  sql="DROP USER IF EXISTS 'root'@'%';"
  if [[ -n "${root_host}" && "${root_host}" != "%" ]]; then
    sql+=" DROP USER IF EXISTS 'root'@'${escaped_host}';"
  fi
  sql+=" FLUSH PRIVILEGES;"

  log "关闭安装器管理的远程 root 账号"
  kubectl exec -n "${NAMESPACE}" "${pod_name}" -- env MYSQL_PWD="${root_password}" mysql -uroot -Nse "${sql}" >/dev/null
  success "远程 root 已关闭"
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
  kubectl exec -n "${NAMESPACE}" "${pod_name}" -- env MYSQL_PWD="${root_password}" mysql -uroot -Nse "${sql}" >/dev/null
  success "mysqld-exporter 监控账号已就绪"
}


wait_for_mysql_ready() {
  local pod_name
  pod_name="$(mysql_pod_name)"

  log "等待 Pod/${pod_name} Ready"
  kubectl wait --for=condition=ready "pod/${pod_name}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}" >/dev/null

  log "等待 MySQL 接受连接"
  local retries=120 attempt root_password
  for (( attempt=1; attempt<=retries; attempt++ )); do
    root_password="$(kubectl get secret -n "${NAMESPACE}" "${AUTH_SECRET}" -o 'jsonpath={.data.mysql-root-password}' 2>/dev/null | base64 --decode || true)"
    if [[ -n "${root_password}" ]] && kubectl exec -n "${NAMESPACE}" "${pod_name}" -- env MYSQL_PWD="${root_password}" mysqladmin -uroot ping >/dev/null 2>&1; then
      cleanup_legacy_local_users
      reconcile_remote_root_user
      ensure_embedded_exporter_user
      success "MySQL 已就绪"
      return 0
    fi
    sleep 5
  done

  die "MySQL 在超时时间内未就绪"
}

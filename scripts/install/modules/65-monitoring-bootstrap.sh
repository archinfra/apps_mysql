# Runtime/bootstrap extensions loaded after 60-runtime.sh.

validate_single_instance_mode() {
  if [[ "${ACTION}" == "install" && "${MYSQL_REPLICAS}" != "1" ]]; then
    die "apps_mysql v1.6.0 仅支持单实例交付；--mysql-replicas 必须为 1。多副本 StatefulSet 不等于 MySQL HA。"
  fi

  # Keep --registry compatible with installers produced before the 8.4 LTS switch.
  case "${MYSQL_IMAGE}" in
    */mysql:8.0.45|*/mysql:8.0.46)
      MYSQL_IMAGE="${REGISTRY_REPO}/mysql:8.4.11"
      ;;
  esac

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

  # ConfigMap is mounted through subPath, so restart is required for deterministic config uptake.
  kubectl rollout restart "statefulset/${STS_NAME}" -n "${NAMESPACE}" >/dev/null
  success "MySQL runtime ConfigMap 已对齐并触发单实例滚动重启"
}


cleanup_legacy_local_users() {
  local pod_name root_password
  pod_name="$(mysql_pod_name)"
  root_password="$(kubectl get secret -n "${NAMESPACE}" "${AUTH_SECRET}" -o 'jsonpath={.data.mysql-root-password}' | base64 --decode)"

  kubectl exec -n "${NAMESPACE}" "${pod_name}" -- env MYSQL_PWD="${root_password}" mysql -uroot -Nse \
    "DROP USER IF EXISTS 'localroot'@'localhost'; DROP USER IF EXISTS 'mysqlhealthchecker'@'localhost'; FLUSH PRIVILEGES;" >/dev/null 2>&1 || true
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
  local retries=60 attempt root_password
  for (( attempt=1; attempt<=retries; attempt++ )); do
    root_password="$(kubectl get secret -n "${NAMESPACE}" "${AUTH_SECRET}" -o 'jsonpath={.data.mysql-root-password}' 2>/dev/null | base64 --decode || true)"
    if [[ -n "${root_password}" ]] && kubectl exec -n "${NAMESPACE}" "${pod_name}" -- env MYSQL_PWD="${root_password}" mysqladmin -uroot ping >/dev/null 2>&1; then
      cleanup_legacy_local_users
      ensure_embedded_exporter_user
      success "MySQL 已就绪"
      return 0
    fi
    sleep 5
  done

  die "MySQL 在超时时间内未就绪"
}

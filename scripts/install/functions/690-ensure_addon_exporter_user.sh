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


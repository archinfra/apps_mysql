install_app() {
  extract_payload
  prepare_images
  ensure_namespace

  if [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && ! cluster_supports_service_monitor; then
    warn "集群中未安装 ServiceMonitor CRD，本次跳过 ServiceMonitor 资源"
    SERVICE_MONITOR_ENABLED="false"
  fi

  section "安装 / 对齐 MySQL"
  apply_mysql_manifests
  if [[ "${BACKUP_ENABLED}" == "true" ]]; then
    apply_backup_support_manifests
    apply_backup_schedule_manifests
  else
    warn "当前关闭了备份组件，将清理 backup CronJob 及支持资源"
  fi
  cleanup_disabled_optional_resources
  wait_for_statefulset_ready
  wait_for_mysql_ready
  success "MySQL 安装/对齐完成"
}


show_addon_status() {
  local external_monitoring="未安装"
  local embedded_monitoring="未安装"
  local backup_addon="未安装"
  local embedded_logging="未安装"
  local addon_service_monitor="未安装"
  local embedded_service_monitor="未安装"

  require_namespace_exists

  resource_exists deployment "${ADDON_EXPORTER_DEPLOYMENT_NAME}" && external_monitoring="已安装"
  resource_exists cronjob "${BACKUP_CRONJOB_NAME}" && backup_addon="已安装"

  if resource_exists statefulset "${STS_NAME}"; then
    statefulset_has_container "mysqld-exporter" && embedded_monitoring="已安装"
    statefulset_has_container "fluent-bit" && embedded_logging="已安装"
  fi

  if cluster_supports_service_monitor; then
    resource_exists servicemonitor "${ADDON_SERVICE_MONITOR_NAME}" && addon_service_monitor="已安装"
    resource_exists servicemonitor "${SERVICE_MONITOR_NAME}" && embedded_service_monitor="已安装"
  else
    addon_service_monitor="集群未安装 CRD"
    embedded_service_monitor="集群未安装 CRD"
  fi

  section "Addon 状态"
  echo "外置 monitoring addon   : ${external_monitoring}"
  echo "内嵌 monitoring sidecar : ${embedded_monitoring}"
  echo "外置 ServiceMonitor     : ${addon_service_monitor}"
  echo "内嵌 ServiceMonitor     : ${embedded_service_monitor}"
  echo "backup addon            : ${backup_addon}"
  echo "Fluent Bit sidecar      : ${embedded_logging}"
  echo
  echo "推荐结论:"
  echo "1. 已有 MySQL 若补监控/备份，优先使用 addon-install，新资源以 Deployment/CronJob 形式补齐。"
  echo "2. 日志推荐接入平台级 DaemonSet 日志体系，不建议默认叠加 sidecar。"
  echo "3. 只有在必须采集容器内 slow log 文件时，才建议走 install --enable-fluentbit。"
}


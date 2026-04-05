install_addons() {
  extract_payload
  prepare_images
  ensure_namespace

  if addon_selected monitoring; then
    if resource_exists statefulset "${STS_NAME}" && statefulset_has_container "mysqld-exporter"; then
      die "当前 MySQL 已启用内嵌 exporter sidecar，不建议再叠加外置 monitoring addon"
    fi

    if addon_selected service-monitor && ! cluster_supports_service_monitor; then
      warn "集群中未安装 ServiceMonitor CRD，本次仅安装 monitoring addon，跳过 service-monitor"
      ADDONS="${ADDONS//service-monitor/}"
      ADDONS="${ADDONS//,,/,}"
      ADDONS="${ADDONS#,}"
      ADDONS="${ADDONS%,}"
      SERVICE_MONITOR_ENABLED="false"
    fi

    if ! resource_exists statefulset "${STS_NAME}" && [[ "${ADDON_MONITORING_TARGET_EXPLICIT}" != "true" ]]; then
      die "为已有外部 MySQL 安装 monitoring addon 时，请显式提供 --monitoring-target"
    fi

    if monitoring_bootstrap_auth_available; then
      ensure_addon_exporter_user
    else
      warn "未提供可写 MySQL 管理凭据，跳过 exporter 用户自动创建；请确保目标实例已存在 ${ADDON_EXPORTER_USERNAME} 账号"
    fi

    section "安装 monitoring addon"
    apply_monitoring_addon_manifests
    kubectl rollout status "deployment/${ADDON_EXPORTER_DEPLOYMENT_NAME}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}"
    success "monitoring addon 安装完成"
  fi

  if addon_selected backup; then
    if ! resource_exists statefulset "${STS_NAME}" && [[ "${MYSQL_HOST_EXPLICIT}" != "true" ]]; then
      die "为已有外部 MySQL 安装 backup addon 时，请显式提供 --mysql-host"
    fi

    apply_backup_support_manifests
    preflight_mysql_connection "预检 backup addon 目标连接"

    section "安装 backup addon"
    apply_backup_schedule_manifests
    success "backup addon 安装完成"
  fi
}
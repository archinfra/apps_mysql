monitoring_bootstrap_auth_available() {
  if [[ -n "${MYSQL_PASSWORD}" ]]; then
    return 0
  fi

  secret_has_key "${MYSQL_AUTH_SECRET}" "${MYSQL_PASSWORD_KEY}"
}


uninstall_addons() {
  require_namespace_exists

  if addon_selected service-monitor && cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${ADDON_SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi

  if addon_selected monitoring; then
    section "移除 monitoring addon"
    delete_external_monitoring_resources
    success "monitoring addon 已移除"
  fi
}


show_addon_status() {
  local external_monitoring="未安装"
  local embedded_monitoring="未安装"
  local embedded_logging="未安装"
  local addon_service_monitor="未安装"
  local embedded_service_monitor="未安装"

  require_namespace_exists

  resource_exists deployment "${ADDON_EXPORTER_DEPLOYMENT_NAME}" && external_monitoring="已安装"

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
  echo "Fluent Bit sidecar      : ${embedded_logging}"
  echo
  echo "推荐结论:"
  echo "1. 已有 MySQL 若补监控，优先使用 addon-install，新资源以 Deployment 形式补齐。"
  echo "2. 备份恢复已迁移到独立数据保护系统，不再通过 apps_mysql addon 管理。"
  echo "3. 日志推荐接入平台级 DaemonSet 日志体系，只有在必须采集 Pod 内慢日志文件时才开启 sidecar。"
}


show_status() {
  require_namespace_exists

  section "运行状态"
  kubectl get statefulset -n "${NAMESPACE}" || true
  echo
  kubectl get deployment -n "${NAMESPACE}" || true
  echo
  kubectl get pods -n "${NAMESPACE}" -o wide || true
  echo
  kubectl get svc -n "${NAMESPACE}" || true
  echo
  kubectl get pvc -n "${NAMESPACE}" || true
  echo
  if cluster_supports_service_monitor; then
    kubectl get servicemonitor -n "${NAMESPACE}" || true
    echo
  fi
  kubectl get jobs -n "${NAMESPACE}" || true
}


delete_pvcs_if_requested() {
  [[ "${DELETE_PVC}" == "true" ]] || return 0

  log "删除 StatefulSet/${STS_NAME} 关联 PVC"
  mapfile -t pvcs < <(kubectl get pvc -n "${NAMESPACE}" -o name | grep "^persistentvolumeclaim/data-${STS_NAME}-" || true)
  if [[ ${#pvcs[@]} -eq 0 ]]; then
    return 0
  fi
  kubectl delete -n "${NAMESPACE}" "${pvcs[@]}" >/dev/null || true
}


uninstall_app() {
  extract_payload
  section "卸载 MySQL"

  if ! cluster_supports_service_monitor; then
    SERVICE_MONITOR_ENABLED="false"
  fi

  render_manifest "${MYSQL_MANIFEST}" | kubectl delete -n "${NAMESPACE}" --ignore-not-found -f - >/dev/null || true
  delete_external_monitoring_resources
  delete_legacy_backup_resources
  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found "mysql-benchmark" >/dev/null 2>&1 || true
  kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${METRICS_SERVICE_NAME}" >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${FLUENTBIT_CONFIGMAP}" >/dev/null 2>&1 || true
  if cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${ADDON_SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi
  delete_pvcs_if_requested

  success "MySQL 卸载完成"
}


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
  cleanup_disabled_optional_resources
  wait_for_statefulset_ready
  wait_for_mysql_ready
  success "MySQL 安装/对齐完成"
}


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

    if ! resource_exists statefulset "${STS_NAME}" && [[ "${ADDON_MONITORING_TARGET_EXPLICIT}" != "true" && "${MYSQL_HOST_EXPLICIT}" != "true" ]]; then
      die "为已有外部 MySQL 安装 monitoring addon 时，请显式提供 --monitoring-target，或至少提供 --mysql-host/--mysql-port"
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
}

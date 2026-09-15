# MySQL 8.4 lifecycle overrides. Loaded after 70-lifecycle-actions.sh.

install_app() {
  extract_payload
  prepare_images
  ensure_namespace
  ensure_install_root_password
  sync_install_root_secret
  sync_embedded_exporter_secret

  if [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && ! cluster_supports_service_monitor; then
    warn "ServiceMonitor CRD is missing; skipping ServiceMonitor resources"
    SERVICE_MONITOR_ENABLED="false"
  fi

  if [[ "${PROMETHEUS_RULE_ENABLED}" == "true" ]] && ! cluster_supports_prometheus_rule; then
    warn "PrometheusRule CRD is missing; skipping PrometheusRule resources"
    PROMETHEUS_RULE_ENABLED="false"
  fi

  local existing_statefulset="false"
  if kubectl get statefulset -n "${NAMESPACE}" "${STS_NAME}" >/dev/null 2>&1; then
    existing_statefulset="true"
  fi

  section "Install Or Reconcile MySQL 8.4 LTS"
  # Runtime ConfigMaps and auth Secrets must exist before a new StatefulSet pod is created.
  apply_mysql_runtime_config
  apply_mysql_manifests
  apply_mysql_observability_manifests
  cleanup_disabled_optional_resources

  # ConfigMap is mounted through subPath. Existing pods need one deterministic restart.
  if [[ "${existing_statefulset}" == "true" ]]; then
    kubectl rollout restart "statefulset/${STS_NAME}" -n "${NAMESPACE}" >/dev/null
    log "MySQL runtime 配置已更新，触发单实例滚动重启"
  fi

  wait_for_statefulset_ready
  wait_for_mysql_ready
  install_data_protection_integration
  success "MySQL 8.4.11 LTS install/reconcile completed"
}


uninstall_app() {
  extract_payload
  require_namespace_exists
  section "Uninstall MySQL 8.4 LTS"

  # Explicit deletion keeps uninstall independent from the current install-time feature flags.
  kubectl delete statefulset -n "${NAMESPACE}" --ignore-not-found "${STS_NAME}" >/dev/null 2>&1 || true
  kubectl delete service -n "${NAMESPACE}" --ignore-not-found \
    "${SERVICE_NAME}" "${NODEPORT_SERVICE_NAME}" "${METRICS_SERVICE_NAME}" >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found \
    "${MYSQL_CONFIGMAP}" "${PROBE_CONFIGMAP}" "${FLUENTBIT_CONFIGMAP}" "${GRAFANA_DASHBOARD_NAME}" mysql-init-users >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "${ADDON_EXPORTER_SECRET}" >/dev/null 2>&1 || true

  delete_external_monitoring_resources
  delete_legacy_backup_resources
  uninstall_data_protection_integration

  if cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found \
      "${SERVICE_MONITOR_NAME}" "${ADDON_SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi
  if cluster_supports_prometheus_rule; then
    kubectl delete prometheusrule -n "${NAMESPACE}" --ignore-not-found \
      "${PROMETHEUS_RULE_NAME}" "${ADDON_PROMETHEUS_RULE_NAME}" >/dev/null 2>&1 || true
  fi

  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found mysql-benchmark >/dev/null 2>&1 || true

  if [[ "${DELETE_PVC}" == "true" ]]; then
    delete_pvcs_if_requested
    kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "${AUTH_SECRET}" >/dev/null 2>&1 || true
    success "MySQL workload、PVC 与 root Secret 已删除"
  else
    success "MySQL workload 已卸载；PVC 与 Secret/${AUTH_SECRET} 已保留，便于后续恢复同一数据目录"
  fi
}

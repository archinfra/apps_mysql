# MySQL 8.4 install override. Loaded after 70-lifecycle-actions.sh.

install_app() {
  extract_payload
  prepare_images
  ensure_namespace
  ensure_install_root_password

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
  # Runtime ConfigMaps must exist before a new StatefulSet pod is created.
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

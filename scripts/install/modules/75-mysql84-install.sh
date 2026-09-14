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

  section "Install Or Reconcile MySQL 8.4 LTS"
  apply_mysql_manifests
  apply_mysql_runtime_config
  cleanup_disabled_optional_resources
  wait_for_statefulset_ready
  wait_for_mysql_ready
  install_data_protection_integration
  success "MySQL 8.4.11 LTS install/reconcile completed"
}

uninstall_app() {
  extract_payload
  section "卸载 MySQL"

  if ! cluster_supports_service_monitor; then
    SERVICE_MONITOR_ENABLED="false"
  fi

  render_manifest "${MYSQL_MANIFEST}" | kubectl delete -n "${NAMESPACE}" --ignore-not-found -f - >/dev/null || true
  delete_backup_resources
  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found "mysql-restore" >/dev/null 2>&1 || true
  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found "mysql-benchmark" >/dev/null 2>&1 || true
  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found -l job-name >/dev/null 2>&1 || true
  kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${METRICS_SERVICE_NAME}" >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${FLUENTBIT_CONFIGMAP}" >/dev/null 2>&1 || true
  if cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi
  delete_pvcs_if_requested

  success "MySQL 卸载完成"
}


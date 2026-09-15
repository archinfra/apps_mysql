# MySQL 8.4 delivery rendering extensions loaded after 50-render-and-apply.sh.

render_feature_blocks() {
  local file_path="$1"
  local nodeport_enabled="${NODEPORT_ENABLED}"
  local stdout_logging_enabled="false"
  local backup_notification_enabled="false"
  local backup_database_enabled="false"
  local backup_secondary_storage_enabled="false"
  local backup_retention_enabled="false"
  local native_password_enabled="${MYSQL_NATIVE_PASSWORD_ENABLED}"

  if [[ "${FLUENTBIT_ENABLED}" != "true" ]]; then
    stdout_logging_enabled="true"
  fi

  if [[ -n "${BACKUP_NOTIFICATION_REF}" ]]; then
    backup_notification_enabled="true"
  fi

  if [[ -n "${BACKUP_DATABASE}" ]]; then
    backup_database_enabled="true"
  fi

  if [[ -n "${BACKUP_SECONDARY_STORAGE_NAME}" ]]; then
    backup_secondary_storage_enabled="true"
  fi

  if [[ -n "${BACKUP_RETENTION_REF}" ]]; then
    backup_retention_enabled="true"
  fi

  cat "${file_path}" \
    | render_optional_block "FEATURE_MONITORING" "${MONITORING_ENABLED}" \
    | render_optional_block "FEATURE_SERVICE_MONITOR" "${SERVICE_MONITOR_ENABLED}" \
    | render_optional_block "FEATURE_PROMETHEUS_RULE" "${PROMETHEUS_RULE_ENABLED}" \
    | render_optional_block "FEATURE_FLUENTBIT" "${FLUENTBIT_ENABLED}" \
    | render_optional_block "FEATURE_STDOUT_LOGGING" "${stdout_logging_enabled}" \
    | render_optional_block "FEATURE_NATIVE_PASSWORD" "${native_password_enabled}" \
    | render_optional_block "FEATURE_BACKUP_NOTIFICATION" "${backup_notification_enabled}" \
    | render_optional_block "FEATURE_BACKUP_DATABASE" "${backup_database_enabled}" \
    | render_optional_block "FEATURE_BACKUP_SECONDARY_STORAGE" "${backup_secondary_storage_enabled}" \
    | render_optional_block "FEATURE_BACKUP_RETENTION" "${backup_retention_enabled}" \
    | render_optional_block "FEATURE_NODEPORT" "${nodeport_enabled}"
}


render_manifest() {
  local file_path="$1"
  render_feature_blocks "${file_path}" \
    | template_replace \
    | sed \
        -e "s#__MYSQL_INNODB_BUFFER_POOL_SIZE__#${MYSQL_INNODB_BUFFER_POOL_SIZE}#g" \
        -e "s#__MYSQL_LOG_SIZE_LIMIT__#${MYSQL_LOG_SIZE_LIMIT}#g"
}


apply_mysql_observability_manifests() {
  if [[ "${MONITORING_ENABLED}" != "true" && "${SERVICE_MONITOR_ENABLED}" != "true" && "${PROMETHEUS_RULE_ENABLED}" != "true" ]]; then
    return 0
  fi

  require_manifest_file "${MYSQL_OBSERVABILITY_MANIFEST}"
  render_manifest "${MYSQL_OBSERVABILITY_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


cleanup_disabled_optional_resources() {
  # Remove stale objects when a feature is disabled on a later reconcile.
  if [[ "${NODEPORT_ENABLED}" != "true" ]]; then
    kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${NODEPORT_SERVICE_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${MONITORING_ENABLED}" != "true" ]]; then
    kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${METRICS_SERVICE_NAME}" >/dev/null 2>&1 || true
    kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "${ADDON_EXPORTER_SECRET}" >/dev/null 2>&1 || true
    kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${GRAFANA_DASHBOARD_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${SERVICE_MONITOR_ENABLED}" != "true" ]] && cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${PROMETHEUS_RULE_ENABLED}" != "true" ]] && cluster_supports_prometheus_rule; then
    kubectl delete prometheusrule -n "${NAMESPACE}" --ignore-not-found "${PROMETHEUS_RULE_NAME}" >/dev/null 2>&1 || true
    kubectl delete prometheusrule -n "${NAMESPACE}" --ignore-not-found "${ADDON_PROMETHEUS_RULE_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${FLUENTBIT_ENABLED}" != "true" ]]; then
    kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${FLUENTBIT_CONFIGMAP}" >/dev/null 2>&1 || true
  fi

  # v1.6.0 no longer mounts init SQL or fixed-password health users.
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found mysql-init-users >/dev/null 2>&1 || true

  delete_legacy_backup_resources
}

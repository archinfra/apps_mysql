cleanup_disabled_optional_resources() {
  if [[ "${BACKUP_ENABLED}" != "true" ]]; then
    delete_backup_resources
  fi

  if [[ "${BACKUP_ENABLED}" == "true" && ! backup_backend_is_s3 ]]; then
    kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "${BACKUP_STORAGE_SECRET}" >/dev/null 2>&1 || true
  fi

  if [[ "${MONITORING_ENABLED}" != "true" ]]; then
    kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${METRICS_SERVICE_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${SERVICE_MONITOR_ENABLED}" != "true" ]] && cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${FLUENTBIT_ENABLED}" != "true" ]]; then
    kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${FLUENTBIT_CONFIGMAP}" >/dev/null 2>&1 || true
  fi
}


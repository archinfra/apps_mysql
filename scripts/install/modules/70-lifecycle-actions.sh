monitoring_bootstrap_auth_available() {
  if [[ -n "${MYSQL_PASSWORD}" ]]; then
    return 0
  fi

  secret_has_key "${MYSQL_AUTH_SECRET}" "${MYSQL_PASSWORD_KEY}"
}


data_protection_resource_exists() {
  local resource_name="$1"
  local object_name="$2"

  kubectl get "${resource_name}.dataprotection.archinfra.io" -n "${BACKUP_NAMESPACE}" "${object_name}" >/dev/null 2>&1
}


resolve_mysql_backup_password() {
  if [[ "${MYSQL_ROOT_PASSWORD_EXPLICIT}" == "true" ]]; then
    printf '%s' "${MYSQL_ROOT_PASSWORD}"
    return 0
  fi

  kubectl get secret -n "${NAMESPACE}" "${AUTH_SECRET}" -o 'jsonpath={.data.mysql-root-password}' 2>/dev/null | base64 --decode
}


prepare_data_protection_integration() {
  [[ "${DATA_PROTECTION_ENABLED}" == "true" ]] || return 1

  if ! cluster_supports_data_protection; then
    warn "dataprotection CRDs are not installed; skipping MySQL data protection registration"
    return 1
  fi

  ensure_named_namespace "${BACKUP_NAMESPACE}"

  if ! data_protection_resource_exists "backupstorages" "${BACKUP_PRIMARY_STORAGE_NAME}"; then
    warn "BackupStorage/${BACKUP_PRIMARY_STORAGE_NAME} was not found; skipping MySQL data protection registration"
    return 1
  fi

  if [[ -n "${BACKUP_SECONDARY_STORAGE_NAME}" ]] && ! data_protection_resource_exists "backupstorages" "${BACKUP_SECONDARY_STORAGE_NAME}"; then
    warn "BackupStorage/${BACKUP_SECONDARY_STORAGE_NAME} was not found; skipping secondary backup storage"
    BACKUP_SECONDARY_STORAGE_NAME=""
  fi

  if [[ -n "${BACKUP_RETENTION_REF}" ]] && ! data_protection_resource_exists "retentionpolicies" "${BACKUP_RETENTION_REF}"; then
    warn "RetentionPolicy/${BACKUP_RETENTION_REF} was not found; skipping retention reference"
    BACKUP_RETENTION_REF=""
  fi

  if [[ -n "${BACKUP_NOTIFICATION_REF}" ]] && ! data_protection_resource_exists "notificationendpoints" "${BACKUP_NOTIFICATION_REF}"; then
    warn "NotificationEndpoint/${BACKUP_NOTIFICATION_REF} was not found; skipping notification reference"
    BACKUP_NOTIFICATION_REF=""
  fi

  return 0
}


sync_data_protection_auth_secret() {
  local mysql_password
  if ! mysql_password="$(resolve_mysql_backup_password 2>/dev/null)"; then
    warn "Unable to resolve the MySQL root password; skipping data protection registration"
    return 1
  fi

  if [[ -z "${mysql_password}" ]]; then
    warn "Unable to resolve the MySQL root password; skipping data protection registration"
    return 1
  fi

  kubectl create secret generic "${BACKUP_AUTH_SECRET}" \
    -n "${BACKUP_NAMESPACE}" \
    --from-literal="password=${mysql_password}" \
    --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}


install_data_protection_integration() {
  prepare_data_protection_integration || return 0
  sync_data_protection_auth_secret || return 0

  section "Register MySQL Data Protection"
  apply_data_protection_manifests
  DATA_PROTECTION_APPLIED="true"
  success "MySQL data protection registration completed"
}


uninstall_data_protection_integration() {
  cluster_supports_data_protection || return 0

  kubectl delete backuppolicies.dataprotection.archinfra.io -n "${BACKUP_NAMESPACE}" --ignore-not-found "${BACKUP_POLICY_NAME}" >/dev/null 2>&1 || true
  kubectl delete backupsources.dataprotection.archinfra.io -n "${BACKUP_NAMESPACE}" --ignore-not-found "${BACKUP_SOURCE_NAME}" >/dev/null 2>&1 || true
  kubectl delete secret -n "${BACKUP_NAMESPACE}" --ignore-not-found "${BACKUP_AUTH_SECRET}" >/dev/null 2>&1 || true
}


uninstall_addons() {
  require_namespace_exists

  if addon_selected service-monitor && cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${ADDON_SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi

  if addon_selected monitoring && cluster_supports_prometheus_rule; then
    kubectl delete prometheusrule -n "${NAMESPACE}" --ignore-not-found "${ADDON_PROMETHEUS_RULE_NAME}" >/dev/null 2>&1 || true
  fi

  if addon_selected monitoring; then
    section "Remove Monitoring Addon"
    delete_external_monitoring_resources
    success "Monitoring addon removed"
  fi
}


show_addon_status() {
  local external_monitoring="not-installed"
  local embedded_monitoring="not-installed"
  local embedded_logging="not-installed"
  local addon_service_monitor="not-installed"
  local embedded_service_monitor="not-installed"
  local addon_prometheus_rule="not-installed"
  local embedded_prometheus_rule="not-installed"

  require_namespace_exists

  resource_exists deployment "${ADDON_EXPORTER_DEPLOYMENT_NAME}" && external_monitoring="installed"

  if resource_exists statefulset "${STS_NAME}"; then
    statefulset_has_container "mysqld-exporter" && embedded_monitoring="installed"
    statefulset_has_container "fluent-bit" && embedded_logging="installed"
  fi

  if cluster_supports_service_monitor; then
    resource_exists servicemonitor "${ADDON_SERVICE_MONITOR_NAME}" && addon_service_monitor="installed"
    resource_exists servicemonitor "${SERVICE_MONITOR_NAME}" && embedded_service_monitor="installed"
  else
    addon_service_monitor="crd-missing"
    embedded_service_monitor="crd-missing"
  fi

  if cluster_supports_prometheus_rule; then
    resource_exists prometheusrule "${ADDON_PROMETHEUS_RULE_NAME}" && addon_prometheus_rule="installed"
    resource_exists prometheusrule "${PROMETHEUS_RULE_NAME}" && embedded_prometheus_rule="installed"
  else
    addon_prometheus_rule="crd-missing"
    embedded_prometheus_rule="crd-missing"
  fi

  section "Addon Status"
  echo "External monitoring addon : ${external_monitoring}"
  echo "Embedded monitoring       : ${embedded_monitoring}"
  echo "External ServiceMonitor   : ${addon_service_monitor}"
  echo "Embedded ServiceMonitor   : ${embedded_service_monitor}"
  echo "External PrometheusRule   : ${addon_prometheus_rule}"
  echo "Embedded PrometheusRule   : ${embedded_prometheus_rule}"
  echo "Fluent Bit sidecar        : ${embedded_logging}"
  echo
  echo "Recommended:"
  echo "1. If MySQL already exists, prefer addon-install for extra monitoring."
  echo "2. Backup and restore execution still belongs to dataprotection controllers."
  echo "3. If you need the log sidecar, use install and plan for a rolling update."
}


show_status() {
  require_namespace_exists

  section "Runtime Status"
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
  if cluster_supports_prometheus_rule; then
    kubectl get prometheusrule -n "${NAMESPACE}" || true
    echo
  fi
  if cluster_supports_data_protection && kubectl get namespace "${BACKUP_NAMESPACE}" >/dev/null 2>&1; then
    kubectl get backupsources.dataprotection.archinfra.io -n "${BACKUP_NAMESPACE}" --ignore-not-found "${BACKUP_SOURCE_NAME}" || true
    kubectl get backuppolicies.dataprotection.archinfra.io -n "${BACKUP_NAMESPACE}" --ignore-not-found "${BACKUP_POLICY_NAME}" || true
    echo
  fi
  kubectl get jobs -n "${NAMESPACE}" || true
}


delete_pvcs_if_requested() {
  [[ "${DELETE_PVC}" == "true" ]] || return 0

  log "Delete StatefulSet/${STS_NAME} PVCs"
  mapfile -t pvcs < <(kubectl get pvc -n "${NAMESPACE}" -o name | grep "^persistentvolumeclaim/data-${STS_NAME}-" || true)
  if [[ ${#pvcs[@]} -eq 0 ]]; then
    return 0
  fi
  kubectl delete -n "${NAMESPACE}" "${pvcs[@]}" >/dev/null || true
}


uninstall_app() {
  extract_payload
  section "Uninstall MySQL"

  if ! cluster_supports_service_monitor; then
    SERVICE_MONITOR_ENABLED="false"
  fi
  if ! cluster_supports_prometheus_rule; then
    PROMETHEUS_RULE_ENABLED="false"
  fi

  render_manifest "${MYSQL_MANIFEST}" | kubectl delete -n "${NAMESPACE}" --ignore-not-found -f - >/dev/null || true
  delete_external_monitoring_resources
  delete_legacy_backup_resources
  uninstall_data_protection_integration
  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found "mysql-benchmark" >/dev/null 2>&1 || true
  kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${METRICS_SERVICE_NAME}" >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${FLUENTBIT_CONFIGMAP}" >/dev/null 2>&1 || true
  if cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${ADDON_SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi
  if cluster_supports_prometheus_rule; then
    kubectl delete prometheusrule -n "${NAMESPACE}" --ignore-not-found "${PROMETHEUS_RULE_NAME}" >/dev/null 2>&1 || true
    kubectl delete prometheusrule -n "${NAMESPACE}" --ignore-not-found "${ADDON_PROMETHEUS_RULE_NAME}" >/dev/null 2>&1 || true
  fi
  delete_pvcs_if_requested

  success "MySQL uninstall completed"
}


install_app() {
  extract_payload
  prepare_images
  ensure_namespace

  if [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && ! cluster_supports_service_monitor; then
    warn "ServiceMonitor CRD is missing; skipping ServiceMonitor resources"
    SERVICE_MONITOR_ENABLED="false"
  fi

  if [[ "${PROMETHEUS_RULE_ENABLED}" == "true" ]] && ! cluster_supports_prometheus_rule; then
    warn "PrometheusRule CRD is missing; skipping PrometheusRule resources"
    PROMETHEUS_RULE_ENABLED="false"
  fi

  section "Install Or Reconcile MySQL"
  apply_mysql_manifests
  cleanup_disabled_optional_resources
  wait_for_statefulset_ready
  wait_for_mysql_ready
  install_data_protection_integration
  success "MySQL install/reconcile completed"
}


install_addons() {
  extract_payload
  prepare_images
  ensure_namespace

  if addon_selected monitoring; then
    if resource_exists statefulset "${STS_NAME}" && statefulset_has_container "mysqld-exporter"; then
      die "The current MySQL already embeds mysqld-exporter; do not stack the external monitoring addon"
    fi

    if addon_selected service-monitor && ! cluster_supports_service_monitor; then
      warn "ServiceMonitor CRD is missing; installing monitoring addon without service-monitor"
      ADDONS="${ADDONS//service-monitor/}"
      ADDONS="${ADDONS//,,/,}"
      ADDONS="${ADDONS#,}"
      ADDONS="${ADDONS%,}"
      SERVICE_MONITOR_ENABLED="false"
    fi

    if ! cluster_supports_prometheus_rule; then
      warn "PrometheusRule CRD is missing; skipping monitoring addon alert rules"
      PROMETHEUS_RULE_ENABLED="false"
    fi

    if ! resource_exists statefulset "${STS_NAME}" && [[ "${ADDON_MONITORING_TARGET_EXPLICIT}" != "true" && "${MYSQL_HOST_EXPLICIT}" != "true" ]]; then
      die "When installing the monitoring addon for an existing external MySQL, pass --monitoring-target or at least --mysql-host/--mysql-port"
    fi

    if monitoring_bootstrap_auth_available; then
      ensure_addon_exporter_user
    else
      warn "Writable MySQL admin credentials were not provided; skipping exporter user bootstrap"
    fi

    section "Install Monitoring Addon"
    apply_monitoring_addon_manifests
    kubectl rollout status "deployment/${ADDON_EXPORTER_DEPLOYMENT_NAME}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}"
    success "Monitoring addon install completed"
  fi
}

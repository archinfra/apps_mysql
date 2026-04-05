delete_backup_resources() {
  kubectl delete cronjob -n "${NAMESPACE}" --ignore-not-found "${BACKUP_CRONJOB_NAME}" >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${BACKUP_SCRIPT_CONFIGMAP}" >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "${BACKUP_STORAGE_SECRET}" >/dev/null 2>&1 || true
}


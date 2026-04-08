legacy_backup_resource_selector() {
  echo "app.kubernetes.io/component=backup"
}


create_benchmark_job() {
  local benchmark_job_name="mysql-benchmark-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建压测 Job ${benchmark_job_name}" >&2
  BENCHMARK_JOB_NAME="${benchmark_job_name}" render_manifest "${BENCHMARK_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${benchmark_job_name}"
}


delete_legacy_backup_resources() {
  local selector
  selector="$(legacy_backup_resource_selector)"

  kubectl delete cronjob -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete job -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true

  kubectl delete cronjob -n "${NAMESPACE}" --ignore-not-found "mysql-backup" >/dev/null 2>&1 || true
  kubectl delete job -n "${NAMESPACE}" --ignore-not-found "mysql-backup" "mysql-restore" >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "mysql-backup-scripts" >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "mysql-backup-storage" >/dev/null 2>&1 || true
}

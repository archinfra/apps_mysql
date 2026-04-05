create_manual_backup_job() {
  local job_name="${BACKUP_CRONJOB_NAME}-manual-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建手工备份 Job ${job_name}" >&2
  BACKUP_JOB_NAME="${job_name}" render_manifest "${BACKUP_JOB_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${job_name}"
}


create_restore_job() {
  local restore_job_name="mysql-restore-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建恢复 Job ${restore_job_name}" >&2
  RESTORE_JOB_NAME="${restore_job_name}" render_manifest "${RESTORE_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${restore_job_name}"
}


create_benchmark_job() {
  local benchmark_job_name="mysql-benchmark-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建压测 Job ${benchmark_job_name}" >&2
  BENCHMARK_JOB_NAME="${benchmark_job_name}" render_manifest "${BENCHMARK_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${benchmark_job_name}"
}


delete_backup_resources() {
  kubectl delete cronjob -n "${NAMESPACE}" --ignore-not-found "${BACKUP_CRONJOB_NAME}" >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${BACKUP_SCRIPT_CONFIGMAP}" >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "${BACKUP_STORAGE_SECRET}" >/dev/null 2>&1 || true
}


run_backup() {
  extract_payload
  prepare_images
  ensure_namespace
  apply_backup_support_manifests
  preflight_mysql_connection "预检备份目标连接"

  section "执行手工备份"
  local job_name
  job_name="$(create_manual_backup_job)"
  wait_for_job "${job_name}" || die "备份任务失败"
}

run_restore() {
  extract_payload
  prepare_images
  ensure_namespace
  apply_backup_support_manifests
  preflight_mysql_connection "预检恢复目标连接"

  section "执行数据恢复"
  local restore_job_name
  restore_job_name="$(create_restore_job)"
  wait_for_job "${restore_job_name}" || die "恢复任务失败"
}

verify_backup_restore() {
  extract_payload
  prepare_images
  ensure_namespace
  apply_backup_support_manifests
  preflight_mysql_connection "预检备份/恢复目标连接"

  section "执行备份/恢复闭环校验"

  local snapshot_value changed_value restored_value backup_job restore_job report_path
  snapshot_value="snapshot-$(date +%s)"
  changed_value="changed-$(date +%s)"

  log "写入校验数据"
  mysql_exec "CREATE DATABASE IF NOT EXISTS offline_validation;"
  mysql_exec "CREATE TABLE IF NOT EXISTS offline_validation.backup_restore_check (id INT PRIMARY KEY, marker VARCHAR(128) NOT NULL);"
  mysql_exec "REPLACE INTO offline_validation.backup_restore_check (id, marker) VALUES (1, '${snapshot_value}');"

  backup_job="$(create_manual_backup_job)"
  wait_for_job "${backup_job}" || die "校验用备份任务失败"

  log "修改数据，准备验证恢复结果"
  mysql_exec "UPDATE offline_validation.backup_restore_check SET marker='${changed_value}' WHERE id=1;"

  restore_job="$(create_restore_job)"
  wait_for_job "${restore_job}" || die "校验用恢复任务失败"

  restored_value="$(mysql_exec "SELECT marker FROM offline_validation.backup_restore_check WHERE id=1;")"
  [[ "${restored_value}" == "${snapshot_value}" ]] || die "备份/恢复闭环校验失败，期望 ${snapshot_value}，实际 ${restored_value}"

  report_path="$(write_report "backup-restore-${NAMESPACE}-$(date +%Y%m%d%H%M%S).txt" "$(cat <<EOF
mysql backup/restore verification report
generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
namespace=${NAMESPACE}
mysql_target=${MYSQL_TARGET_NAME}
backup_job=${backup_job}
restore_job=${restore_job}
backup_backend=${BACKUP_BACKEND}
restore_mode=${MYSQL_RESTORE_MODE}
snapshot_value=${snapshot_value}
restored_value=${restored_value}
status=success
EOF
)")"

  success "备份/恢复闭环校验成功"
  echo "报告文件: ${report_path}"
}


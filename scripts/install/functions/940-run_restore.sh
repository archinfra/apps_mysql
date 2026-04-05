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
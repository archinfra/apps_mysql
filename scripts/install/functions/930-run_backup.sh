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
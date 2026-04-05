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
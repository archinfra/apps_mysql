backup_resource_selector() {
  echo "app.kubernetes.io/component=backup"
}


apply_backup_support_manifests_for_all_plans() {
  local spec

  backup_plan_build_catalog
  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    apply_backup_support_manifests
  done
}


apply_backup_schedule_manifests_for_all_plans() {
  local spec

  backup_plan_build_catalog
  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    apply_backup_schedule_manifests
  done
}


create_manual_backup_job() {
  local job_name="${BACKUP_CRONJOB_NAME}-manual-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建手工备份 Job ${job_name} (plan=${BACKUP_PLAN_NAME})" >&2
  BACKUP_JOB_NAME="${job_name}" render_manifest "${BACKUP_JOB_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${job_name}"
}


create_restore_job() {
  local restore_job_name="mysql-restore-${BACKUP_PLAN_NAME}-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建恢复 Job ${restore_job_name} (plan=${BACKUP_PLAN_NAME})" >&2
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
  local selector
  selector="$(backup_resource_selector)"
  kubectl delete cronjob -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete job -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
}


run_backup() {
  local spec job_name
  local completed_jobs=()

  extract_payload
  prepare_images
  ensure_namespace
  preflight_mysql_connection "预检备份目标连接"

  section "执行手工备份"
  backup_plan_build_catalog
  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    apply_backup_support_manifests
    job_name="$(create_manual_backup_job)"
    wait_for_job "${job_name}" || die "备份任务失败，plan=${BACKUP_PLAN_NAME}"
    completed_jobs+=("${BACKUP_PLAN_NAME}:${job_name}")
  done

  success "所有 backup plan 执行完成"
  printf '%s\n' "${completed_jobs[@]}"
}


run_restore() {
  local spec restore_job_name

  extract_payload
  prepare_images
  ensure_namespace
  preflight_mysql_connection "预检恢复目标连接"

  section "执行数据恢复"
  while IFS= read -r spec; do
    [[ -n "${spec}" ]] || continue
    backup_plan_activate_spec "${spec}"

    if [[ "${MYSQL_RESTORE_MODE}" == "wipe-all-user-databases" ]] && ! backup_plan_supports_wipe_restore; then
      if [[ "${BACKUP_RESTORE_SOURCE}" != "auto" ]]; then
        die "restore-source=${BACKUP_PLAN_NAME} 是部分备份，不支持 wipe-all-user-databases；请改用 merge，或选择全量备份来源"
      fi
      warn "restore-source=${BACKUP_PLAN_NAME} 是部分备份，与 wipe-all-user-databases 不兼容，跳过"
      continue
    fi

    apply_backup_support_manifests
    restore_job_name="$(create_restore_job)"
    if wait_for_job "${restore_job_name}"; then
      success "恢复任务完成，source plan=${BACKUP_PLAN_NAME}"
      echo "恢复作业: ${restore_job_name}"
      return 0
    fi
    warn "restore-source=${BACKUP_PLAN_NAME} 恢复失败，继续尝试下一个来源"
  done < <(backup_plan_specs_for_restore)

  die "恢复任务失败，所有 restore-source 均未成功"
}


verify_backup_restore() {
  local snapshot_value changed_value restored_value backup_job restore_job report_path
  local spec
  local backup_jobs=()
  local restore_source_plan=""

  extract_payload
  prepare_images
  ensure_namespace
  preflight_mysql_connection "预检备份/恢复目标连接"

  section "执行备份/恢复闭环校验"

  snapshot_value="snapshot-$(date +%s)"
  changed_value="changed-$(date +%s)"

  log "写入校验数据"
  mysql_exec "CREATE DATABASE IF NOT EXISTS offline_validation;"
  mysql_exec "CREATE TABLE IF NOT EXISTS offline_validation.backup_restore_check (id INT PRIMARY KEY, marker VARCHAR(128) NOT NULL);"
  mysql_exec "REPLACE INTO offline_validation.backup_restore_check (id, marker) VALUES (1, '${snapshot_value}');"

  backup_plan_build_catalog
  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    apply_backup_support_manifests
    backup_job="$(create_manual_backup_job)"
    wait_for_job "${backup_job}" || die "校验用备份任务失败，plan=${BACKUP_PLAN_NAME}"
    backup_jobs+=("${BACKUP_PLAN_NAME}:${backup_job}")
  done

  log "修改数据，准备验证恢复结果"
  mysql_exec "UPDATE offline_validation.backup_restore_check SET marker='${changed_value}' WHERE id=1;"

  restore_job=""
  while IFS= read -r spec; do
    [[ -n "${spec}" ]] || continue
    backup_plan_activate_spec "${spec}"

    if ! backup_plan_supports_verify_marker; then
      if [[ "${BACKUP_RESTORE_SOURCE}" != "auto" ]]; then
        die "restore-source=${BACKUP_PLAN_NAME} 未覆盖 offline_validation.backup_restore_check，无法做闭环校验"
      fi
      warn "restore-source=${BACKUP_PLAN_NAME} 未覆盖 offline_validation 校验表，跳过"
      continue
    fi

    if [[ "${MYSQL_RESTORE_MODE}" == "wipe-all-user-databases" ]] && ! backup_plan_supports_wipe_restore; then
      if [[ "${BACKUP_RESTORE_SOURCE}" != "auto" ]]; then
        die "restore-source=${BACKUP_PLAN_NAME} 是部分备份，不支持 wipe-all-user-databases 闭环校验"
      fi
      warn "restore-source=${BACKUP_PLAN_NAME} 是部分备份，与 wipe-all-user-databases 不兼容，跳过"
      continue
    fi

    apply_backup_support_manifests
    restore_job="$(create_restore_job)"
    if wait_for_job "${restore_job}"; then
      restore_source_plan="${BACKUP_PLAN_NAME}"
      break
    fi
    restore_job=""
    warn "校验恢复在 plan=${BACKUP_PLAN_NAME} 失败，继续尝试下一个来源"
  done < <(backup_plan_specs_for_restore)

  [[ -n "${restore_job}" ]] || die "校验用恢复任务失败"

  restored_value="$(mysql_exec "SELECT marker FROM offline_validation.backup_restore_check WHERE id=1;")"
  [[ "${restored_value}" == "${snapshot_value}" ]] || die "备份/恢复闭环校验失败，期望 ${snapshot_value}，实际 ${restored_value}"

  report_path="$(write_report "backup-restore-${NAMESPACE}-$(date +%Y%m%d%H%M%S).txt" "$(cat <<EOF
mysql backup/restore verification report
generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
namespace=${NAMESPACE}
mysql_target=${MYSQL_TARGET_NAME}
backup_jobs=${backup_jobs[*]}
restore_job=${restore_job}
restore_source=${restore_source_plan:-${BACKUP_RESTORE_SOURCE}}
restore_mode=${MYSQL_RESTORE_MODE}
snapshot_value=${snapshot_value}
restored_value=${restored_value}
status=success
EOF
)")"

  success "备份/恢复闭环校验成功"
  echo "报告文件: ${report_path}"
}

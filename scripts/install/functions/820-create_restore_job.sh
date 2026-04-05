create_restore_job() {
  local restore_job_name="mysql-restore-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建恢复 Job ${restore_job_name}" >&2
  RESTORE_JOB_NAME="${restore_job_name}" render_manifest "${RESTORE_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${restore_job_name}"
}


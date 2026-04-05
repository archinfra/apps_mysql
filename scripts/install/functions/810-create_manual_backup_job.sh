create_manual_backup_job() {
  local job_name="${BACKUP_CRONJOB_NAME}-manual-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建手工备份 Job ${job_name}" >&2
  BACKUP_JOB_NAME="${job_name}" render_manifest "${BACKUP_JOB_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${job_name}"
}


render_feature_blocks() {
  local file_path="$1"
  local backup_nfs_enabled="false"
  local backup_s3_enabled="false"
  local nodeport_enabled="${NODEPORT_ENABLED}"

  if backup_backend_is_nfs; then
    backup_nfs_enabled="true"
  else
    backup_s3_enabled="true"
  fi

  cat "${file_path}" \
    | render_optional_block "FEATURE_MONITORING" "${MONITORING_ENABLED}" \
    | render_optional_block "FEATURE_SERVICE_MONITOR" "${SERVICE_MONITOR_ENABLED}" \
    | render_optional_block "FEATURE_FLUENTBIT" "${FLUENTBIT_ENABLED}" \
    | render_optional_block "FEATURE_NODEPORT" "${nodeport_enabled}" \
    | render_optional_block "BACKUP_NFS" "${backup_nfs_enabled}" \
    | render_optional_block "BACKUP_S3" "${backup_s3_enabled}"
}
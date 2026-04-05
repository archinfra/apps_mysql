apply_backup_schedule_manifests() {
  render_manifest "${BACKUP_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


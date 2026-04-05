apply_backup_manifests() {
  render_manifest "${BACKUP_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


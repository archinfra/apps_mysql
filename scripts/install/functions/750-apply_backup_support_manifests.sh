apply_backup_support_manifests() {
  render_manifest "${BACKUP_SUPPORT_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


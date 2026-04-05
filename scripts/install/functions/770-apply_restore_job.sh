apply_restore_job() {
  render_manifest "${RESTORE_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


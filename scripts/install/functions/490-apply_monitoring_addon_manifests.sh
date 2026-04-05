apply_monitoring_addon_manifests() {
  render_manifest "${MONITORING_ADDON_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


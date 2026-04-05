cluster_supports_service_monitor() {
  kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1
}


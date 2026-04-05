show_status() {
  section "运行状态"
  kubectl get statefulset -n "${NAMESPACE}" || true
  echo
  kubectl get deployment -n "${NAMESPACE}" || true
  echo
  kubectl get pods -n "${NAMESPACE}" -o wide || true
  echo
  kubectl get svc -n "${NAMESPACE}" || true
  echo
  kubectl get pvc -n "${NAMESPACE}" || true
  echo
  kubectl get cronjob -n "${NAMESPACE}" || true
  echo
  if cluster_supports_service_monitor; then
    kubectl get servicemonitor -n "${NAMESPACE}" || true
    echo
  fi
  kubectl get jobs -n "${NAMESPACE}" || true
}


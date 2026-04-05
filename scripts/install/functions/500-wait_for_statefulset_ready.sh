wait_for_statefulset_ready() {
  log "等待 StatefulSet/${STS_NAME} 就绪"
  kubectl rollout status "statefulset/${STS_NAME}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}"
}


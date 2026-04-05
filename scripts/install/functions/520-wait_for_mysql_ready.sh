wait_for_mysql_ready() {
  local pod_name
  pod_name="$(mysql_pod_name)"

  log "等待 Pod/${pod_name} Ready"
  kubectl wait --for=condition=ready "pod/${pod_name}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}" >/dev/null

  log "等待 MySQL 接受连接"
  local retries=60
  local attempt
  for (( attempt=1; attempt<=retries; attempt++ )); do
    if kubectl exec -n "${NAMESPACE}" "${pod_name}" -- env MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysqladmin -uroot ping >/dev/null 2>&1; then
      success "MySQL 已就绪"
      return 0
    fi
    sleep 5
  done

  die "MySQL 在超时时间内未就绪"
}


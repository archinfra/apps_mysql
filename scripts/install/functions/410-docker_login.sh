docker_login() {
  log "登录镜像仓库 ${REGISTRY_ADDR}"
  if echo "${REGISTRY_PASS}" | docker login "${REGISTRY_ADDR}" -u "${REGISTRY_USER}" --password-stdin >/dev/null 2>&1; then
    success "镜像仓库登录成功"
  else
    warn "镜像仓库登录失败，继续尝试后续流程"
  fi
}


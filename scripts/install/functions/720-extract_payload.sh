extract_payload() {
  section "解压安装载荷"
  rm -rf "${WORKDIR}"
  mkdir -p "${WORKDIR}" "${IMAGE_DIR}" "${MANIFEST_DIR}"

  local payload_line
  payload_line="$(awk '/^__PAYLOAD_BELOW__$/ { print NR + 1; exit }' "$0")"
  [[ -n "${payload_line}" ]] || die "未找到载荷标记"

  log "正在解压到 ${WORKDIR}"
  tail -n +"${payload_line}" "$0" | tar -xz -C "${WORKDIR}" >/dev/null 2>&1 || die "解压载荷失败"

  [[ -f "${MYSQL_MANIFEST}" ]] || die "缺少 MySQL manifest"
  [[ -f "${BACKUP_MANIFEST}" ]] || die "缺少 backup cronjob manifest"
  [[ -f "${BACKUP_SUPPORT_MANIFEST}" ]] || die "缺少 backup support manifest"
  [[ -f "${BACKUP_JOB_MANIFEST}" ]] || die "缺少 backup job manifest"
  [[ -f "${RESTORE_MANIFEST}" ]] || die "缺少 restore manifest"
  [[ -f "${BENCHMARK_MANIFEST}" ]] || die "缺少 benchmark manifest"
  [[ -f "${MONITORING_ADDON_MANIFEST}" ]] || die "缺少 monitoring addon manifest"
  [[ -f "${IMAGE_JSON}" ]] || die "缺少 image.json"
  success "载荷解压完成"
}


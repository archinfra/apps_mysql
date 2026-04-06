docker_login() {
  log "登录镜像仓库 ${REGISTRY_ADDR}"
  if echo "${REGISTRY_PASS}" | docker login "${REGISTRY_ADDR}" -u "${REGISTRY_USER}" --password-stdin >/dev/null 2>&1; then
    success "镜像仓库登录成功"
  else
    warn "镜像仓库登录失败，继续尝试后续流程"
  fi
}


resolve_target_image_tag() {
  local source_tag="$1"
  local suffix="${source_tag#*/kube4/}"

  if [[ "${suffix}" == "${source_tag}" ]]; then
    suffix="${source_tag##*/}"
  fi

  printf '%s/%s' "${REGISTRY_REPO}" "${suffix}"
}

prepare_images() {
  [[ "${SKIP_IMAGE_PREPARE}" == "true" ]] && {
    warn "已按要求跳过镜像导入与推送"
    return 0
  }

  section "准备离线镜像"
  docker_login

  local count=0
  while IFS= read -r item; do
    [[ -n "${item}" ]] || continue

    local tar_name image_tag target_tag tar_path
    tar_name="$(jq -r '.tar' <<<"${item}")"
    image_tag="$(jq -r '.tag // .pull' <<<"${item}")"
    target_tag="$(resolve_target_image_tag "${image_tag}")"
    tar_path="${IMAGE_DIR}/${tar_name}"

    image_needed_for_current_action "${image_tag}" || continue
    [[ -f "${tar_path}" ]] || continue

    log "导入镜像归档 ${tar_name}"
    docker load -i "${tar_path}" >/dev/null
    if [[ "${target_tag}" != "${image_tag}" ]]; then
      log "重打标签 ${image_tag} -> ${target_tag}"
      docker tag "${image_tag}" "${target_tag}"
    fi
    log "推送镜像 ${target_tag}"
    docker push "${target_tag}" >/dev/null
    count=$((count + 1))
  done < <(jq -c '.[]' "${IMAGE_JSON}")

  (( count > 0 )) || die "载荷中未发现可导入的镜像归档"
  success "已准备 ${count} 个镜像归档"
}

ensure_namespace() {
  if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    return 0
  fi
  log "创建命名空间 ${NAMESPACE}"
  kubectl create namespace "${NAMESPACE}" >/dev/null
}


render_optional_block() {
  local feature_name="$1"
  local enabled="$2"

  awk \
    -v start_marker="#__${feature_name}_START__" \
    -v end_marker="#__${feature_name}_END__" \
    -v enabled="${enabled}" '
      {
        marker=$0
        sub(/^[[:space:]]+/, "", marker)
      }
      marker == start_marker { skip=(enabled != "true"); next }
      marker == end_marker { skip=0; next }
      !skip { print }
    '
}


render_feature_blocks() {
  local file_path="$1"
  local backup_nfs_enabled="false"
  local backup_s3_enabled="false"
  local nodeport_enabled="${NODEPORT_ENABLED}"

  if backup_backend_is_nfs; then
    backup_nfs_enabled="true"
  else
    backup_s3_enabled="true"
  fi

  cat "${file_path}" \
    | render_optional_block "FEATURE_MONITORING" "${MONITORING_ENABLED}" \
    | render_optional_block "FEATURE_SERVICE_MONITOR" "${SERVICE_MONITOR_ENABLED}" \
    | render_optional_block "FEATURE_FLUENTBIT" "${FLUENTBIT_ENABLED}" \
    | render_optional_block "FEATURE_NODEPORT" "${nodeport_enabled}" \
    | render_optional_block "BACKUP_NFS" "${backup_nfs_enabled}" \
    | render_optional_block "BACKUP_S3" "${backup_s3_enabled}"
}

render_manifest() {
  local file_path="$1"
  render_feature_blocks "${file_path}" | template_replace
}


apply_mysql_manifests() {
  render_manifest "${MYSQL_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_backup_manifests() {
  render_manifest "${BACKUP_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_monitoring_addon_manifests() {
  render_manifest "${MONITORING_ADDON_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


cleanup_disabled_optional_resources() {
  if [[ "${BACKUP_ENABLED}" != "true" ]]; then
    delete_backup_resources
  fi

  if [[ "${BACKUP_ENABLED}" == "true" && ! backup_backend_is_s3 ]]; then
    kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "${BACKUP_STORAGE_SECRET}" >/dev/null 2>&1 || true
  fi

  if [[ "${MONITORING_ENABLED}" != "true" ]]; then
    kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${METRICS_SERVICE_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${SERVICE_MONITOR_ENABLED}" != "true" ]] && cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${FLUENTBIT_ENABLED}" != "true" ]]; then
    kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${FLUENTBIT_CONFIGMAP}" >/dev/null 2>&1 || true
  fi
}


extract_payload() {
  section "解压安装载荷"
  rm -rf "${WORKDIR}"
  mkdir -p "${WORKDIR}" "${IMAGE_DIR}" "${MANIFEST_DIR}"

  local marker_line payload_offset skip_bytes byte_hex
  marker_line="$(awk '/^__PAYLOAD_BELOW__$/ { print NR; exit }' "$0")"
  [[ -n "${marker_line}" ]] || die "未找到载荷标记"
  payload_offset="$(( $(head -n "${marker_line}" "$0" | wc -c | tr -d ' ') + 1 ))"

  skip_bytes=0
  while :; do
    byte_hex="$(dd if="$0" bs=1 skip="$((payload_offset + skip_bytes - 1))" count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    case "${byte_hex}" in
      0a|0d)
        skip_bytes=$((skip_bytes + 1))
        ;;
      "")
        die "载荷边界异常，未找到有效的压缩数据"
        ;;
      *)
        break
        ;;
    esac
  done

  log "正在解压到 ${WORKDIR}"
  tail -c +"$((payload_offset + skip_bytes))" "$0" | tar -xz -C "${WORKDIR}" >/dev/null 2>&1 || die "解压载荷失败"

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


image_needed_for_current_action() {
  local image_tag="$1"

  case "${ACTION}" in
    install)
      return 0
      ;;
    addon-install)
      if addon_selected monitoring && [[ "${image_tag}" == */mysqld-exporter:* ]]; then
        return 0
      fi
      if addon_selected backup && [[ "${image_tag}" == */mysql:* ]]; then
        return 0
      fi
      if addon_selected backup && backup_backend_is_s3 && [[ "${image_tag}" == */minio-mc:* ]]; then
        return 0
      fi
      return 1
      ;;
    backup|restore|verify-backup-restore)
      if [[ "${image_tag}" == */mysql:* ]]; then
        return 0
      fi
      if backup_backend_is_s3 && [[ "${image_tag}" == */minio-mc:* ]]; then
        return 0
      fi
      return 1
      ;;
    benchmark)
      if [[ "${image_tag}" == */mysql:* || "${image_tag}" == */sysbench:* ]]; then
        return 0
      fi
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}


template_replace() {
  sed \
    -e "s#__APP_NAME__#${APP_NAME}#g" \
    -e "s#__NAMESPACE__#${NAMESPACE}#g" \
    -e "s#__MYSQL_REPLICAS__#${MYSQL_REPLICAS}#g" \
    -e "s#__STORAGE_CLASS__#${STORAGE_CLASS}#g" \
    -e "s#__STORAGE_SIZE__#${STORAGE_SIZE}#g" \
    -e "s#__MYSQL_ROOT_PASSWORD__#${MYSQL_ROOT_PASSWORD}#g" \
    -e "s#__SERVICE_NAME__#${SERVICE_NAME}#g" \
    -e "s#__STS_NAME__#${STS_NAME}#g" \
    -e "s#__AUTH_SECRET__#${AUTH_SECRET}#g" \
    -e "s#__PROBE_CONFIGMAP__#${PROBE_CONFIGMAP}#g" \
    -e "s#__INIT_CONFIGMAP__#${INIT_CONFIGMAP}#g" \
    -e "s#__MYSQL_CONFIGMAP__#${MYSQL_CONFIGMAP}#g" \
    -e "s#__NODEPORT_SERVICE_NAME__#${NODEPORT_SERVICE_NAME}#g" \
    -e "s#__NODE_PORT__#${NODE_PORT}#g" \
    -e "s#__METRICS_SERVICE_NAME__#${METRICS_SERVICE_NAME}#g" \
    -e "s#__METRICS_PORT__#${METRICS_PORT}#g" \
    -e "s#__SERVICE_MONITOR_NAME__#${SERVICE_MONITOR_NAME}#g" \
    -e "s#__SERVICE_MONITOR_INTERVAL__#${SERVICE_MONITOR_INTERVAL}#g" \
    -e "s#__SERVICE_MONITOR_SCRAPE_TIMEOUT__#${SERVICE_MONITOR_SCRAPE_TIMEOUT}#g" \
    -e "s#__ADDON_EXPORTER_DEPLOYMENT_NAME__#${ADDON_EXPORTER_DEPLOYMENT_NAME}#g" \
    -e "s#__ADDON_EXPORTER_SERVICE_NAME__#${ADDON_EXPORTER_SERVICE_NAME}#g" \
    -e "s#__ADDON_EXPORTER_SECRET__#${ADDON_EXPORTER_SECRET}#g" \
    -e "s#__ADDON_EXPORTER_USERNAME__#${ADDON_EXPORTER_USERNAME}#g" \
    -e "s#__ADDON_EXPORTER_PASSWORD__#${ADDON_EXPORTER_PASSWORD}#g" \
    -e "s#__ADDON_MONITORING_TARGET__#${ADDON_MONITORING_TARGET}#g" \
    -e "s#__ADDON_SERVICE_MONITOR_NAME__#${ADDON_SERVICE_MONITOR_NAME}#g" \
    -e "s#__FLUENTBIT_CONFIGMAP__#${FLUENTBIT_CONFIGMAP}#g" \
    -e "s#__MYSQL_SLOW_QUERY_TIME__#${MYSQL_SLOW_QUERY_TIME}#g" \
    -e "s#__BACKUP_SCRIPT_CONFIGMAP__#${BACKUP_SCRIPT_CONFIGMAP}#g" \
    -e "s#__BACKUP_CRONJOB_NAME__#${BACKUP_CRONJOB_NAME}#g" \
    -e "s#__BACKUP_JOB_NAME__#${BACKUP_JOB_NAME:-mysql-backup-manual}#g" \
    -e "s#__BACKUP_STORAGE_SECRET__#${BACKUP_STORAGE_SECRET}#g" \
    -e "s#__BACKUP_NFS_SERVER__#${BACKUP_NFS_SERVER}#g" \
    -e "s#__BACKUP_NFS_PATH__#${BACKUP_NFS_PATH}#g" \
    -e "s#__BACKUP_ROOT_DIR__#${BACKUP_ROOT_DIR}#g" \
    -e "s#__BACKUP_SCHEDULE__#${BACKUP_SCHEDULE}#g" \
    -e "s#__BACKUP_RETENTION__#${BACKUP_RETENTION}#g" \
    -e "s#__RESTORE_SNAPSHOT__#${RESTORE_SNAPSHOT}#g" \
    -e "s#__MYSQL_RESTORE_MODE__#${MYSQL_RESTORE_MODE}#g" \
    -e "s#__S3_ENDPOINT__#${S3_ENDPOINT}#g" \
    -e "s#__S3_BUCKET__#${S3_BUCKET}#g" \
    -e "s#__S3_PREFIX__#${S3_PREFIX}#g" \
    -e "s#__S3_ACCESS_KEY__#${S3_ACCESS_KEY}#g" \
    -e "s#__S3_SECRET_KEY__#${S3_SECRET_KEY}#g" \
    -e "s#__S3_INSECURE__#${S3_INSECURE}#g" \
    -e "s#__MYSQL_HOST__#${MYSQL_HOST}#g" \
    -e "s#__MYSQL_PORT__#${MYSQL_PORT}#g" \
    -e "s#__MYSQL_USER__#${MYSQL_USER}#g" \
    -e "s#__MYSQL_AUTH_SECRET__#${MYSQL_AUTH_SECRET}#g" \
    -e "s#__MYSQL_PASSWORD_KEY__#${MYSQL_PASSWORD_KEY}#g" \
    -e "s#__MYSQL_TARGET_NAME__#${MYSQL_TARGET_NAME}#g" \
    -e "s#__MYSQL_IMAGE__#${MYSQL_IMAGE}#g" \
    -e "s#__MYSQL_EXPORTER_IMAGE__#${MYSQL_EXPORTER_IMAGE}#g" \
    -e "s#__FLUENTBIT_IMAGE__#${FLUENTBIT_IMAGE}#g" \
    -e "s#__S3_CLIENT_IMAGE__#${S3_CLIENT_IMAGE}#g" \
    -e "s#__BUSYBOX_IMAGE__#${BUSYBOX_IMAGE}#g" \
    -e "s#__SYSBENCH_IMAGE__#${SYSBENCH_IMAGE}#g" \
    -e "s#__RESTORE_JOB_NAME__#${RESTORE_JOB_NAME:-mysql-restore}#g" \
    -e "s#__BENCHMARK_JOB_NAME__#${BENCHMARK_JOB_NAME:-mysql-benchmark}#g" \
    -e "s#__BENCHMARK_CONCURRENCY__#${BENCHMARK_THREADS}#g" \
    -e "s#__BENCHMARK_THREADS__#${BENCHMARK_THREADS}#g" \
    -e "s#__BENCHMARK_TIME__#${BENCHMARK_TIME}#g" \
    -e "s#__BENCHMARK_WARMUP_TIME__#${BENCHMARK_WARMUP_TIME}#g" \
    -e "s#__BENCHMARK_WARMUP_ROWS__#${BENCHMARK_WARMUP_ROWS}#g" \
    -e "s#__BENCHMARK_TABLES__#${BENCHMARK_TABLES}#g" \
    -e "s#__BENCHMARK_TABLE_SIZE__#${BENCHMARK_TABLE_SIZE}#g" \
    -e "s#__BENCHMARK_DB__#${BENCHMARK_DB}#g" \
    -e "s#__BENCHMARK_RAND_TYPE__#${BENCHMARK_RAND_TYPE}#g" \
    -e "s#__BENCHMARK_KEEP_DATA__#${BENCHMARK_KEEP_DATA}#g" \
    -e "s#__BENCHMARK_PROFILE__#${BENCHMARK_PROFILE}#g" \
    -e "s#__BENCHMARK_HOST__#${BENCHMARK_HOST}#g" \
    -e "s#__BENCHMARK_PORT__#${BENCHMARK_PORT}#g" \
    -e "s#__BENCHMARK_USER__#${BENCHMARK_USER}#g"
}

apply_backup_support_manifests() {
  render_manifest "${BACKUP_SUPPORT_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_backup_schedule_manifests() {
  render_manifest "${BACKUP_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_restore_job() {
  render_manifest "${RESTORE_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_benchmark_job() {
  render_manifest "${BENCHMARK_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


validate_inputs() {
  [[ "${NODEPORT_ENABLED}" =~ ^(true|false)$ ]] || die "--nodeport-enabled 仅支持 true 或 false"

  if [[ "${ACTION}" != "addon-status" ]]; then
    [[ "${MYSQL_REPLICAS}" =~ ^[0-9]+$ ]] || die "mysql 副本数必须是数字"
    if [[ "${NODEPORT_ENABLED}" == "true" ]]; then
      [[ "${NODE_PORT}" =~ ^[0-9]+$ ]] || die "nodePort 必须是数字"
      (( NODE_PORT >= 30000 && NODE_PORT <= 32767 )) || die "nodePort 必须在 30000-32767 之间"
    fi
  fi

  [[ "${MYSQL_PORT}" =~ ^[0-9]+$ ]] || die "MySQL 端口必须是数字"
  [[ "${BACKUP_RETENTION}" =~ ^[0-9]+$ ]] || die "备份保留数量必须是数字"
  [[ "${BENCHMARK_THREADS}" =~ ^[0-9]+$ ]] || die "压测线程数必须是数字"
  [[ "${BENCHMARK_TIME}" =~ ^[0-9]+$ ]] || die "压测时长必须是数字"
  [[ "${BENCHMARK_WARMUP_TIME}" =~ ^[0-9]+$ ]] || die "压测 warmup 时长必须是数字"
  [[ "${BENCHMARK_WARMUP_ROWS}" =~ ^[0-9]+$ ]] || die "压测 warmup 数据量必须是数字"
  [[ "${BENCHMARK_TABLES}" =~ ^[0-9]+$ ]] || die "压测表数必须是数字"
  [[ "${BENCHMARK_TABLE_SIZE}" =~ ^[0-9]+$ ]] || die "压测单表数据量必须是数字"
  [[ "${MYSQL_SLOW_QUERY_TIME}" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "慢查询阈值必须是数字"
  [[ "${BACKUP_BACKEND}" == "nfs" || "${BACKUP_BACKEND}" == "s3" ]] || die "备份后端仅支持 nfs 或 s3"
  [[ "${MYSQL_RESTORE_MODE}" =~ ^(merge|wipe-all-user-databases)$ ]] || die "restore-mode 仅支持 merge 或 wipe-all-user-databases"
  [[ "${BENCHMARK_PROFILE}" =~ ^(standard|oltp-point-select|oltp-read-only|oltp-read-write)$ ]] || die "benchmark-profile 仅支持 standard、oltp-point-select、oltp-read-only、oltp-read-write"

  if needs_backup_storage && backup_backend_is_nfs && [[ -z "${BACKUP_NFS_SERVER}" ]]; then
    die "使用 NFS 备份时必须提供 --backup-nfs-server"
  fi

  if needs_backup_storage && backup_backend_is_s3; then
    [[ -n "${S3_ENDPOINT}" ]] || die "使用 S3 备份时必须提供 --s3-endpoint"
    [[ -n "${S3_BUCKET}" ]] || die "使用 S3 备份时必须提供 --s3-bucket"
    [[ -n "${S3_ACCESS_KEY}" ]] || die "使用 S3 备份时必须提供 --s3-access-key"
    [[ -n "${S3_SECRET_KEY}" ]] || die "使用 S3 备份时必须提供 --s3-secret-key"
  fi

  validate_action_feature_gates
}
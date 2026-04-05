print_plan() {
  section "执行计划"
  echo "动作                    : ${ACTION}"
  echo "命名空间                : ${NAMESPACE}"
  echo "等待超时                : ${WAIT_TIMEOUT}"

  case "${ACTION}" in
    install)
      echo "StatefulSet             : ${STS_NAME}"
      echo "服务名                  : ${SERVICE_NAME}"
      echo "NodePort 开关           : ${NODEPORT_ENABLED}"
      if [[ "${NODEPORT_ENABLED}" == "true" ]]; then
        echo "NodePort 服务名         : ${NODEPORT_SERVICE_NAME}"
        echo "NodePort                : ${NODE_PORT}"
      fi
      echo "副本数                  : ${MYSQL_REPLICAS}"
      echo "StorageClass            : ${STORAGE_CLASS}"
      echo "存储大小                : ${STORAGE_SIZE}"
      echo "数据目录                : /var/lib/mysql（固定）"
      echo "镜像前缀                : ${REGISTRY_REPO}"
      echo "监控 exporter           : ${MONITORING_ENABLED}"
      echo "ServiceMonitor          : ${SERVICE_MONITOR_ENABLED}"
      echo "Fluent Bit              : ${FLUENTBIT_ENABLED}"
      echo "备份组件                : ${BACKUP_ENABLED}"
      echo "压测能力                : ${BENCHMARK_ENABLED}"
      echo "默认特性开关            : monitoring/service-monitor/fluentbit/backup/benchmark"
      echo "业务影响                : install 会整体对齐 StatefulSet，配置变化时可能触发滚动更新"
      ;;
    addon-install|addon-uninstall)
      echo "Addon 列表              : ${ADDONS}"
      echo "业务影响                : 默认只新增或删除外置资源，不修改 MySQL StatefulSet"
      if addon_selected monitoring; then
        echo "监控目标                : ${ADDON_MONITORING_TARGET}"
        echo "监控账号                : ${ADDON_EXPORTER_USERNAME}"
      fi
      if addon_selected backup; then
        echo "备份目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
        echo "备份账号                : ${MYSQL_USER}"
        echo "认证来源                : $(mysql_auth_source_summary)"
        echo "逻辑实例名              : ${MYSQL_TARGET_NAME}"
      fi
      ;;
    backup)
      echo "执行模式                : 立即执行一次备份 Job"
      echo "备份目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
      echo "备份账号                : ${MYSQL_USER}"
      echo "认证来源                : $(mysql_auth_source_summary)"
      echo "逻辑实例名              : ${MYSQL_TARGET_NAME}"
      echo "备份后端                : ${BACKUP_BACKEND}"
      echo "保留数量                : ${BACKUP_RETENTION}"
      echo "业务影响                : 只创建一次性备份 Job，不会安装 CronJob"
      ;;
    restore)
      echo "执行模式                : 立即执行一次恢复 Job"
      echo "恢复目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
      echo "恢复账号                : ${MYSQL_USER}"
      echo "认证来源                : $(mysql_auth_source_summary)"
      echo "逻辑实例名              : ${MYSQL_TARGET_NAME}"
      echo "恢复快照                : ${RESTORE_SNAPSHOT}"
      echo "恢复模式                : ${MYSQL_RESTORE_MODE}"
      echo "业务影响                : 会向目标实例导入 SQL，建议在维护窗口执行"
      ;;
    verify-backup-restore)
      echo "执行模式                : 备份/恢复闭环校验"
      echo "校验目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
      echo "校验账号                : ${MYSQL_USER}"
      echo "认证来源                : $(mysql_auth_source_summary)"
      echo "逻辑实例名              : ${MYSQL_TARGET_NAME}"
      echo "业务影响                : 会写入 offline_validation 库表用于校验"
      ;;
    benchmark)
      echo "执行模式                : 工程化压测 Job"
      echo "压测目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
      echo "压测账号                : ${MYSQL_USER}"
      echo "认证来源                : $(mysql_auth_source_summary)"
      echo "压测模型                : ${BENCHMARK_PROFILE}"
      echo "压测线程数              : ${BENCHMARK_THREADS}"
      echo "正式压测时长(秒)        : ${BENCHMARK_TIME}"
      echo "Warmup 时长(秒)         : ${BENCHMARK_WARMUP_TIME}"
      echo "Warmup 数据量(行)       : ${BENCHMARK_WARMUP_ROWS}"
      echo "压测表数                : ${BENCHMARK_TABLES}"
      echo "正式数据量(行)          : ${BENCHMARK_TABLE_SIZE}"
      echo "压测数据库              : ${BENCHMARK_DB}"
      echo "随机分布                : ${BENCHMARK_RAND_TYPE}"
      echo "保留测试数据            : ${BENCHMARK_KEEP_DATA}"
      echo "报告目录                : ${REPORT_DIR}"
      echo "自动等待超时            : $(job_wait_timeout benchmark)"
      ;;
  esac

  if needs_backup_storage; then
    echo "备份根目录              : ${BACKUP_ROOT_DIR}"
    if backup_schedule_required; then
      echo "备份计划                : ${BACKUP_SCHEDULE}"
    fi
    if backup_backend_is_nfs; then
      echo "NFS 服务地址            : ${BACKUP_NFS_SERVER}"
      echo "NFS 导出路径            : ${BACKUP_NFS_PATH}"
    else
      echo "S3 Endpoint             : ${S3_ENDPOINT}"
      echo "S3 Bucket               : ${S3_BUCKET}"
      echo "S3 Prefix               : ${S3_PREFIX:-<空>}"
      echo "S3 Insecure             : ${S3_INSECURE}"
    fi
  fi
}

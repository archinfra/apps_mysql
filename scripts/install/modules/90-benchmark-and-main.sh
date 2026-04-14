extract_benchmark_report_block() {
  local content="$1"
  local start_marker="$2"
  local end_marker="$3"

  printf '%s\n' "${content}" | awk -v start="${start_marker}" -v end="${end_marker}" '
    $0 == start { in_block=1; next }
    $0 == end { in_block=0; exit }
    in_block { print }
  '
}


run_benchmark() {
  extract_payload
  prepare_images
  ensure_namespace
  preflight_mysql_connection "预检压测目标连接"

  section "执行压测"
  local benchmark_job report_body report_text report_json log_path text_path json_path
  benchmark_job="$(create_benchmark_job)"
  wait_for_job "${benchmark_job}" "benchmark" || die "压测任务失败，请根据上面的 Job/Pod 日志继续排查"

  report_body="$(kubectl logs -n "${NAMESPACE}" "job/${benchmark_job}" --tail=-1)"
  log_path="$(write_report "${benchmark_job}.log" "${report_body}")"
  report_text="$(extract_benchmark_report_block "${report_body}" "__MYSQL_BENCHMARK_REPORT_TEXT_START__" "__MYSQL_BENCHMARK_REPORT_TEXT_END__")"
  report_json="$(extract_benchmark_report_block "${report_body}" "__MYSQL_BENCHMARK_REPORT_JSON_START__" "__MYSQL_BENCHMARK_REPORT_JSON_END__")"

  if [[ -z "${report_text}" ]]; then
    report_text="${report_body}"
  fi

  text_path="$(write_report "${benchmark_job}.txt" "${report_text}")"
  if [[ -n "${report_json}" ]]; then
    json_path="$(write_report "${benchmark_job}.json" "${report_json}")"
  fi

  success "压测完成"
  echo "完整日志: ${log_path}"
  echo "文本报告: ${text_path}"
  [[ -n "${json_path:-}" ]] && echo "JSON 报告: ${json_path}"
}


show_post_install_notes() {
  section "后续建议"

  if [[ "${NODEPORT_ENABLED}" == "true" ]]; then
    cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}
kubectl get pvc -n ${NAMESPACE}
$( [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && echo "kubectl get servicemonitor -n ${NAMESPACE}" )
$( [[ "${DATA_PROTECTION_APPLIED}" == "true" ]] && echo "kubectl get backupsources.dataprotection.archinfra.io -n ${BACKUP_NAMESPACE} ${BACKUP_SOURCE_NAME}" )
$( [[ "${DATA_PROTECTION_APPLIED}" == "true" ]] && echo "kubectl get backuppolicies.dataprotection.archinfra.io -n ${BACKUP_NAMESPACE} ${BACKUP_POLICY_NAME}" )
kubectl logs -n ${NAMESPACE} ${STS_NAME}-0 -c mysql --tail=200
$( [[ "${FLUENTBIT_ENABLED}" == "true" ]] && echo "kubectl logs -n ${NAMESPACE} ${STS_NAME}-0 -c fluent-bit --tail=200" )

集群内访问地址:
${STS_NAME}-0.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:3306

NodePort 访问地址:
<node-ip>:${NODE_PORT}

数据复用关键条件:
1. uninstall 时不要加 --delete-pvc
2. namespace 与 --sts-name 保持不变
3. 再次执行 install 即可按当前开关重新对齐
4. MySQL 备份恢复通过 dataprotection 管理，不再单独交付 addon runner 镜像
$( if [[ "${DATA_PROTECTION_APPLIED}" == "true" ]]; then echo "5. 已在 ${BACKUP_NAMESPACE} 注册 BackupSource/${BACKUP_SOURCE_NAME} 与 BackupPolicy/${BACKUP_POLICY_NAME}"; elif [[ "${DATA_PROTECTION_ENABLED}" == "true" ]]; then echo "5. 本次未完成数据保护注册，请确认 dataprotection CRD 与 BackupStorage/${BACKUP_PRIMARY_STORAGE_NAME} 是否已就绪"; fi )
EOF
    return 0
  fi

  cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}
kubectl get pvc -n ${NAMESPACE}
$( [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && echo "kubectl get servicemonitor -n ${NAMESPACE}" )
$( [[ "${DATA_PROTECTION_APPLIED}" == "true" ]] && echo "kubectl get backupsources.dataprotection.archinfra.io -n ${BACKUP_NAMESPACE} ${BACKUP_SOURCE_NAME}" )
$( [[ "${DATA_PROTECTION_APPLIED}" == "true" ]] && echo "kubectl get backuppolicies.dataprotection.archinfra.io -n ${BACKUP_NAMESPACE} ${BACKUP_POLICY_NAME}" )
kubectl logs -n ${NAMESPACE} ${STS_NAME}-0 -c mysql --tail=200
$( [[ "${FLUENTBIT_ENABLED}" == "true" ]] && echo "kubectl logs -n ${NAMESPACE} ${STS_NAME}-0 -c fluent-bit --tail=200" )

集群内访问地址:
${STS_NAME}-0.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:3306

NodePort 访问:
已关闭

数据复用关键条件:
1. uninstall 时不要加 --delete-pvc
2. namespace 与 --sts-name 保持不变
3. 再次执行 install 即可按当前开关重新对齐
4. MySQL 备份恢复通过 dataprotection 管理，不再单独交付 addon runner 镜像
$( if [[ "${DATA_PROTECTION_APPLIED}" == "true" ]]; then echo "5. 已在 ${BACKUP_NAMESPACE} 注册 BackupSource/${BACKUP_SOURCE_NAME} 与 BackupPolicy/${BACKUP_POLICY_NAME}"; elif [[ "${DATA_PROTECTION_ENABLED}" == "true" ]]; then echo "5. 本次未完成数据保护注册，请确认 dataprotection CRD 与 BackupStorage/${BACKUP_PRIMARY_STORAGE_NAME} 是否已就绪"; fi )
EOF
}


show_post_addon_notes() {
  section "Addon 后续建议"
  cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get deploy -n ${NAMESPACE}
$( cluster_supports_service_monitor && echo "kubectl get servicemonitor -n ${NAMESPACE}" )

业务影响说明:
1. addon-install 默认不修改 MySQL StatefulSet
2. monitoring addon 会额外创建 exporter Deployment
3. 如需日志 sidecar，请改用 install，并提前评估滚动更新窗口
4. 备份恢复能力已迁移到独立数据保护系统
EOF
}


cleanup() {
  :
}


main() {
  trap cleanup EXIT

  parse_args "$@"

  banner
  if [[ "${ACTION}" == "help" ]]; then
    show_help
    exit 0
  fi

  resolve_feature_dependencies
  prompt_missing_values
  validate_environment
  validate_inputs
  prepare_runtime_auth_secret

  if [[ "${ACTION}" != "status" && "${ACTION}" != "addon-status" ]]; then
    confirm_plan
  fi

  case "${ACTION}" in
    install)
      install_app
      show_post_install_notes
      ;;
    addon-install)
      install_addons
      show_post_addon_notes
      ;;
    addon-uninstall)
      uninstall_addons
      ;;
    addon-status)
      show_addon_status
      ;;
    uninstall)
      uninstall_app
      ;;
    status)
      show_status
      ;;
    benchmark)
      run_benchmark
      ;;
    *)
      die "不支持的动作: ${ACTION}"
      ;;
  esac
}

main "$@"

exit 0

__PAYLOAD_BELOW__

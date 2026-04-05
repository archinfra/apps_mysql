show_post_addon_notes() {
  section "Addon 后续建议"
  cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get deploy -n ${NAMESPACE}
kubectl get cronjob -n ${NAMESPACE}
$( cluster_supports_service_monitor && echo "kubectl get servicemonitor -n ${NAMESPACE}" )

业务影响说明:
1. addon-install 默认不修改 MySQL StatefulSet
2. monitoring addon 会额外创建 exporter Deployment
3. backup addon 会额外创建 CronJob
4. 如需日志 sidecar，请改用 install，并提前评估滚动更新窗口
EOF
}


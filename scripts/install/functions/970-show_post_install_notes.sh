show_post_install_notes() {
  section "后续建议"

  if [[ "${NODEPORT_ENABLED}" == "true" ]]; then
    cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}
kubectl get pvc -n ${NAMESPACE}
$( [[ "${BACKUP_ENABLED}" == "true" ]] && echo "kubectl get cronjob -n ${NAMESPACE}" )
$( [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && echo "kubectl get servicemonitor -n ${NAMESPACE}" )

集群内访问地址:
${STS_NAME}-0.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:3306

NodePort 访问地址:
<node-ip>:${NODE_PORT}

数据复用关键条件:
1. uninstall 时不要加 --delete-pvc
2. namespace 与 --sts-name 保持不变
3. 再次执行 install 即可按当前开关重新对齐
EOF
    return 0
  fi

  cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}
kubectl get pvc -n ${NAMESPACE}
$( [[ "${BACKUP_ENABLED}" == "true" ]] && echo "kubectl get cronjob -n ${NAMESPACE}" )
$( [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && echo "kubectl get servicemonitor -n ${NAMESPACE}" )

集群内访问地址:
${STS_NAME}-0.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:3306

NodePort 访问:
已关闭

数据复用关键条件:
1. uninstall 时不要加 --delete-pvc
2. namespace 与 --sts-name 保持不变
3. 再次执行 install 即可按当前开关重新对齐
EOF
}

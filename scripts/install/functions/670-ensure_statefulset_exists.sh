ensure_statefulset_exists() {
  kubectl get statefulset "${STS_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1 || die "未找到 StatefulSet/${STS_NAME}，请先确认 MySQL 已存在"
}


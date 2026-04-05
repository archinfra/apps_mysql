require_namespace_exists() {
  namespace_exists || die "未找到命名空间 ${NAMESPACE}"
}


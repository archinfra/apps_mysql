show_help_logging() {
  cat <<'EOF'
日志能力建议分两层:

平台层:
  DaemonSet Fluent Bit + ES/OpenSearch/Loki
  统一采集容器 stdout/stderr

应用层:
  MySQL sidecar Fluent Bit
  直接采 slow log / error log 文件

当前推荐:
  1. 已建设平台日志体系时，不建议再做 MySQL sidecar。
  2. addon 路径不提供 logging addon。
  3. install --enable-fluentbit 仅保留给必须采容器内日志文件的场景。

日志落点:
  1. 默认模式下，研发优先看容器 stdout/stderr。
  2. 启用 fluentbit sidecar 后，MySQL 会把 error log / slow log 写到 /var/log/mysql/*.log。
  3. sidecar 负责 tail 这些文件并输出到自己的 stdout，便于被平台日志系统继续采走。

研发快速排查:
  1. 查看 MySQL 容器日志:
     kubectl logs -n <ns> <pod> -c mysql --tail=200
  2. 查看 sidecar 日志:
     kubectl logs -n <ns> <pod> -c fluent-bit --tail=200
  3. 直接进入 Pod 看日志文件:
     kubectl exec -n <ns> <pod> -c mysql -- ls -l /var/log/mysql
     kubectl exec -n <ns> <pod> -c mysql -- tail -n 200 /var/log/mysql/error.log
     kubectl exec -n <ns> <pod> -c mysql -- tail -n 200 /var/log/mysql/slow.log
EOF
}


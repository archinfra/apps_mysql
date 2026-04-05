show_help_architecture() {
  cat <<'EOF'
能力分层:
  install
    负责 MySQL 本体、StatefulSet、Service、PVC，以及 sidecar 型能力

  addon-install
    负责已有 MySQL 的外置能力补齐，例如 exporter Deployment、ServiceMonitor、backup CronJob

为什么监控能做 addon，而日志默认不做:
  1. exporter 可以外置成独立 Deployment。
  2. slow log 文件采集通常需要 sidecar 进入同一个 Pod。
EOF
}


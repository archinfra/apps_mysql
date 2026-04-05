show_help_addons() {
  cat <<'EOF'
addon-install / addon-uninstall / addon-status 面向“已有 MySQL 补能力”。

支持的 addon:
  monitoring
    外置 mysqld-exporter Deployment + Service
    默认新增独立 Pod，不修改 MySQL StatefulSet

  service-monitor
    仅创建 ServiceMonitor 声明
    自动依赖 monitoring

  backup
    安装备份支持资源 + CronJob
    不会重启 MySQL Pod

addon 参数:
  --addons <list>                   必填，逗号分隔: monitoring,service-monitor,backup
  --monitoring-target <host:port>   监控目标地址；已有外部 MySQL 时建议显式指定
  --exporter-user <user>            默认: mysqld_exporter
  --exporter-password <password>    默认: exporter@passw0rd

补备份能力时建议同时给出:
  --mysql-host <host>
  --mysql-port <port>
  --mysql-user <user>
  --mysql-password <password>
  或:
  --mysql-auth-secret <name> --mysql-password-key <key>

日志决策:
  1. 已有平台级日志体系时，不建议给 MySQL 叠加 sidecar。
  2. addon 路径不提供 logging addon，因为它会改 StatefulSet。
  3. 必须采 slow log 文件时，再使用 install --enable-fluentbit。
EOF
}


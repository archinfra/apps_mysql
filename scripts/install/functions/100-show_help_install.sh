show_help_install() {
  cat <<'EOF'
install 适合:
  1. 首次安装 MySQL
  2. 调整副本数、存储、Service 等配置后重新对齐
  3. 启用或关闭监控、日志、备份、压测等能力

常用参数:
  -n, --namespace <ns>              默认: aict
  --root-password <password>        默认: passw0rd
  --auth-secret <name>              默认: mysql-auth
  --mysql-replicas <num>            默认: 1
  --storage-class <name>            默认: nfs
  --storage-size <size>             默认: 10Gi
  --service-name <name>             默认: mysql
  --sts-name <name>                 默认: mysql
  --nodeport-service-name <name>    默认: mysql-nodeport
  --node-port <port>                默认: 30306
  --nodeport-enabled true|false     默认: true
  --enable-nodeport / --disable-nodeport
  --registry <repo-prefix>          例如: harbor.example.com/kube4
  --mysql-slow-query-time <sec>     默认: 2
  --wait-timeout <duration>         默认: 10m

备份相关:
  --backup-backend nfs|s3           默认: nfs
  --backup-root-dir <dir>           默认: backups
  --backup-nfs-server <addr>
  --backup-nfs-path <path>          默认: /data/nfs-share

功能开关:
  默认启用 monitoring / service-monitor / fluentbit / backup / benchmark
  --enable-monitoring / --disable-monitoring
  --enable-service-monitor / --disable-service-monitor
  --enable-fluentbit / --disable-fluentbit
  --enable-backup / --disable-backup
  --enable-benchmark / --disable-benchmark

说明:
  1. install 会对 StatefulSet 及相关资源做声明式对齐
  2. 如果 MySQL 配置或 sidecar 发生变化，可能触发滚动更新
  3. 如果只是补装备份或外置监控，优先使用 addon-install
EOF
}

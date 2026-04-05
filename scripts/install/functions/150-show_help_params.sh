show_help_params() {
  cat <<'EOF'
核心参数速查:
  --namespace <ns>
  --service-name <name>
  --sts-name <name>
  --auth-secret <name>
  --root-password <password>
  --wait-timeout <duration>
  -y, --yes

镜像与仓库:
  --registry <repo-prefix>
  --skip-image-prepare

NodePort:
  --nodeport-enabled true|false
  --enable-nodeport
  --disable-nodeport
  --node-port <port>
  --nodeport-service-name <name>

MySQL 目标连接:
  --mysql-host <host>
  --mysql-port <port>
  --mysql-user <user>
  --mysql-password <password>
  --mysql-auth-secret <name>
  --mysql-password-key <key>
  --mysql-target-name <name>

备份存储:
  --backup-backend nfs|s3
  --backup-root-dir <dir>
  --backup-nfs-server <addr>
  --backup-nfs-path <path>
  --backup-schedule <cron>
  --backup-retention <num>
  --s3-endpoint <url>
  --s3-bucket <name>
  --s3-prefix <dir>
  --s3-access-key <key>
  --s3-secret-key <key>
  --s3-insecure true|false

压测:
  --benchmark-profile <name>
  --benchmark-threads <num>
  --benchmark-time <sec>
  --benchmark-warmup-time <sec>
  --benchmark-warmup-rows <rows>
  --benchmark-tables <num>
  --benchmark-table-size <rows>
  --benchmark-db <name>
  --benchmark-rand-type <name>
  --benchmark-keep-data true|false
  --report-dir <dir>
EOF
}

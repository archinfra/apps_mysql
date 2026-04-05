show_help_backup() {
  cat <<'EOF'
请区分两个动作:

场景 A: 安装备份组件
  install --enable-backup
  addon-install --addons backup

场景 B: 立即执行一次备份
  backup

区别:
  1. 场景 A 会安装 ConfigMap / Secret / CronJob 等资源
  2. 场景 B 只会创建一次性 Job，不会安装定时 CronJob

目标连接参数:
  --mysql-host <host>               默认推导为 <sts>-0.<svc>.<ns>.svc.cluster.local
  --mysql-port <port>               默认: 3306
  --mysql-user <user>               默认: root
  --mysql-password <password>       推荐立即动作显式传入
  --mysql-auth-secret <name>        使用已有 Secret
  --mysql-password-key <key>        Secret 中密码键名
  --mysql-target-name <name>        备份目录中的逻辑实例名

认证要求:
  1. backup / restore / verify-backup-restore 不再回退到 --root-password
  2. 这类动作请显式提供 --mysql-password，或提供可用的 --mysql-auth-secret

NFS 参数:
  --backup-backend nfs
  --backup-nfs-server <addr>
  --backup-nfs-path <path>          默认: /data/nfs-share
  --backup-root-dir <dir>           默认: backups
  --backup-retention <num>          默认: 5

S3 参数:
  --backup-backend s3
  --s3-endpoint <url>
  --s3-bucket <name>
  --s3-prefix <dir>
  --s3-access-key <key>
  --s3-secret-key <key>
EOF
}

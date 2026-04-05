show_help_examples() {
  cat <<'EOF'
常见示例:

首次安装:
  ./mysql-installer.run install \
    --namespace mysql-demo \
    --root-password 'StrongPassw0rd' \
    --storage-class nfs \
    --storage-size 20Gi \
    --backup-backend nfs \
    --backup-nfs-server 192.168.10.2 \
    --backup-nfs-path /data/nfs-share \
    --backup-root-dir backups \
    -y

已有 MySQL 安装定时备份组件:
  ./mysql-installer.run addon-install \
    --namespace mysql-demo \
    --addons backup \
    --mysql-host 10.0.0.20 \
    --mysql-port 3306 \
    --mysql-user root \
    --mysql-password '<MYSQL_PASSWORD>' \
    --mysql-target-name mysql-prod \
    --backup-backend nfs \
    --backup-nfs-server 192.168.10.2 \
    --backup-nfs-path /data/nfs-share \
    --backup-root-dir backups \
    --backup-schedule '0 2 * * *' \
    -y

立即执行一次备份:
  ./mysql-installer.run backup \
    --namespace mysql-demo \
    --mysql-host 10.0.0.20 \
    --mysql-port 3306 \
    --mysql-user root \
    --mysql-password '<MYSQL_PASSWORD>' \
    --mysql-target-name mysql-prod \
    --backup-backend nfs \
    --backup-nfs-server 192.168.10.2 \
    --backup-nfs-path /data/nfs-share \
    --backup-root-dir backups \
    -y

独立压测:
  ./mysql-installer.run benchmark \
    --namespace mysql-demo \
    --mysql-host 10.0.0.20 \
    --mysql-port 3306 \
    --mysql-user root \
    --mysql-password '<MYSQL_PASSWORD>' \
    --benchmark-profile standard \
    --benchmark-threads 64 \
    --benchmark-time 300 \
    --benchmark-warmup-time 60 \
    --benchmark-tables 16 \
    --benchmark-table-size 200000 \
    --report-dir ./reports \
    -y
EOF
}


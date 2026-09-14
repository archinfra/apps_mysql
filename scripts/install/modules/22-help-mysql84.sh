# MySQL 8.4 help overrides loaded after 20-help.sh.

show_help_install() {
  local cmd="./mysql-installer-<arch>.run"

  cat <<EOF
install 仅在 integrated 包中可用，当前交付基线为 MySQL 8.4.11 LTS，单实例模式。

常用参数:
  -n, --namespace <ns>              默认: aict
  --root-password <password>        默认: 自动生成随机密码；已有 Secret/${AUTH_SECRET} 时复用
  --auth-secret <name>              默认: mysql-auth
  --mysql-replicas <num>            固定: 1（当前不提供伪多副本）
  --storage-class <name>            默认: nfs；生产建议显式改为块存储类
  --storage-size <size>              默认: 20Gi
  --service-name <name>             默认: mysql
  --sts-name <name>                 默认: mysql
  --enable-nodeport                 默认关闭；确需集群外直连时显式开启
  --node-port <port>                默认: 30306
  --enable-monitoring / --disable-monitoring
  --enable-service-monitor / --disable-service-monitor
  --enable-fluentbit / --disable-fluentbit
  --enable-data-protection / --disable-data-protection
  --resource-profile <name>         默认: mid，支持 low|mid|midd|high
  --mysql-slow-query-time <seconds> 默认: 2
  --registry <repo-prefix>          例如: harbor.example.com/kube4
  --wait-timeout <duration>         默认: 10m

默认安全/性能基线:
  - NodePort 默认关闭
  - root 与 exporter 密码不再使用固定默认值
  - local_infile=OFF、skip_name_resolve=ON、mysqlx=0
  - InnoDB durability: innodb_flush_log_at_trx_commit=1、sync_binlog=1
  - binlog ROW + GTID，保留 7 天
  - performance_schema 与 slow query log 默认开启
  - mysqld-exporter v0.19.0 使用独立低权限账号

示例:
  ${cmd} install \
    --namespace mysql-prod \
    --storage-class ceph-rbd \
    --storage-size 100Gi \
    --root-password 'StrongPassw0rd!' \
    --resource-profile high \
    -y

查看自动生成的 root 密码:
  kubectl get secret -n <namespace> mysql-auth -o jsonpath='{.data.mysql-root-password}' | base64 -d; echo
EOF
}


show_help_params() {
  cat <<'EOF'
核心参数速查:
  --namespace <ns>
  --service-name <name>
  --sts-name <name>
  --auth-secret <name>
  --root-password <password>        不传则首次安装自动生成
  --wait-timeout <duration>
  -y, --yes

镜像与仓库:
  --registry <repo-prefix>
  --skip-image-prepare

访问暴露:
  --enable-nodeport                默认关闭
  --disable-nodeport
  --node-port <port>
  --nodeport-service-name <name>

监控:
  --addons monitoring,service-monitor
  --monitoring-target <host:port>
  --exporter-user <user>
  --exporter-password <password>   不传则自动生成
  --enable-monitoring / --disable-monitoring
  --enable-service-monitor / --disable-service-monitor

运行配置:
  --resource-profile <low|mid|midd|high>
  --storage-class <name>
  --storage-size <size>
  --mysql-slow-query-time <seconds>

数据保护:
  --enable-data-protection / --disable-data-protection
  --backup-namespace <ns>
  --backup-storage-name <name>
  --backup-secondary-storage-name <name>
  --backup-schedule <cron>
  --backup-retention-ref <name>
  --backup-notification-ref <name>
  --backup-database <name>
EOF
}

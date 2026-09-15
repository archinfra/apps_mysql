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
  --enable-remote-root              默认开启；创建并幂等对齐 root@<host>
  --disable-remote-root             删除安装器管理的远程 root
  --root-remote-host <host>         默认: %
  --enable-native-password          默认开启 mysql_native_password 兼容插件
  --disable-native-password         仅在客户端全部支持 caching_sha2_password 后使用
  --enable-nodeport                 默认关闭；确需集群外直连时显式开启
  --node-port <port>                默认: 30306
  --resource-profile <name>         默认: mid，支持 low|mid|midd|high
  --innodb-buffer-pool-size <size>  覆盖资源档位默认值，例如 2G
  --mysql-log-size-limit <size>     MySQL 本地日志 emptyDir 上限，默认: 2Gi
  --enable-monitoring / --disable-monitoring
  --enable-service-monitor / --disable-service-monitor
  --enable-fluentbit / --disable-fluentbit
  --enable-data-protection / --disable-data-protection
  --mysql-slow-query-time <seconds> 默认: 2
  --registry <repo-prefix>          例如: harbor.example.com/kube4
  --wait-timeout <duration>         默认: 10m

默认安全/性能基线:
  - NodePort 默认关闭；remote root 默认只通过集群网络可达
  - root 与 exporter 密码不使用固定默认值
  - root@localhost 保留默认 caching_sha2_password；root@% 默认用于兼容旧客户端并使用 mysql_native_password
  - local_infile=OFF、skip_name_resolve=ON、mysqlx=0
  - utf8mb4 / utf8mb4_0900_ai_ci，数据库与错误日志统一 UTC
  - startupProbe 最长允许约 10 分钟启动；terminationGracePeriodSeconds=120
  - InnoDB durability: innodb_flush_log_at_trx_commit=1、sync_binlog=1
  - resource profile 会联动 InnoDB Buffer Pool: low=384M、mid=1G、high=2G
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
    --root-remote-host '%' \
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
  --enable-remote-root / --disable-remote-root
  --root-remote-host <host>         默认: %
  --enable-native-password / --disable-native-password
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
  --innodb-buffer-pool-size <size>
  --storage-class <name>
  --storage-size <size>
  --mysql-log-size-limit <size>
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

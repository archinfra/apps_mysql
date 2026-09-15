# MySQL 8.4 help overrides loaded after 20-help.sh.

show_help_install() {
  local cmd="./mysql-installer-<arch>.run"

  cat <<EOF
install 仅在 integrated 包中可用，当前交付基线为 MySQL 8.4.11 LTS，单实例模式。

资源规格（--resource-profile）:
  lite      精简模式：MySQL request 500m/1Gi，limit 1C/2Gi，Buffer Pool 1G，新装 PVC 默认 20Gi
  standard  标准模式：MySQL request 1C/4Gi，limit 2C/8Gi，Buffer Pool 5G，新装 PVC 默认 100Gi（默认）
  large     大规格模式：MySQL request 2C/8Gi，limit 4C/16Gi，Buffer Pool 10G，新装 PVC 默认 500Gi

重要说明:
  - resource-profile 只接受 lite / standard / large，其他名称直接报错，避免交付口径分叉。
  - 2C8G / 1C2G / 4C16G 指 MySQL 主容器 limit；request 默认约为 50%，便于 Kubernetes 调度。
  - mysqld-exporter / Fluent Bit / initContainer 有各自的小额资源开销，不计入上述 MySQL 主容器规格。
  - 新安装时，profile 同时给出 CPU、内存、InnoDB Buffer Pool 和 PVC 默认容量。
  - 已有 PVC 重跑 installer 时不会因为切换 profile 自动改盘；必须显式传 --storage-size 才尝试扩容。
  - Kubernetes PVC 不支持缩容；在线扩容要求 StorageClass.allowVolumeExpansion=true。
  - --storage-size 与 --innodb-buffer-pool-size 优先级高于 profile 默认值。

常用参数:
  -n, --namespace <ns>              默认: aict
  --root-password <password>        默认: 自动生成随机密码；已有 Secret/${AUTH_SECRET} 时复用
  --auth-secret <name>              默认: mysql-auth
  --mysql-replicas <num>            固定: 1（当前不提供伪多副本）
  --resource-profile <name>         默认: standard；仅支持 lite|standard|large
  --storage-class <name>            默认: nfs；生产建议显式改为块存储类
  --storage-size <size>             覆盖 profile 的 PVC 容量，例如 200Gi
  --innodb-buffer-pool-size <size>  覆盖 profile 的 Buffer Pool，例如 6G
  --mysql-log-size-limit <size>     MySQL 本地日志 emptyDir 上限，默认: 2Gi
  --service-name <name>             默认: mysql
  --sts-name <name>                 默认: mysql
  --enable-remote-root              默认开启；创建并幂等对齐 root@<host>
  --disable-remote-root             删除安装器管理的远程 root
  --root-remote-host <host>         默认: %
  --enable-native-password          默认开启 mysql_native_password 兼容插件
  --disable-native-password         仅在客户端全部支持 caching_sha2_password 后使用
  --enable-nodeport                 默认关闭；确需集群外直连时显式开启
  --node-port <port>                默认: 30306
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
  - resource profile 会联动 MySQL CPU / Memory、InnoDB Buffer Pool 和新装 PVC 默认容量
  - binlog ROW + GTID，保留 7 天
  - performance_schema 与 slow query log 默认开启
  - mysqld-exporter v0.19.0 使用独立低权限账号

示例一：默认标准模式（2C8G / 100Gi）
  ${cmd} install \
    --namespace mysql-prod \
    --storage-class ceph-rbd \
    --root-password 'StrongPassw0rd!' \
    --resource-profile standard \
    -y

示例二：精简模式（1C2G / 20Gi）
  ${cmd} install \
    --namespace mysql-lite \
    --resource-profile lite \
    --storage-class nfs \
    --disable-data-protection \
    -y

示例三：大规格模式并覆盖默认磁盘
  ${cmd} install \
    --namespace mysql-large \
    --resource-profile large \
    --storage-class ceph-rbd \
    --storage-size 1Ti \
    --innodb-buffer-pool-size 11G \
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

资源与存储:
  --resource-profile <lite|standard|large>
      lite      MySQL limit 1C/2Gi，request 500m/1Gi，Buffer Pool 1G，PVC 默认 20Gi
      standard  MySQL limit 2C/8Gi，request 1C/4Gi，Buffer Pool 5G，PVC 默认 100Gi（默认）
      large     MySQL limit 4C/16Gi，request 2C/8Gi，Buffer Pool 10G，PVC 默认 500Gi
  --storage-class <name>            默认 nfs；生产建议 Ceph RBD / SAN / Local PV / 云盘
  --storage-size <size>             显式覆盖 profile，例如 200Gi、1Ti
  --innodb-buffer-pool-size <size>  显式覆盖 profile，例如 6G、12G
  --mysql-log-size-limit <size>     默认 2Gi
  --mysql-slow-query-time <seconds> 默认 2

存储 reconcile 规则:
  - 新装：profile 决定默认 PVC 大小。
  - 已有 PVC + 未传 --storage-size：保留当前 PVC，不随 profile 自动扩缩容。
  - 已有 PVC + 显式 --storage-size：installer 对 PVC 发起 resize。
  - PVC 不允许缩容；扩容依赖 StorageClass.allowVolumeExpansion=true。
  - StatefulSet volumeClaimTemplates 是 immutable，installer 会保留原模板容量并直接管理现有 PVC 的扩容。

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

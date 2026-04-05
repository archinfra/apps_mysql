show_help_overview() {
  cat <<'EOF'
用法:
  ./mysql-installer.run <动作> [参数]
  ./mysql-installer.run help [主题]

动作:
  install                 安装或整套对齐 MySQL 及内嵌能力
  uninstall               卸载资源，默认保留 PVC
  status                  查看当前资源状态
  addon-install           给已有 MySQL 单独补齐外置能力
  addon-uninstall         单独移除外置能力
  addon-status            查看 addon 状态与影响边界
  backup                  立即执行一次备份 Job
  restore                 立即执行一次恢复 Job
  verify-backup-restore   执行备份/恢复闭环校验
  benchmark               执行工程化压测
  help                    查看中文帮助

help 主题:
  overview
  install
  addons
  backup
  restore
  benchmark
  params
  backup-restore
  logging
  architecture
  examples

关键设计:
  1. install 是“整套声明式对齐”，不是一次性初始化脚本。
  2. addon-install 面向“已有 MySQL 补能力”，尽量只新增资源，不改 MySQL StatefulSet。
  3. backup 是“立刻备份一次”，addon-install --addons backup 才是“安装定时备份组件”。
  4. 日志默认推荐平台层 DaemonSet Fluent Bit + ES/OpenSearch/Loki。
EOF
}


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

show_help_restore() {
  cat <<'EOF'
restore 用于从备份快照恢复 MySQL。

常用参数:
  --mysql-host <host>
  --mysql-port <port>               默认: 3306
  --mysql-user <user>               默认: root
  --mysql-password <password>       推荐显式传入
  --mysql-auth-secret <name>        使用已有 Secret
  --mysql-password-key <key>        Secret 中密码键名
  --mysql-target-name <name>        备份目录中的逻辑实例名
  --restore-snapshot <name|latest>  默认: latest
  --mysql-restore-mode merge|replace 默认: merge

说明:
  1. latest 会优先读取 latest.txt
  2. 如果 latest.txt 指向的快照已不存在，会自动回退到最新的 .sql.gz
  3. restore 会直接向目标实例导入 SQL，请在维护窗口执行
EOF
}

show_help_benchmark() {
  cat <<'EOF'
benchmark 会创建一次性 Job，对目标 MySQL 执行 sysbench 压测。

常用参数:
  --mysql-host <host>
  --mysql-port <port>                    默认: 3306
  --mysql-user <user>                    默认: root
  --mysql-password <password>            推荐显式传入
  --benchmark-profile <name>             默认: standard
  --benchmark-threads <num>              默认: 32
  --benchmark-time <sec>                 默认: 180
  --benchmark-warmup-time <sec>          默认: 30
  --benchmark-warmup-rows <rows>         默认: 10000
  --benchmark-tables <num>               默认: 8
  --benchmark-table-size <rows>          默认: 100000
  --benchmark-db <name>                  默认: sbtest
  --benchmark-rand-type <name>           默认: uniform
  --benchmark-keep-data true|false       默认: false
  --report-dir <dir>                     默认: ./reports

输出:
  1. 保留完整 job 日志
  2. 生成文本报告 .txt
  3. 生成结构化报告 .json，便于后续分析

说明:
  1. warmup rows 与正式 table size 已解耦
  2. MySQL 8 会自动附加更宽松的兼容参数
EOF
}

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

show_help_backup_restore() {
  cat <<'EOF'
备份原理:
  1. 连接目标 MySQL 并探测可用性
  2. 枚举用户库，排除系统库
  3. 执行 mysqldump，生成 gzip、sha256 和 meta
  4. 更新 latest.txt，并按 retention 清理旧快照

恢复原理:
  1. 定位快照
  2. 校验 sha256
  3. 按 restore-mode 决定是否先清空用户库
  4. gunzip 后通过 mysql 客户端导入

业务影响:
  1. backup 不要求停业务。
  2. restore 不会主动停库，但会修改目标数据，建议维护窗口执行。
EOF
}


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


show_help() {
  case "${HELP_TOPIC}" in
    overview)
      show_help_overview
      ;;
    install)
      show_help_install
      ;;
    addons)
      show_help_addons
      ;;
    backup)
      show_help_backup
      ;;
    restore)
      show_help_restore
      ;;
    benchmark)
      show_help_benchmark
      ;;
    params)
      show_help_params
      ;;
    backup-restore)
      show_help_backup_restore
      ;;
    logging)
      show_help_logging
      ;;
    architecture)
      show_help_architecture
      ;;
    examples)
      show_help_examples
      ;;
    *)
      die "未知 help 主题: ${HELP_TOPIC}。可用主题: overview, install, addons, backup, restore, benchmark, params, backup-restore, logging, architecture, examples"
      ;;
  esac
}



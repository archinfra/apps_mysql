show_help_overview() {
  local cmd="./$(program_name)"
  local supported_actions
  supported_actions="$(package_profile_supported_actions_text)"

  cat <<EOF
用法:
  ${cmd} <动作> [参数]
  ${cmd} help [主题]

当前产物包:
  $(package_profile_label)

当前包可用动作:
  ${supported_actions}

动作说明:
  install                 整体安装或对齐 MySQL 本体与内置能力
  uninstall               卸载集成包创建的资源，默认保留 PVC
  status                  查看当前资源状态
  addon-install           给已有 MySQL 补充外围监控能力
  addon-uninstall         单独移除外围监控能力
  addon-status            查看 addon 状态与影响边界
  benchmark               执行压测 Job 并输出报告
  help                    查看中文帮助

help 主题:
  overview
  install
  addons
  benchmark
  params
  packages
  logging
  architecture
  examples

关键说明:
  1. apps_mysql 负责 MySQL 安装、监控、压测，以及与 dataprotection 的接入注册。
  2. 备份恢复仍由独立数据保护系统执行，但 install 会自动注册 BackupAddon/BackupSource/BackupPolicy。
  3. 默认日志直接进容器 stdout/stderr，便于 kubectl logs 与平台日志采集共存。
EOF
}


show_help_install() {
  local cmd="./mysql-installer-<arch>.run"
  local resource_hint="  --resource-profile <name>         默认: mid，支持 low|mid|midd|high"

  cat <<EOF
install 仅在 integrated 包中可用，适合:
  1. 首次安装 MySQL
  2. 调整副本数、存储、Service 等配置后重新对齐
  3. 一次性决定是否内嵌监控 sidecar、ServiceMonitor 和日志 sidecar

常用参数:
  -n, --namespace <ns>              默认: aict
  --root-password <password>        默认: passw0rd
  --auth-secret <name>              默认: mysql-auth
  --mysql-replicas <num>            默认: 1
  --storage-class <name>            默认: nfs
  --storage-size <size>             默认: 10Gi
  --service-name <name>             默认: mysql
  --sts-name <name>                 默认: mysql
  --nodeport-enabled true|false     默认: true
  --enable-nodeport / --disable-nodeport
  --enable-monitoring / --disable-monitoring
  --enable-service-monitor / --disable-service-monitor
  --enable-fluentbit / --disable-fluentbit
  --enable-data-protection / --disable-data-protection
  --backup-namespace <ns>            默认: backup-system
  --backup-storage-name <name>       默认: minio-primary
  --backup-secondary-storage-name <name>
  --backup-schedule <cron>           默认: 0 */6 * * *
  --backup-retention-ref <name>      默认: keep-last-3
  --backup-notification-ref <name>
  --backup-database <name>
  --mysql-slow-query-time <seconds> 默认: 2
  --registry <repo-prefix>          例如: harbor.example.com/kube4
  --wait-timeout <duration>         默认: 10m

说明:
  1. install 会对 StatefulSet 与相关资源做声明式对齐，配置变化可能触发滚动更新。
  2. 如果只是给已有 MySQL 补监控，优先使用 addon-install。
  3. 如果集群已安装 dataprotection 且备份存储已就绪，install 会自动注册 MySQL 备份接入与默认策略。

示例:
  ${cmd} install \
    --namespace mysql-demo \
    --root-password 'StrongPassw0rd' \
    --backup-storage-name minio-primary \
    --enable-fluentbit \
    --mysql-slow-query-time 1 \
    -y

资源档位:
${resource_hint}
EOF
}


show_help_addons() {
  local cmd="./mysql-monitoring-<arch>.run"

  cat <<EOF
addon-install / addon-uninstall / addon-status 面向“已有 MySQL 补监控能力”。

支持的 addon:
  monitoring
    外置 mysqld-exporter Deployment + Service
    默认新增独立 Pod，不修改 MySQL StatefulSet

  service-monitor
    创建 ServiceMonitor 声明
    自动依赖 monitoring

addon 参数:
  --addons <list>                   必填，逗号分隔: monitoring,service-monitor
  --monitoring-target <host:port>   监控目标地址；已有外部 MySQL 时建议显式指定
  --mysql-host <host>               可作为 monitoring-target 的简化来源
  --mysql-port <port>               默认: 3306
  --exporter-user <user>            默认: mysqld_exporter
  --exporter-password <password>    默认: exporter@passw0rd

说明:
  1. addon-install 默认不修改 MySQL StatefulSet。
  2. logging 不作为 addon 提供；如需 sidecar，请走 integrated install。
  3. 备份恢复已迁移到独立数据保护系统。

示例:
  ${cmd} addon-install \
    --namespace mysql-demo \
    --addons monitoring,service-monitor \
    --monitoring-target 10.0.0.20:3306 \
    -y
EOF
}


show_help_benchmark() {
  local cmd="./mysql-benchmark-<arch>.run"

  cat <<EOF
benchmark 会创建一次性 Job，对目标 MySQL 执行 sysbench 压测。

常用参数:
  --mysql-host <host>
  --mysql-port <port>                    默认: 3306
  --mysql-user <user>                    默认: root
  --mysql-password <password>            推荐显式传入
  --mysql-auth-secret <name>             使用已有 Secret
  --mysql-password-key <key>             Secret 中密码键名
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
  1. 完整 job 日志 .log
  2. 文本报告 .txt
  3. 结构化报告 .json

说明:
  1. benchmark 只创建 Job，不会改动 StatefulSet。
  2. 当前会自动兼容不支持 --warmup-time 的 sysbench 版本。

示例:
  ${cmd} benchmark \
    --namespace mysql-demo \
    --mysql-host 10.0.0.20 \
    --mysql-user root \
    --mysql-password '<MYSQL_PASSWORD>' \
    --benchmark-profile oltp-read-write \
    --benchmark-threads 64 \
    --benchmark-time 300 \
    --report-dir ./reports \
    -y
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

监控:
  --addons monitoring,service-monitor
  --monitoring-target <host:port>
  --exporter-user <user>
  --exporter-password <password>

安装期开关:
  --enable-monitoring / --disable-monitoring
  --enable-service-monitor / --disable-service-monitor
  --enable-fluentbit / --disable-fluentbit
  --enable-data-protection / --disable-data-protection
  --resource-profile <name>
  --mysql-slow-query-time <seconds>

数据保护:
  --backup-namespace <ns>
  --backup-addon-name <name>
  --backup-source-name <name>
  --backup-policy-name <name>
  --backup-auth-secret <name>
  --backup-storage-name <name>
  --backup-secondary-storage-name <name>
  --backup-retention-ref <name>
  --backup-notification-ref <name>
  --backup-schedule <cron>
  --backup-database <name>

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
  --benchmark-keep-data
  --report-dir <dir>
EOF
}


show_help_packages() {
  cat <<'EOF'
当前会构建三类产物:

  mysql-installer-<arch>.run
    集成包
    支持 install / uninstall / status / addon / benchmark

  mysql-benchmark-<arch>.run
    压测能力包
    只保留 benchmark 所需镜像、manifest 与动作

  mysql-monitoring-<arch>.run
    监控能力包
    支持 monitoring / service-monitor 的 addon 安装与卸载

设计目标:
  1. 保留 integrated 包，继续服务离线整体交付
  2. 抽出 benchmark / monitoring，降低非目标场景的使用成本
  3. 备份恢复改由独立数据保护系统负责，apps_mysql 不再重复承载
EOF
}


show_help_logging() {
  cat <<'EOF'
日志能力现在分两层：

默认行为:
  1. MySQL 日志统一写到 /var/log/mysql 下的安全路径
  2. 未开启 sidecar 时，error.log / slow.log 会被软链接到容器 stderr / stdout
  3. 因此默认就支持 kubectl logs 查看，也方便平台 DaemonSet 统一采集

启用 --enable-fluentbit 后:
  1. error.log 仍会进入 mysql 容器 stderr，kubectl logs -c mysql 仍然可看
  2. slow log 改为写真实文件，由 fluent-bit sidecar 转发到它自己的 stdout
  3. 适合必须消费文件型慢日志的场景

当前推荐:
  1. 已有平台 Fluent Bit/Fluentd/Vector 时，优先直接采容器 stdout/stderr
  2. 只有明确需要 Pod 内 slow log 文件时，再启用 --enable-fluentbit
  3. monitoring addon 不负责日志，日志只在 integrated install 路径里管理
EOF
}


show_help_architecture() {
  cat <<'EOF'
能力分层:
  integrated
    负责 MySQL 本体、StatefulSet、Service、PVC，以及内置 sidecar 对齐
  benchmark
    负责压测能力与报告输出
  monitoring
    负责 exporter / ServiceMonitor 等外围监控能力

边界调整:
  1. apps_mysql 只保留安装、监控、压测
  2. 备份恢复已经迁移到独立数据保护系统
  3. 这样可以避免安装器继续膨胀，也减少其他项目复用时的负担

源码结构:
  scripts/install/modules/*.sh
    职责模块源码入口

  scripts/assemble-install.sh
    组装 install.sh

  build.sh
    根据 --profile 与 --arch 产出不同离线包
EOF
}


show_help_examples() {
  cat <<EOF
常见示例:

首次安装 MySQL：
  ./mysql-installer-<arch>.run install \
    --namespace mysql-demo \
    --root-password 'StrongPassw0rd' \
    -y

首次安装并显式打开文件慢日志 sidecar：
  ./mysql-installer-<arch>.run install \
    --namespace mysql-demo \
    --enable-fluentbit \
    --mysql-slow-query-time 1 \
    -y

给已有 MySQL 补监控：
  ./mysql-monitoring-<arch>.run addon-install \
    --namespace mysql-demo \
    --addons monitoring,service-monitor \
    --monitoring-target 10.0.0.20:3306 \
    -y

独立压测：
  ./mysql-benchmark-<arch>.run benchmark \
    --namespace mysql-demo \
    --mysql-host 10.0.0.20 \
    --mysql-user root \
    --mysql-password '<MYSQL_PASSWORD>' \
    --benchmark-profile oltp-read-write \
    --benchmark-threads 64 \
    --benchmark-time 300 \
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
    benchmark)
      show_help_benchmark
      ;;
    params)
      show_help_params
      ;;
    packages)
      show_help_packages
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
      die "未知 help 主题: ${HELP_TOPIC}。可用主题: overview, install, addons, benchmark, params, packages, logging, architecture, examples"
      ;;
  esac
}

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
  addon-install           给已有 MySQL 补充外围能力
  addon-uninstall         单独移除外围能力
  addon-status            查看 addon 状态与影响边界
  backup                  立即执行一次备份 Job
  restore                 立即执行一次恢复 Job
  verify-backup-restore   执行备份/恢复闭环校验
  benchmark               执行压测 Job 并输出报告
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
  packages
  logging
  architecture
  examples

关键设计:
  1. 这套工具已经拆成“集成包 + 能力包”，不是只有一个大一统 installer。
  2. backup 既支持默认主计划，也支持通过重复 --backup-plan 增加多个中心、多种存储、多条定时策略。
  3. 备份范围可以是全量、指定库，或指定表；restore 会按备份内容回放。
  4. backup 是“立刻执行一次”，addon-install --addons backup 才是“安装定时备份计划”。
EOF
}


show_help_install() {
  local cmd="./mysql-installer-<arch>.run"

  cat <<EOF
install 仅在 integrated 包中可用，适合:
  1. 首次安装 MySQL
  2. 调整副本数、存储、Service 等配置后重新对齐
  3. 一次性开启或关闭监控、日志、备份、压测等能力

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
  --registry <repo-prefix>          例如: harbor.example.com/kube4
  --wait-timeout <duration>         默认: 10m

备份能力:
  --enable-backup / --disable-backup
  --backup-backend nfs|s3           默认主计划后端
  --backup-store-name <name>        默认主计划存储名，默认: primary
  --backup-plan-file <path>         从 YAML/JSON 加载备份计划
  --backup-plan '<spec>'            追加一个额外备份计划，可重复传入
  --enable-default-backup-plan
  --disable-default-backup-plan     仅保留显式定义的 backup plan

说明:
  1. install 会对 StatefulSet 与相关资源做声明式对齐，配置变化可能触发滚动更新。
  2. 如果只是给已有 MySQL 补监控或备份，优先使用 addon-install。
  3. 多中心备份推荐用一个主计划 + 多个 --backup-plan，或直接关闭默认计划后全部显式定义。

示例:
  ${cmd} install \\
    --namespace mysql-demo \\
    --root-password 'StrongPassw0rd' \\
    --backup-plan-file ./examples/backup-plans.example.yaml \\
    -y
EOF
}


show_help_addons() {
  local cmd="./mysql-backup-restore-<arch>.run"

  cat <<EOF
addon-install / addon-uninstall / addon-status 面向“已有 MySQL 补能力”。

支持的 addon:
  monitoring
    外置 mysqld-exporter Deployment + Service
    默认新增独立 Pod，不修改 MySQL StatefulSet

  service-monitor
    创建 ServiceMonitor 声明
    自动依赖 monitoring

  backup
    安装备份脚本、Secret 与一个或多个 CronJob
    支持多计划、多中心、按库/表范围导出

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

示例:
  ${cmd} addon-install \\
    --namespace mysql-demo \\
    --addons backup \\
    --mysql-host 10.0.0.20 \\
    --mysql-user root \\
    --mysql-password '<MYSQL_PASSWORD>' \\
    --disable-default-backup-plan \\
    --backup-plan 'name=nfs-a;backend=nfs;nfsServer=192.168.10.2;nfsPath=/data/nfs-a;schedule=0 2 * * *;retention=7' \\
    --backup-plan 'name=minio-b;backend=s3;s3Endpoint=https://minio.dc2.example.com;s3Bucket=mysql-backup;s3Prefix=prod;s3AccessKey=minio;s3SecretKey=secret;schedule=30 2 * * *;retention=7' \\
    -y
EOF
}


show_help_backup() {
  local cmd="./mysql-backup-restore-<arch>.run"

  cat <<EOF
请区分两个动作:

场景 A: 安装备份组件
  install --enable-backup
  addon-install --addons backup

场景 B: 立即执行一次备份
  backup

区别:
  1. 场景 A 会安装 ConfigMap / Secret / CronJob 等资源
  2. 场景 B 只会创建一次性 Job，不会安装 CronJob

目标连接参数:
  --mysql-host <host>               默认推导为 <sts>-0.<svc>.<ns>.svc.cluster.local
  --mysql-port <port>               默认: 3306
  --mysql-user <user>               默认: root
  --mysql-password <password>       推荐立即动作显式传入
  --mysql-auth-secret <name>        使用已有 Secret
  --mysql-password-key <key>        Secret 中密码键名
  --mysql-target-name <name>        备份目录中的逻辑实例名

计划参数:
  --backup-backend nfs|s3           默认主计划后端
  --backup-store-name <name>        默认主计划存储名
  --backup-root-dir <dir>           默认: backups
  --backup-schedule <cron>          默认主计划定时
  --backup-retention <num>          默认: 5
  --backup-databases <db1,db2>      只导出指定库
  --backup-tables <db.tbl,...>      只导出指定表
  --backup-plan-file <path>         从 YAML/JSON 批量加载计划
  --backup-plan '<spec>'            增加额外计划，可重复传入
  --enable-default-backup-plan      显式保留默认主计划
  --disable-default-backup-plan     不再使用顶层主计划

NFS 计划字段:
  name=<plan-name>;backend=nfs;nfsServer=<addr>;nfsPath=<path>;schedule=<cron>;retention=<num>;storeName=<name>

S3 计划字段:
  name=<plan-name>;backend=s3;s3Endpoint=<url>;s3Bucket=<bucket>;s3Prefix=<prefix>;s3AccessKey=<key>;s3SecretKey=<key>;schedule=<cron>;retention=<num>;storeName=<name>

范围字段:
  databases=db1,db2
  tables=db1.t1,db2.t2

配置文件:
  推荐把长期计划写入 YAML/JSON，再通过 --backup-plan-file 引入。
  文件支持:
    defaultPlanEnabled: true|false
    restoreSource: auto|<plan-name>
    defaults: {...}
    plans: [...]

认证要求:
  1. backup / restore / verify-backup-restore 不再回退到 --root-password。
  2. 请显式提供 --mysql-password，或提供可用的 --mysql-auth-secret。

示例:
  ${cmd} backup \\
    --namespace mysql-demo \\
    --mysql-host 10.0.0.20 \\
    --mysql-user root \\
    --mysql-password '<MYSQL_PASSWORD>' \\
    --backup-plan-file ./examples/backup-plans.example.yaml \\
    -y
EOF
}


show_help_restore() {
  local cmd="./mysql-backup-restore-<arch>.run"

  cat <<EOF
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
  --restore-source <plan-name|auto> 默认: auto，按 backup plan 顺序尝试
  --restore-mode merge|wipe-all-user-databases 默认: merge
  --backup-plan-file <path>         从 YAML/JSON 加载备份来源定义

说明:
  1. latest 会优先读取 latest.txt。
  2. 如果 latest.txt 指向的快照不存在，会自动回退到目录里最新的 .sql.gz。
  3. 当 restore-source 是“部分库/表备份”时，建议使用 merge。
  4. wipe-all-user-databases 只允许全量备份来源，避免误删其他业务库。

示例:
  ${cmd} restore \\
    --namespace mysql-demo \\
    --mysql-host 10.0.0.20 \\
    --mysql-user root \\
    --mysql-password '<MYSQL_PASSWORD>' \\
    --restore-source dc2-s3 \\
    --restore-snapshot latest \\
    --restore-mode merge \\
    --backup-plan-file ./examples/backup-plans.example.yaml \\
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
  1. benchmark 能单独打包成 mysql-benchmark-<arch>.run。
  2. 当前会自动兼容不支持 --warmup-time 的 sysbench 版本。

示例:
  ${cmd} benchmark \\
    --namespace mysql-demo \\
    --mysql-host 10.0.0.20 \\
    --mysql-user root \\
    --mysql-password '<MYSQL_PASSWORD>' \\
    --benchmark-profile oltp-read-write \\
    --benchmark-threads 64 \\
    --benchmark-time 300 \\
    --benchmark-table-size 300000 \\
    --report-dir ./reports \\
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
  --mysql-target-name <name>

备份计划:
  --backup-backend nfs|s3
  --backup-store-name <name>
  --backup-root-dir <dir>
  --backup-nfs-server <addr>
  --backup-nfs-path <path>
  --backup-schedule <cron>
  --backup-retention <num>
  --backup-databases <db1,db2>
  --backup-tables <db.tbl,...>
  --backup-plan-file <path>
  --backup-plan '<spec>'
  --enable-default-backup-plan
  --disable-default-backup-plan
  --restore-source <plan-name|auto>
  --restore-snapshot <name|latest>
  --restore-mode merge|wipe-all-user-databases

S3:
  --s3-endpoint <url>
  --s3-bucket <name>
  --s3-prefix <dir>
  --s3-access-key <key>
  --s3-secret-key <key>
  --s3-insecure

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


show_help_backup_restore() {
  cat <<'EOF'
备份原理:
  1. 连接目标 MySQL 并探测可用性
  2. 按 scope 决定导出全库、指定库，或指定表
  3. 生成 gzip、sha256、meta 与 latest.txt
  4. 按 retention 清理旧快照

多中心设计:
  1. 一个 backup plan 对应一个存储目的地和一条调度策略
  2. 一个定时 backup plan 就会生成一个独立 CronJob
  3. 可以有多个 NFS、多个 S3，也可以 NFS + S3 混搭
  4. 默认计划继续兼容旧参数，额外中心通过重复 --backup-plan 或 --backup-plan-file 叠加

路径规则:
  NFS:
    <backup-nfs-path>/<backup-root-dir>/mysql/<namespace>/<mysql-target-name>/stores/<store-name>/
  S3:
    <bucket>/<s3-prefix>/<backup-root-dir>/mysql/<namespace>/<mysql-target-name>/stores/<store-name>/

恢复原理:
  1. 按 restore-source 或 auto 顺序选择备份来源
  2. 定位快照并校验 sha256
  3. 根据 restore-mode 决定是否先清空用户库
  4. gunzip 后通过 mysql 客户端导入

边界说明:
  1. backup 不要求停业务。
  2. restore 会修改目标数据，建议维护窗口执行。
  3. 对部分库/表备份，推荐 restore-mode=merge。
  4. verify-backup-restore 只会拿“覆盖 offline_validation 校验表”的备份来源做恢复校验。
EOF
}


show_help_packages() {
  cat <<'EOF'
当前会构建四类产物:

  mysql-installer-<arch>.run
    集成包
    支持 install / uninstall / status / addon / backup / restore / benchmark

  mysql-backup-restore-<arch>.run
    备份恢复能力包
    支持 status / addon-install backup / addon-uninstall backup / backup / restore / verify-backup-restore

  mysql-benchmark-<arch>.run
    压测能力包
    只保留 benchmark 所需镜像、manifest 与动作

  mysql-monitoring-<arch>.run
    监控能力包
    支持 monitoring / service-monitor 的 addon 安装与卸载

设计目标:
  1. 保留 integrated 包，继续服务离线整体交付
  2. 抽出 backup-restore / benchmark / monitoring，降低非目标场景的使用成本
  3. 让“只想压测”或“只想做备份恢复”的团队不必接受整个大包
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
EOF
}


show_help_architecture() {
  cat <<'EOF'
能力分层:
  integrated
    负责 MySQL 本体、StatefulSet、Service、PVC，以及整体安装体验

  backup-restore
    负责备份计划、恢复、闭环校验、多中心副本

  benchmark
    负责压测能力与报告输出

  monitoring
    负责 exporter / ServiceMonitor 等外围监控能力

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

首次安装并保留主备份计划:
  ./mysql-installer-<arch>.run install \\
    --namespace mysql-demo \\
    --root-password 'StrongPassw0rd' \\
    --backup-plan-file ./examples/backup-plans.example.yaml \\
    -y

只给已有 MySQL 补多中心定时备份:
  ./mysql-backup-restore-<arch>.run addon-install \\
    --namespace mysql-demo \\
    --addons backup \\
    --mysql-host 10.0.0.20 \\
    --mysql-user root \\
    --mysql-password '<MYSQL_PASSWORD>' \\
    --backup-plan-file ./examples/backup-plans.example.yaml \\
    -y

立刻导出指定表到多中心:
  ./mysql-backup-restore-<arch>.run backup \\
    --namespace mysql-demo \\
    --mysql-host 10.0.0.20 \\
    --mysql-user root \\
    --mysql-password '<MYSQL_PASSWORD>' \\
    --backup-plan-file ./examples/backup-plans.example.yaml \\
    -y

从指定中心恢复:
  ./mysql-backup-restore-<arch>.run restore \\
    --namespace mysql-demo \\
    --mysql-host 10.0.0.20 \\
    --mysql-user root \\
    --mysql-password '<MYSQL_PASSWORD>' \\
    --restore-source minio-c \\
    --restore-snapshot latest \\
    --restore-mode merge \\
    --backup-plan-file ./examples/backup-plans.example.yaml \\
    -y

独立压测:
  ./mysql-benchmark-<arch>.run benchmark \\
    --namespace mysql-demo \\
    --mysql-host 10.0.0.20 \\
    --mysql-user root \\
    --mysql-password '<MYSQL_PASSWORD>' \\
    --benchmark-profile oltp-read-write \\
    --benchmark-threads 64 \\
    --benchmark-time 300 \\
    --report-dir ./reports \\
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
      die "未知 help 主题: ${HELP_TOPIC}。可用主题: overview, install, addons, backup, restore, benchmark, params, backup-restore, packages, logging, architecture, examples"
      ;;
  esac
}

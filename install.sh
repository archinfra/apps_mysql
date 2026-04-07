#!/usr/bin/env bash

# Generated source layout:
# - edit scripts/install/modules/*.sh
# - regenerate install.sh via scripts/assemble-install.sh

set -Eeuo pipefail

APP_NAME="mysql"
APP_VERSION="1.5.3"
PACKAGE_PROFILE="${PACKAGE_PROFILE:-integrated}"
WORKDIR="/tmp/${APP_NAME}-installer"
IMAGE_DIR="${WORKDIR}/images"
MANIFEST_DIR="${WORKDIR}/manifests"

IMAGE_JSON="${IMAGE_DIR}/image.json"
MYSQL_MANIFEST="${MANIFEST_DIR}/innodb-mysql.yaml"
BACKUP_MANIFEST="${MANIFEST_DIR}/mysql-backup.yaml"
BACKUP_SUPPORT_MANIFEST="${MANIFEST_DIR}/mysql-backup-support.yaml"
BACKUP_JOB_MANIFEST="${MANIFEST_DIR}/mysql-backup-job.yaml"
RESTORE_MANIFEST="${MANIFEST_DIR}/mysql-restore-job.yaml"
BENCHMARK_MANIFEST="${MANIFEST_DIR}/mysql-benchmark-job.yaml"
MONITORING_ADDON_MANIFEST="${MANIFEST_DIR}/mysql-addon-monitoring.yaml"

REGISTRY_ADDR="${REGISTRY_ADDR:-sealos.hub:5000}"
REGISTRY_USER="${REGISTRY_USER:-admin}"
REGISTRY_PASS="${REGISTRY_PASS:-passw0rd}"
REGISTRY_REPO="${REGISTRY_REPO:-${REGISTRY_ADDR}/kube4}"
MYSQL_IMAGE="${MYSQL_IMAGE:-${REGISTRY_REPO}/mysql:8.0.45}"
MYSQL_EXPORTER_IMAGE="${MYSQL_EXPORTER_IMAGE:-${REGISTRY_REPO}/mysqld-exporter:v0.15.1}"
FLUENTBIT_IMAGE="${FLUENTBIT_IMAGE:-${REGISTRY_REPO}/fluent-bit:3.0.7}"
S3_CLIENT_IMAGE="${S3_CLIENT_IMAGE:-${REGISTRY_REPO}/minio-mc:latest}"
BUSYBOX_IMAGE="${BUSYBOX_IMAGE:-${REGISTRY_REPO}/busybox:v1}"
SYSBENCH_IMAGE="${SYSBENCH_IMAGE:-${REGISTRY_REPO}/sysbench:1.0.20-oe2403sp1}"

ACTION="install"
HELP_TOPIC="overview"
ADDONS=""
NAMESPACE="aict"
MYSQL_REPLICAS="1"
MYSQL_ROOT_PASSWORD="passw0rd"
STORAGE_CLASS="nfs"
STORAGE_SIZE="10Gi"
SERVICE_NAME="mysql"
STS_NAME="mysql"
AUTH_SECRET="mysql-auth"
MYSQL_HOST=""
MYSQL_PORT="3306"
MYSQL_USER="root"
MYSQL_PASSWORD=""
MYSQL_AUTH_SECRET=""
MYSQL_PASSWORD_KEY=""
MYSQL_TARGET_NAME=""
MYSQL_RESTORE_MODE="merge"
MYSQL_RUNTIME_SECRET="mysql-runtime-auth"
MYSQL_ROOT_PASSWORD_EXPLICIT="false"
MYSQL_PASSWORD_EXPLICIT="false"
MYSQL_AUTH_SECRET_EXPLICIT="false"
MYSQL_PASSWORD_KEY_EXPLICIT="false"
MYSQL_HOST_EXPLICIT="false"
MYSQL_TARGET_NAME_EXPLICIT="false"
PROBE_CONFIGMAP="mysql-probes"
INIT_CONFIGMAP="mysql-init-users"
MYSQL_CONFIGMAP="mysql-config"
BACKUP_SCRIPT_CONFIGMAP="mysql-backup-scripts"
BACKUP_CRONJOB_NAME="mysql-backup"
BACKUP_STORAGE_SECRET="mysql-backup-storage"
BACKUP_BACKEND="nfs"
BACKUP_PLAN_NAME="primary"
BACKUP_STORE_NAME="primary"
BACKUP_DATABASES=""
BACKUP_TABLES=""
BACKUP_PLAN_FILE=""
BACKUP_RESTORE_SOURCE="auto"
BACKUP_RESTORE_SOURCE_EXPLICIT="false"
BACKUP_DEFAULT_PLAN_ENABLED="true"
BACKUP_DEFAULT_PLAN_ENABLED_EXPLICIT="false"
NODEPORT_SERVICE_NAME="mysql-nodeport"
NODE_PORT="30306"
NODEPORT_ENABLED="true"
MONITORING_ENABLED="true"
SERVICE_MONITOR_ENABLED="true"
FLUENTBIT_ENABLED="true"
BACKUP_ENABLED="true"
BENCHMARK_ENABLED="true"
METRICS_SERVICE_NAME="mysql-metrics"
METRICS_PORT="9104"
SERVICE_MONITOR_NAME="mysql-monitor"
SERVICE_MONITOR_INTERVAL="30s"
SERVICE_MONITOR_SCRAPE_TIMEOUT="10s"
ADDON_EXPORTER_DEPLOYMENT_NAME="mysql-exporter"
ADDON_EXPORTER_SERVICE_NAME="mysql-exporter"
ADDON_EXPORTER_SECRET="mysql-exporter-auth"
ADDON_EXPORTER_USERNAME="mysqld_exporter"
ADDON_EXPORTER_PASSWORD="exporter@passw0rd"
ADDON_MONITORING_TARGET=""
ADDON_MONITORING_TARGET_EXPLICIT="false"
ADDON_SERVICE_MONITOR_NAME="mysql-exporter-monitor"
FLUENTBIT_CONFIGMAP="mysql-fluent-bit"
MYSQL_SLOW_QUERY_TIME="2"
BACKUP_NFS_SERVER=""
BACKUP_NFS_PATH="/data/nfs-share"
BACKUP_ROOT_DIR="backups"
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_RETENTION="5"
S3_ENDPOINT=""
S3_BUCKET=""
S3_PREFIX=""
S3_ACCESS_KEY=""
S3_SECRET_KEY=""
S3_INSECURE="false"
RESTORE_SNAPSHOT="latest"
WAIT_TIMEOUT="10m"
WAIT_TIMEOUT_EXPLICIT="false"
AUTO_YES="false"
DELETE_PVC="false"
SKIP_IMAGE_PREPARE="false"
REPORT_DIR="./reports"
BENCHMARK_CONCURRENCY="32"
BENCHMARK_ITERATIONS="3"
BENCHMARK_QUERIES="2000"
BENCHMARK_WARMUP_ROWS="10000"
BENCHMARK_THREADS="32"
BENCHMARK_TIME="180"
BENCHMARK_WARMUP_TIME="30"
BENCHMARK_TABLES="8"
BENCHMARK_TABLE_SIZE="100000"
BENCHMARK_DB="sbtest"
BENCHMARK_RAND_TYPE="uniform"
BENCHMARK_KEEP_DATA="false"
BENCHMARK_PROFILE="standard"
BENCHMARK_HOST=""
BENCHMARK_PORT="3306"
BENCHMARK_USER="root"

declare -a BACKUP_PLAN_EXTRA_SPECS=()
declare -a BACKUP_PLAN_CATALOG=()
declare -a BACKUP_PLAN_NAMES=()
BACKUP_PLAN_DEFAULTS_CAPTURED="false"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log() {
  echo -e "${CYAN}[INFO]${NC} $*"
}


success() {
  echo -e "${GREEN}[OK]${NC} $*"
}


warn() {
  echo -e "${YELLOW}[WARN]${NC} $*" >&2
}


die() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
  exit 1
}


section() {
  echo
  echo -e "${BLUE}${BOLD}============================================================${NC}"
  echo -e "${BLUE}${BOLD}$*${NC}"
  echo -e "${BLUE}${BOLD}============================================================${NC}"
}


banner() {
  echo
  echo -e "${GREEN}${BOLD}MySQL 离线安装器${NC}"
  echo -e "${CYAN}版本: ${APP_VERSION}${NC}"
  echo -e "${CYAN}产物包: $(package_profile_label)${NC}"
}


backup_backend_is_nfs() {
  [[ "${BACKUP_BACKEND}" == "nfs" ]]
}


backup_backend_is_s3() {
  [[ "${BACKUP_BACKEND}" == "s3" ]]
}


program_name() {
  basename "$0"
}


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

package_profile_label() {
  case "${PACKAGE_PROFILE}" in
    integrated)
      echo "integrated"
      ;;
    backup-restore)
      echo "backup-restore"
      ;;
    benchmark)
      echo "benchmark"
      ;;
    monitoring)
      echo "monitoring"
      ;;
    *)
      echo "${PACKAGE_PROFILE}"
      ;;
  esac
}


package_profile_supports_action() {
  local action_name="$1"

  case "${PACKAGE_PROFILE}" in
    integrated)
      return 0
      ;;
    backup-restore)
      case "${action_name}" in
        help|status|addon-install|addon-uninstall|addon-status|backup|restore|verify-backup-restore)
          return 0
          ;;
      esac
      ;;
    benchmark)
      case "${action_name}" in
        help|benchmark)
          return 0
          ;;
      esac
      ;;
    monitoring)
      case "${action_name}" in
        help|status|addon-install|addon-uninstall|addon-status)
          return 0
          ;;
      esac
      ;;
    *)
      die "未知 package profile: ${PACKAGE_PROFILE}"
      ;;
  esac

  return 1
}


package_profile_supports_addon() {
  local addon_name="$1"

  case "${PACKAGE_PROFILE}" in
    integrated)
      case "${addon_name}" in
        monitoring|service-monitor|backup)
          return 0
          ;;
      esac
      ;;
    backup-restore)
      [[ "${addon_name}" == "backup" ]]
      return
      ;;
    monitoring)
      case "${addon_name}" in
        monitoring|service-monitor)
          return 0
          ;;
      esac
      ;;
  esac

  return 1
}


package_profile_supported_actions_text() {
  case "${PACKAGE_PROFILE}" in
    integrated)
      echo "install uninstall status addon-install addon-uninstall addon-status backup restore verify-backup-restore benchmark help"
      ;;
    backup-restore)
      echo "status addon-install addon-uninstall addon-status backup restore verify-backup-restore help"
      ;;
    benchmark)
      echo "benchmark help"
      ;;
    monitoring)
      echo "status addon-install addon-uninstall addon-status help"
      ;;
  esac
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    ACTION="help"
    HELP_TOPIC="overview"
    return 0
  fi

  case "$1" in
    help)
      ACTION="help"
      shift
      if [[ $# -gt 0 ]]; then
        HELP_TOPIC="$1"
        shift
      fi
      [[ $# -eq 0 ]] || die "help 仅支持一个主题参数"
      return 0
      ;;
    -h|--help)
      ACTION="help"
      HELP_TOPIC="overview"
      shift
      [[ $# -eq 0 ]] || die "--help 不接受其他参数，请使用 help <主题>"
      return 0
      ;;
  esac

  while [[ $# -gt 0 ]]; do
    case "$1" in
      install|uninstall|status|addon-install|addon-uninstall|addon-status|backup|restore|verify-backup-restore|benchmark)
        ACTION="$1"
        shift
        ;;
      -n|--namespace)
        NAMESPACE="$2"
        shift 2
        ;;
      --mysql-replicas)
        MYSQL_REPLICAS="$2"
        shift 2
        ;;
      --storage-class)
        STORAGE_CLASS="$2"
        shift 2
        ;;
      --storage-size)
        STORAGE_SIZE="$2"
        shift 2
        ;;
      --root-password)
        MYSQL_ROOT_PASSWORD="$2"
        MYSQL_ROOT_PASSWORD_EXPLICIT="true"
        shift 2
        ;;
      --auth-secret)
        AUTH_SECRET="$2"
        shift 2
        ;;
      --service-name)
        SERVICE_NAME="$2"
        shift 2
        ;;
      --addons)
        ADDONS="$2"
        shift 2
        ;;
      --sts-name)
        STS_NAME="$2"
        shift 2
        ;;
      --nodeport-service-name)
        NODEPORT_SERVICE_NAME="$2"
        shift 2
        ;;
      --node-port)
        NODE_PORT="$2"
        shift 2
        ;;
      --nodeport-enabled)
        NODEPORT_ENABLED="$2"
        shift 2
        ;;
      --enable-nodeport)
        NODEPORT_ENABLED="true"
        shift
        ;;
      --disable-nodeport)
        NODEPORT_ENABLED="false"
        shift
        ;;
      --registry)
        REGISTRY_REPO="$2"
        REGISTRY_ADDR="${2%%/*}"
        MYSQL_IMAGE="${REGISTRY_REPO}/mysql:8.0.45"
        MYSQL_EXPORTER_IMAGE="${REGISTRY_REPO}/mysqld-exporter:v0.15.1"
        FLUENTBIT_IMAGE="${REGISTRY_REPO}/fluent-bit:3.0.7"
        S3_CLIENT_IMAGE="${REGISTRY_REPO}/minio-mc:latest"
        BUSYBOX_IMAGE="${REGISTRY_REPO}/busybox:v1"
        SYSBENCH_IMAGE="${REGISTRY_REPO}/sysbench:1.0.20-oe2403sp1"
        shift 2
        ;;
      --mysql-host)
        MYSQL_HOST="$2"
        MYSQL_HOST_EXPLICIT="true"
        shift 2
        ;;
      --mysql-port)
        MYSQL_PORT="$2"
        shift 2
        ;;
      --mysql-user)
        MYSQL_USER="$2"
        shift 2
        ;;
      --mysql-password)
        MYSQL_PASSWORD="$2"
        MYSQL_PASSWORD_EXPLICIT="true"
        shift 2
        ;;
      --mysql-auth-secret)
        MYSQL_AUTH_SECRET="$2"
        MYSQL_AUTH_SECRET_EXPLICIT="true"
        shift 2
        ;;
      --mysql-password-key)
        MYSQL_PASSWORD_KEY="$2"
        MYSQL_PASSWORD_KEY_EXPLICIT="true"
        shift 2
        ;;
      --mysql-target-name)
        MYSQL_TARGET_NAME="$2"
        MYSQL_TARGET_NAME_EXPLICIT="true"
        shift 2
        ;;
      --enable-monitoring)
        MONITORING_ENABLED="true"
        shift
        ;;
      --disable-monitoring)
        MONITORING_ENABLED="false"
        shift
        ;;
      --enable-service-monitor)
        SERVICE_MONITOR_ENABLED="true"
        shift
        ;;
      --disable-service-monitor)
        SERVICE_MONITOR_ENABLED="false"
        shift
        ;;
      --enable-fluentbit)
        FLUENTBIT_ENABLED="true"
        shift
        ;;
      --disable-fluentbit)
        FLUENTBIT_ENABLED="false"
        shift
        ;;
      --enable-backup)
        BACKUP_ENABLED="true"
        shift
        ;;
      --disable-backup)
        BACKUP_ENABLED="false"
        shift
        ;;
      --enable-benchmark)
        BENCHMARK_ENABLED="true"
        shift
        ;;
      --disable-benchmark)
        BENCHMARK_ENABLED="false"
        shift
        ;;
      --mysql-slow-query-time)
        MYSQL_SLOW_QUERY_TIME="$2"
        shift 2
        ;;
      --backup-backend)
        BACKUP_BACKEND="$2"
        shift 2
        ;;
      --backup-store-name)
        BACKUP_STORE_NAME="$2"
        shift 2
        ;;
      --backup-nfs-server)
        BACKUP_NFS_SERVER="$2"
        shift 2
        ;;
      --backup-nfs-path)
        BACKUP_NFS_PATH="$2"
        shift 2
        ;;
      --backup-root-dir)
        BACKUP_ROOT_DIR="$2"
        shift 2
        ;;
      --backup-schedule)
        BACKUP_SCHEDULE="$2"
        shift 2
        ;;
      --backup-retention)
        BACKUP_RETENTION="$2"
        shift 2
        ;;
      --backup-databases)
        BACKUP_DATABASES="$2"
        shift 2
        ;;
      --backup-tables)
        BACKUP_TABLES="$2"
        shift 2
        ;;
      --backup-plan)
        BACKUP_PLAN_EXTRA_SPECS+=("$2")
        shift 2
        ;;
      --backup-plan-file)
        BACKUP_PLAN_FILE="$2"
        shift 2
        ;;
      --enable-default-backup-plan)
        BACKUP_DEFAULT_PLAN_ENABLED="true"
        BACKUP_DEFAULT_PLAN_ENABLED_EXPLICIT="true"
        shift
        ;;
      --disable-default-backup-plan)
        BACKUP_DEFAULT_PLAN_ENABLED="false"
        BACKUP_DEFAULT_PLAN_ENABLED_EXPLICIT="true"
        shift
        ;;
      --s3-endpoint)
        S3_ENDPOINT="$2"
        shift 2
        ;;
      --s3-bucket)
        S3_BUCKET="$2"
        shift 2
        ;;
      --s3-prefix)
        S3_PREFIX="$2"
        shift 2
        ;;
      --s3-access-key)
        S3_ACCESS_KEY="$2"
        shift 2
        ;;
      --s3-secret-key)
        S3_SECRET_KEY="$2"
        shift 2
        ;;
      --s3-insecure)
        S3_INSECURE="true"
        shift
        ;;
      --exporter-user)
        ADDON_EXPORTER_USERNAME="$2"
        shift 2
        ;;
      --exporter-password)
        ADDON_EXPORTER_PASSWORD="$2"
        shift 2
        ;;
      --monitoring-target)
        ADDON_MONITORING_TARGET="$2"
        ADDON_MONITORING_TARGET_EXPLICIT="true"
        shift 2
        ;;
      --restore-snapshot)
        RESTORE_SNAPSHOT="$2"
        shift 2
        ;;
      --restore-mode)
        MYSQL_RESTORE_MODE="$2"
        shift 2
        ;;
      --restore-source)
        BACKUP_RESTORE_SOURCE="$2"
        BACKUP_RESTORE_SOURCE_EXPLICIT="true"
        shift 2
        ;;
      --wait-timeout)
        WAIT_TIMEOUT="$2"
        WAIT_TIMEOUT_EXPLICIT="true"
        shift 2
        ;;
      --skip-image-prepare)
        SKIP_IMAGE_PREPARE="true"
        shift
        ;;
      --delete-pvc)
        DELETE_PVC="true"
        shift
        ;;
      --report-dir)
        REPORT_DIR="$2"
        shift 2
        ;;
      --benchmark-concurrency|--benchmark-threads)
        BENCHMARK_CONCURRENCY="$2"
        BENCHMARK_THREADS="$2"
        shift 2
        ;;
      --benchmark-iterations)
        BENCHMARK_ITERATIONS="$2"
        shift 2
        ;;
      --benchmark-queries)
        BENCHMARK_QUERIES="$2"
        shift 2
        ;;
      --benchmark-warmup-rows)
        BENCHMARK_WARMUP_ROWS="$2"
        shift 2
        ;;
      --benchmark-warmup-time)
        BENCHMARK_WARMUP_TIME="$2"
        shift 2
        ;;
      --benchmark-time)
        BENCHMARK_TIME="$2"
        shift 2
        ;;
      --benchmark-tables)
        BENCHMARK_TABLES="$2"
        shift 2
        ;;
      --benchmark-table-size)
        BENCHMARK_TABLE_SIZE="$2"
        shift 2
        ;;
      --benchmark-db)
        BENCHMARK_DB="$2"
        shift 2
        ;;
      --benchmark-rand-type)
        BENCHMARK_RAND_TYPE="$2"
        shift 2
        ;;
      --benchmark-keep-data)
        BENCHMARK_KEEP_DATA="true"
        shift
        ;;
      --benchmark-profile)
        BENCHMARK_PROFILE="$2"
        shift 2
        ;;
      --benchmark-host)
        BENCHMARK_HOST="$2"
        MYSQL_HOST="$2"
        MYSQL_HOST_EXPLICIT="true"
        shift 2
        ;;
      --benchmark-port)
        BENCHMARK_PORT="$2"
        MYSQL_PORT="$2"
        shift 2
        ;;
      --benchmark-user)
        BENCHMARK_USER="$2"
        MYSQL_USER="$2"
        shift 2
        ;;
      -y|--yes)
        AUTO_YES="true"
        shift
        ;;
      *)
        die "未知参数: $1"
        ;;
    esac
  done
}

normalize_addons() {
  local raw="${ADDONS:-}"
  local normalized=()
  local item trimmed

  [[ -n "${raw}" ]] || die "动作 ${ACTION} 需要提供 --addons，示例: --addons monitoring,backup"

  if [[ "${raw}" == "all" ]]; then
    raw="monitoring,service-monitor,backup"
  fi

  IFS=',' read -r -a items <<<"${raw}"
  for item in "${items[@]}"; do
    trimmed="$(echo "${item}" | awk '{$1=$1; print}')"
    [[ -n "${trimmed}" ]] || continue

    case "${trimmed}" in
      monitoring|service-monitor|backup)
        local exists="false"
        local current
        for current in "${normalized[@]}"; do
          if [[ "${current}" == "${trimmed}" ]]; then
            exists="true"
            break
          fi
        done
        [[ "${exists}" == "true" ]] || normalized+=("${trimmed}")
        ;;
      *)
        die "不支持的 addon: ${trimmed}，当前仅支持 monitoring, service-monitor, backup"
        ;;
    esac
  done

  (( ${#normalized[@]} > 0 )) || die "--addons 未提供有效内容"
  ADDONS="$(IFS=,; echo "${normalized[*]}")"
}


addon_selected() {
  local addon_name="$1"
  [[ ",${ADDONS}," == *",${addon_name},"* ]]
}


needs_backup_storage() {
  if [[ "${ACTION}" == "addon-install" ]]; then
    addon_selected backup && return 0
    return 1
  fi

  case "${ACTION}" in
    install)
      [[ "${BACKUP_ENABLED}" == "true" ]]
      ;;
    backup|restore|verify-backup-restore)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}


backup_schedule_required() {
  [[ "${ACTION}" == "install" && "${BACKUP_ENABLED}" == "true" ]] && return 0
  [[ "${ACTION}" == "addon-install" ]] && addon_selected backup && return 0
  return 1
}


action_needs_image_prepare() {
  case "${ACTION}" in
    install|addon-install|backup|restore|verify-backup-restore|benchmark)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}


action_needs_mysql_auth() {
  case "${ACTION}" in
    backup|restore|verify-backup-restore|benchmark)
      return 0
      ;;
    addon-install)
      addon_selected backup && return 0
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}


sanitize_target_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]/-/g; s/\.\+/-/g; s/--\+/-/g; s/^-//; s/-$//'
}


resolve_mysql_target_defaults() {
  local default_host="${STS_NAME}-0.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local"

  if [[ -z "${MYSQL_HOST}" ]]; then
    MYSQL_HOST="${default_host}"
  fi

  if [[ -z "${MYSQL_AUTH_SECRET}" ]]; then
    if [[ "${MYSQL_PASSWORD_EXPLICIT}" == "true" ]]; then
      MYSQL_AUTH_SECRET="${MYSQL_RUNTIME_SECRET}"
    else
      MYSQL_AUTH_SECRET="${AUTH_SECRET}"
    fi
  fi

  if [[ -z "${MYSQL_PASSWORD_KEY}" ]]; then
    if [[ "${MYSQL_AUTH_SECRET}" == "${AUTH_SECRET}" ]]; then
      MYSQL_PASSWORD_KEY="mysql-root-password"
    else
      MYSQL_PASSWORD_KEY="password"
    fi
  fi

  if [[ -z "${MYSQL_TARGET_NAME}" ]]; then
    if [[ "${MYSQL_HOST_EXPLICIT}" == "true" ]]; then
      MYSQL_TARGET_NAME="$(sanitize_target_name "${MYSQL_HOST}")"
    else
      MYSQL_TARGET_NAME="${STS_NAME}"
    fi
  fi

  if [[ -z "${ADDON_MONITORING_TARGET}" ]]; then
    ADDON_MONITORING_TARGET="${MYSQL_HOST}:${MYSQL_PORT}"
  fi

  if [[ -z "${BENCHMARK_HOST}" ]]; then
    BENCHMARK_HOST="${MYSQL_HOST}"
  fi
  if [[ -z "${BENCHMARK_PORT}" ]]; then
    BENCHMARK_PORT="${MYSQL_PORT}"
  fi
  if [[ -z "${BENCHMARK_USER}" ]]; then
    BENCHMARK_USER="${MYSQL_USER}"
  fi

  if [[ "${BENCHMARK_TIME}" == "180" && "${BENCHMARK_ITERATIONS}" != "3" ]]; then
    BENCHMARK_TIME="$((BENCHMARK_ITERATIONS * 60))"
  fi
}

cluster_supports_service_monitor() {
  kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1
}


resolve_feature_dependencies() {
  resolve_mysql_target_defaults

  if [[ "${MONITORING_ENABLED}" != "true" && "${SERVICE_MONITOR_ENABLED}" == "true" ]]; then
    warn "monitoring 已关闭，因此自动关闭 ServiceMonitor"
    SERVICE_MONITOR_ENABLED="false"
  fi

  if [[ "${ACTION}" == "addon-install" || "${ACTION}" == "addon-uninstall" ]]; then
    normalize_addons
    SERVICE_MONITOR_ENABLED="false"

    if addon_selected service-monitor && ! addon_selected monitoring && [[ "${ACTION}" == "addon-install" ]]; then
      warn "service-monitor 依赖 monitoring，已自动补齐 monitoring"
      ADDONS="monitoring,${ADDONS}"
      normalize_addons
    fi

    if addon_selected monitoring && ! addon_selected service-monitor && [[ "${ACTION}" == "addon-uninstall" ]]; then
      ADDONS="${ADDONS},service-monitor"
      normalize_addons
    fi

    if addon_selected service-monitor; then
      SERVICE_MONITOR_ENABLED="true"
    fi
  fi
}


validate_action_feature_gates() {
  package_profile_supports_action "${ACTION}" || die "当前产物包(${PACKAGE_PROFILE})不支持动作 ${ACTION}，可用动作: $(package_profile_supported_actions_text)"

  case "${ACTION}" in
    addon-install|addon-uninstall)
      [[ -n "${ADDONS}" ]] || die "动作 ${ACTION} 需要提供 --addons"
      local addon_name
      IFS=',' read -r -a requested_addons <<< "${ADDONS}"
      for addon_name in "${requested_addons[@]}"; do
        addon_name="$(trim_string "${addon_name}")"
        [[ -n "${addon_name}" ]] || continue
        package_profile_supports_addon "${addon_name}" || die "当前产物包(${PACKAGE_PROFILE})不支持 addon ${addon_name}"
      done
      ;;
  esac
}

trim_string() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}


normalize_csv_list() {
  local raw="${1:-}"
  local normalized=()
  local item

  raw="${raw//|/,}"
  IFS=',' read -r -a items <<< "${raw}"
  for item in "${items[@]}"; do
    item="$(trim_string "${item}")"
    [[ -n "${item}" ]] || continue
    normalized+=("${item}")
  done

  (IFS=,; printf '%s' "${normalized[*]}")
}


backup_plan_parser_python() {
  if command -v python3 >/dev/null 2>&1; then
    echo "python3"
    return 0
  fi

  if command -v python >/dev/null 2>&1; then
    echo "python"
    return 0
  fi

  return 1
}


backup_plan_file_parse_lines() {
  local config_path="$1"
  local python_cmd

  python_cmd="$(backup_plan_parser_python)" || die "使用 --backup-plan-file 需要 python3 或 python"
  "${python_cmd}" - "${config_path}" <<'PY'
from __future__ import annotations

import json
import pathlib
import re
import sys


def strip_comments(line: str) -> str:
    in_single = False
    in_double = False
    escaped = False
    result = []

    for ch in line:
        if escaped:
            result.append(ch)
            escaped = False
            continue
        if ch == "\\":
            result.append(ch)
            escaped = True
            continue
        if ch == "'" and not in_double:
            in_single = not in_single
            result.append(ch)
            continue
        if ch == '"' and not in_single:
            in_double = not in_double
            result.append(ch)
            continue
        if ch == "#" and not in_single and not in_double:
            break
        result.append(ch)

    return "".join(result).rstrip()


def parse_scalar(value: str):
    raw = value.strip()
    if len(raw) >= 2 and raw[0] == raw[-1] and raw[0] in ("'", '"'):
        raw = raw[1:-1]
    lowered = raw.lower()
    if lowered == "true":
        return True
    if lowered == "false":
        return False
    if lowered in ("null", "none"):
        return None
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    return raw


def parse_key_value(text: str):
    if ":" not in text:
        raise ValueError(f"invalid line: {text}")
    key, value = text.split(":", 1)
    return key.strip(), value.strip()


def parse_yaml(text: str):
    prepared = []
    for raw in text.splitlines():
        cleaned = strip_comments(raw)
        if not cleaned.strip():
            continue
        indent = len(cleaned) - len(cleaned.lstrip(" "))
        if indent % 2:
            raise ValueError("YAML indentation must use multiples of 2 spaces")
        prepared.append((indent, cleaned.lstrip()))

    def parse_scalar_map(start_index: int, indent: int):
        mapping = {}
        index = start_index
        while index < len(prepared):
            current_indent, content = prepared[index]
            if current_indent < indent:
                break
            if current_indent != indent or content.startswith("- "):
                raise ValueError(f"invalid map entry near: {content}")

            key, rest = parse_key_value(content)
            index += 1
            if rest:
              mapping[key] = parse_scalar(rest)
              continue

            items = []
            while index < len(prepared):
                child_indent, child_content = prepared[index]
                if child_indent < indent + 2:
                    break
                if child_indent != indent + 2 or not child_content.startswith("- "):
                    raise ValueError(f"expected list item for {key}")
                items.append(parse_scalar(child_content[2:].strip()))
                index += 1
            mapping[key] = items

        return mapping, index

    def parse_plan_list(start_index: int, indent: int):
        plans = []
        index = start_index
        while index < len(prepared):
            current_indent, content = prepared[index]
            if current_indent < indent:
                break
            if current_indent != indent or not content.startswith("- "):
                raise ValueError(f"invalid plan entry near: {content}")

            item = {}
            inline = content[2:].strip()
            if inline:
                key, rest = parse_key_value(inline)
                item[key] = parse_scalar(rest)
            index += 1

            while index < len(prepared):
                child_indent, child_content = prepared[index]
                if child_indent <= indent:
                    break
                if child_indent != indent + 2:
                    raise ValueError(f"invalid plan child near: {child_content}")

                key, rest = parse_key_value(child_content)
                index += 1
                if rest:
                    item[key] = parse_scalar(rest)
                    continue

                values = []
                while index < len(prepared):
                    list_indent, list_content = prepared[index]
                    if list_indent < indent + 4:
                        break
                    if list_indent != indent + 4 or not list_content.startswith("- "):
                        raise ValueError(f"expected list entry for {key}")
                    values.append(parse_scalar(list_content[2:].strip()))
                    index += 1
                item[key] = values

            plans.append(item)

        return plans, index

    data = {}
    index = 0
    while index < len(prepared):
        indent, content = prepared[index]
        if indent != 0:
            raise ValueError(f"invalid top-level entry near: {content}")
        key, rest = parse_key_value(content)
        index += 1
        if rest:
            data[key] = parse_scalar(rest)
            continue

        if key in ("plans", "backupPlans"):
            plans, index = parse_plan_list(index, 2)
            data["plans"] = plans
        elif key == "defaults":
            defaults, index = parse_scalar_map(index, 2)
            data["defaults"] = defaults
        elif key == "defaultPlan":
            default_plan, index = parse_scalar_map(index, 2)
            data["defaultPlan"] = default_plan
        else:
            raise ValueError(f"unsupported YAML section: {key}")

    return data


def ensure_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def normalize_scalar(value):
    if value is None:
        return ""
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def normalize_list(value):
    items = []
    for item in ensure_list(value):
        item_text = normalize_scalar(item).strip()
        if item_text:
            items.append(item_text)
    return ",".join(items)


def load_config(path: pathlib.Path):
    text = path.read_text(encoding="utf-8")
    suffix = path.suffix.lower()

    if suffix == ".json":
        return json.loads(text)

    if suffix in (".yaml", ".yml"):
        return parse_yaml(text)

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return parse_yaml(text)


def serialize_plan(plan: dict) -> str:
    field_order = [
        "name",
        "storeName",
        "backend",
        "rootDir",
        "schedule",
        "retention",
        "nfsServer",
        "nfsPath",
        "s3Endpoint",
        "s3Bucket",
        "s3Prefix",
        "s3AccessKey",
        "s3SecretKey",
        "s3Insecure",
        "databases",
        "tables",
    ]

    encoded = []
    for key in field_order:
        value = plan.get(key)
        if key in ("databases", "tables"):
            encoded.append(f"{key}={normalize_list(value)}")
        else:
            encoded.append(f"{key}={normalize_scalar(value)}")
    return ";".join(encoded)


config_path = pathlib.Path(sys.argv[1])
config = load_config(config_path)
if not isinstance(config, dict):
    raise SystemExit("backup plan file root must be an object")

defaults = config.get("defaults") or {}
if defaults and not isinstance(defaults, dict):
    raise SystemExit("defaults must be an object")

default_plan = config.get("defaultPlan") or {}
if default_plan and not isinstance(default_plan, dict):
    raise SystemExit("defaultPlan must be an object")

default_plan_enabled = config.get("defaultPlanEnabled")
if default_plan_enabled is None and "enabled" in default_plan:
    default_plan_enabled = default_plan.get("enabled")

restore_source = config.get("restoreSource")
plans = config.get("plans") or config.get("backupPlans") or []
if not isinstance(plans, list):
    raise SystemExit("plans must be a list")

if default_plan_enabled is not None:
    print(f"meta defaultPlanEnabled {normalize_scalar(default_plan_enabled)}")
if restore_source is not None:
    print(f"meta restoreSource {normalize_scalar(restore_source)}")

for raw_plan in plans:
    if not isinstance(raw_plan, dict):
        raise SystemExit("each plan must be an object")
    merged = dict(defaults)
    merged.update(raw_plan)
    print("spec " + serialize_plan(merged))
PY
}


load_backup_plan_file_if_requested() {
  local config_path line
  local -a cli_specs=()
  local -a loaded_specs=()

  [[ -n "${BACKUP_PLAN_FILE}" ]] || return 0
  [[ -f "${BACKUP_PLAN_FILE}" ]] || die "backup plan file 不存在: ${BACKUP_PLAN_FILE}"

  config_path="${BACKUP_PLAN_FILE}"
  cli_specs=("${BACKUP_PLAN_EXTRA_SPECS[@]}")
  BACKUP_PLAN_EXTRA_SPECS=()

  while IFS= read -r line; do
    line="${line%$'\r'}"
    [[ -n "${line}" ]] || continue
    case "${line}" in
      meta\ defaultPlanEnabled\ *)
        if [[ "${BACKUP_DEFAULT_PLAN_ENABLED_EXPLICIT}" != "true" ]]; then
          BACKUP_DEFAULT_PLAN_ENABLED="${line#meta defaultPlanEnabled }"
        fi
        ;;
      meta\ restoreSource\ *)
        if [[ "${BACKUP_RESTORE_SOURCE_EXPLICIT}" != "true" ]]; then
          BACKUP_RESTORE_SOURCE="${line#meta restoreSource }"
        fi
        ;;
      spec\ *)
        loaded_specs+=("${line#spec }")
        ;;
      *)
        die "无法识别 backup plan file 输出: ${line}"
        ;;
    esac
  done < <(backup_plan_file_parse_lines "${config_path}")

  BACKUP_PLAN_EXTRA_SPECS=("${loaded_specs[@]}" "${cli_specs[@]}")
}


capture_default_backup_plan_settings() {
  [[ "${BACKUP_PLAN_DEFAULTS_CAPTURED}" == "true" ]] && return 0

  BACKUP_PLAN_DEFAULT_NAME="${BACKUP_PLAN_NAME:-primary}"
  BACKUP_PLAN_DEFAULT_STORE_NAME="${BACKUP_STORE_NAME:-${BACKUP_PLAN_DEFAULT_NAME}}"
  BACKUP_PLAN_DEFAULT_BACKEND="${BACKUP_BACKEND}"
  BACKUP_PLAN_DEFAULT_NFS_SERVER="${BACKUP_NFS_SERVER}"
  BACKUP_PLAN_DEFAULT_NFS_PATH="${BACKUP_NFS_PATH}"
  BACKUP_PLAN_DEFAULT_ROOT_DIR="${BACKUP_ROOT_DIR}"
  BACKUP_PLAN_DEFAULT_SCHEDULE="${BACKUP_SCHEDULE}"
  BACKUP_PLAN_DEFAULT_RETENTION="${BACKUP_RETENTION}"
  BACKUP_PLAN_DEFAULT_S3_ENDPOINT="${S3_ENDPOINT}"
  BACKUP_PLAN_DEFAULT_S3_BUCKET="${S3_BUCKET}"
  BACKUP_PLAN_DEFAULT_S3_PREFIX="${S3_PREFIX}"
  BACKUP_PLAN_DEFAULT_S3_ACCESS_KEY="${S3_ACCESS_KEY}"
  BACKUP_PLAN_DEFAULT_S3_SECRET_KEY="${S3_SECRET_KEY}"
  BACKUP_PLAN_DEFAULT_S3_INSECURE="${S3_INSECURE}"
  BACKUP_PLAN_DEFAULT_CRONJOB_NAME="${BACKUP_CRONJOB_NAME}"
  BACKUP_PLAN_DEFAULT_STORAGE_SECRET="${BACKUP_STORAGE_SECRET}"
  BACKUP_PLAN_DEFAULT_DATABASES="${BACKUP_DATABASES}"
  BACKUP_PLAN_DEFAULT_TABLES="${BACKUP_TABLES}"
  BACKUP_PLAN_DEFAULTS_CAPTURED="true"
}


backup_plan_reset_active() {
  capture_default_backup_plan_settings

  BACKUP_PLAN_NAME="${BACKUP_PLAN_DEFAULT_NAME}"
  BACKUP_STORE_NAME="${BACKUP_PLAN_DEFAULT_STORE_NAME}"
  BACKUP_BACKEND="${BACKUP_PLAN_DEFAULT_BACKEND}"
  BACKUP_NFS_SERVER="${BACKUP_PLAN_DEFAULT_NFS_SERVER}"
  BACKUP_NFS_PATH="${BACKUP_PLAN_DEFAULT_NFS_PATH}"
  BACKUP_ROOT_DIR="${BACKUP_PLAN_DEFAULT_ROOT_DIR}"
  BACKUP_SCHEDULE="${BACKUP_PLAN_DEFAULT_SCHEDULE}"
  BACKUP_RETENTION="${BACKUP_PLAN_DEFAULT_RETENTION}"
  S3_ENDPOINT="${BACKUP_PLAN_DEFAULT_S3_ENDPOINT}"
  S3_BUCKET="${BACKUP_PLAN_DEFAULT_S3_BUCKET}"
  S3_PREFIX="${BACKUP_PLAN_DEFAULT_S3_PREFIX}"
  S3_ACCESS_KEY="${BACKUP_PLAN_DEFAULT_S3_ACCESS_KEY}"
  S3_SECRET_KEY="${BACKUP_PLAN_DEFAULT_S3_SECRET_KEY}"
  S3_INSECURE="${BACKUP_PLAN_DEFAULT_S3_INSECURE}"
  BACKUP_CRONJOB_NAME="${BACKUP_PLAN_DEFAULT_CRONJOB_NAME}"
  BACKUP_STORAGE_SECRET="${BACKUP_PLAN_DEFAULT_STORAGE_SECRET}"
  BACKUP_DATABASES="${BACKUP_PLAN_DEFAULT_DATABASES}"
  BACKUP_TABLES="${BACKUP_PLAN_DEFAULT_TABLES}"
}


backup_plan_scope_type() {
  if [[ -n "${BACKUP_TABLES}" ]]; then
    echo "tables"
  elif [[ -n "${BACKUP_DATABASES}" ]]; then
    echo "databases"
  else
    echo "all"
  fi
}


backup_plan_apply_derived_names() {
  local normalized_name normalized_store

  normalized_name="$(sanitize_target_name "${BACKUP_PLAN_NAME}")"
  [[ -n "${normalized_name}" ]] || die "backup plan name 不能为空"
  BACKUP_PLAN_NAME="${normalized_name}"

  if [[ -n "${BACKUP_STORE_NAME}" ]]; then
    normalized_store="$(sanitize_target_name "${BACKUP_STORE_NAME}")"
  else
    normalized_store="${BACKUP_PLAN_NAME}"
  fi
  [[ -n "${normalized_store}" ]] || die "backup store name 不能为空"
  BACKUP_STORE_NAME="${normalized_store}"

  if [[ "${BACKUP_PLAN_NAME}" == "${BACKUP_PLAN_DEFAULT_NAME}" ]]; then
    BACKUP_CRONJOB_NAME="${BACKUP_PLAN_DEFAULT_CRONJOB_NAME}"
    BACKUP_STORAGE_SECRET="${BACKUP_PLAN_DEFAULT_STORAGE_SECRET}"
  else
    BACKUP_CRONJOB_NAME="${BACKUP_PLAN_DEFAULT_CRONJOB_NAME}-${BACKUP_PLAN_NAME}"
    BACKUP_STORAGE_SECRET="${BACKUP_PLAN_DEFAULT_STORAGE_SECRET}-${BACKUP_PLAN_NAME}"
  fi
}


backup_plan_validate_active() {
  local schedule_required="${1:-false}"
  local entry database_name table_name

  [[ "${BACKUP_BACKEND}" == "nfs" || "${BACKUP_BACKEND}" == "s3" ]] || die "backup plan ${BACKUP_PLAN_NAME} 的 backend 仅支持 nfs 或 s3"
  [[ "${BACKUP_RETENTION}" =~ ^[0-9]+$ ]] || die "backup plan ${BACKUP_PLAN_NAME} 的 retention 必须是数字"

  if [[ "${schedule_required}" == "true" && -z "${BACKUP_SCHEDULE}" ]]; then
    die "backup plan ${BACKUP_PLAN_NAME} 缺少 schedule"
  fi

  if [[ -n "${BACKUP_DATABASES}" && -n "${BACKUP_TABLES}" ]]; then
    die "backup plan ${BACKUP_PLAN_NAME} 不能同时指定 databases 和 tables"
  fi

  if [[ "${BACKUP_BACKEND}" == "nfs" ]]; then
    [[ -n "${BACKUP_NFS_SERVER}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 使用 NFS 时必须提供 nfsServer"
    [[ -n "${BACKUP_NFS_PATH}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 使用 NFS 时必须提供 nfsPath"
  fi

  if [[ "${BACKUP_BACKEND}" == "s3" ]]; then
    [[ -n "${S3_ENDPOINT}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 使用 S3 时必须提供 s3Endpoint"
    [[ -n "${S3_BUCKET}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 使用 S3 时必须提供 s3Bucket"
    [[ -n "${S3_ACCESS_KEY}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 使用 S3 时必须提供 s3AccessKey"
    [[ -n "${S3_SECRET_KEY}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 使用 S3 时必须提供 s3SecretKey"
  fi

  if [[ -n "${BACKUP_TABLES}" ]]; then
    IFS=',' read -r -a entries <<< "${BACKUP_TABLES}"
    for entry in "${entries[@]}"; do
      entry="$(trim_string "${entry}")"
      [[ -n "${entry}" ]] || continue
      database_name="${entry%%.*}"
      table_name="${entry#*.}"
      [[ -n "${database_name}" && -n "${table_name}" && "${database_name}" != "${entry}" ]] || die "backup plan ${BACKUP_PLAN_NAME} 的 tables 需使用 db.table 形式: ${entry}"
    done
  fi
}


backup_plan_serialize_active() {
  printf 'name=%s;storeName=%s;backend=%s;rootDir=%s;schedule=%s;retention=%s;nfsServer=%s;nfsPath=%s;s3Endpoint=%s;s3Bucket=%s;s3Prefix=%s;s3AccessKey=%s;s3SecretKey=%s;s3Insecure=%s;databases=%s;tables=%s' \
    "${BACKUP_PLAN_NAME}" \
    "${BACKUP_STORE_NAME}" \
    "${BACKUP_BACKEND}" \
    "${BACKUP_ROOT_DIR}" \
    "${BACKUP_SCHEDULE}" \
    "${BACKUP_RETENTION}" \
    "${BACKUP_NFS_SERVER}" \
    "${BACKUP_NFS_PATH}" \
    "${S3_ENDPOINT}" \
    "${S3_BUCKET}" \
    "${S3_PREFIX}" \
    "${S3_ACCESS_KEY}" \
    "${S3_SECRET_KEY}" \
    "${S3_INSECURE}" \
    "${BACKUP_DATABASES}" \
    "${BACKUP_TABLES}"
}


backup_plan_activate_spec() {
  local raw_spec="$1"
  local part key value
  local store_name_explicit="false"

  backup_plan_reset_active
  [[ -n "${raw_spec}" ]] || {
    backup_plan_apply_derived_names
    return 0
  }

  IFS=';' read -r -a parts <<< "${raw_spec}"
  for part in "${parts[@]}"; do
    part="$(trim_string "${part}")"
    [[ -n "${part}" ]] || continue
    [[ "${part}" == *=* ]] || die "backup plan 配置格式错误: ${part}"
    key="$(trim_string "${part%%=*}")"
    value="$(trim_string "${part#*=}")"

    case "${key}" in
      name)
        BACKUP_PLAN_NAME="${value}"
        ;;
      storeName|store|store-name)
        BACKUP_STORE_NAME="${value}"
        store_name_explicit="true"
        ;;
      type|backend)
        BACKUP_BACKEND="${value}"
        ;;
      rootDir|root|root-dir)
        BACKUP_ROOT_DIR="${value}"
        ;;
      schedule)
        BACKUP_SCHEDULE="${value}"
        ;;
      retention)
        BACKUP_RETENTION="${value}"
        ;;
      nfsServer|nfs-server)
        BACKUP_NFS_SERVER="${value}"
        ;;
      nfsPath|nfs-path)
        BACKUP_NFS_PATH="${value}"
        ;;
      s3Endpoint|s3-endpoint)
        S3_ENDPOINT="${value}"
        ;;
      s3Bucket|s3-bucket)
        S3_BUCKET="${value}"
        ;;
      s3Prefix|s3-prefix)
        S3_PREFIX="${value}"
        ;;
      s3AccessKey|s3-access-key)
        S3_ACCESS_KEY="${value}"
        ;;
      s3SecretKey|s3-secret-key)
        S3_SECRET_KEY="${value}"
        ;;
      s3Insecure|s3-insecure)
        S3_INSECURE="${value}"
        ;;
      databases|dbs)
        BACKUP_DATABASES="$(normalize_csv_list "${value}")"
        ;;
      tables)
        BACKUP_TABLES="$(normalize_csv_list "${value}")"
        ;;
      *)
        die "backup plan ${raw_spec} 中存在未知字段: ${key}"
        ;;
    esac
  done

  BACKUP_DATABASES="$(normalize_csv_list "${BACKUP_DATABASES}")"
  BACKUP_TABLES="$(normalize_csv_list "${BACKUP_TABLES}")"
  if [[ -n "${raw_spec}" && "${store_name_explicit}" != "true" ]]; then
    BACKUP_STORE_NAME=""
  fi
  backup_plan_apply_derived_names
}


backup_plan_catalog_required() {
  case "${ACTION}" in
    install)
      [[ "${BACKUP_ENABLED}" == "true" ]]
      ;;
    addon-install)
      addon_selected backup
      ;;
    backup|restore|verify-backup-restore)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}


backup_plan_default_requested() {
  [[ "${BACKUP_DEFAULT_PLAN_ENABLED}" == "true" || ${#BACKUP_PLAN_EXTRA_SPECS[@]} -eq 0 ]]
}


backup_plan_default_spec() {
  backup_plan_activate_spec ""
  printf '%s' "$(backup_plan_serialize_active)"
}


backup_plan_build_catalog() {
  local spec normalized_spec
  local existing_name

  BACKUP_PLAN_CATALOG=()
  BACKUP_PLAN_NAMES=()

  backup_plan_catalog_required || return 0

  if [[ "${BACKUP_DEFAULT_PLAN_ENABLED}" == "true" || ${#BACKUP_PLAN_EXTRA_SPECS[@]} -eq 0 ]]; then
    normalized_spec="$(backup_plan_default_spec)"
    BACKUP_PLAN_CATALOG+=("${normalized_spec}")
    BACKUP_PLAN_NAMES+=("${BACKUP_PLAN_NAME}")
  fi

  for spec in "${BACKUP_PLAN_EXTRA_SPECS[@]}"; do
    backup_plan_activate_spec "${spec}"
    normalized_spec="$(backup_plan_serialize_active)"

    for existing_name in "${BACKUP_PLAN_NAMES[@]}"; do
      [[ "${existing_name}" != "${BACKUP_PLAN_NAME}" ]] || die "backup plan name 重复: ${BACKUP_PLAN_NAME}"
    done

    BACKUP_PLAN_CATALOG+=("${normalized_spec}")
    BACKUP_PLAN_NAMES+=("${BACKUP_PLAN_NAME}")
  done

  (( ${#BACKUP_PLAN_CATALOG[@]} > 0 )) || die "未找到可用的 backup plan，请提供默认备份配置，或通过 --backup-plan 显式定义"
  backup_plan_activate_spec "${BACKUP_PLAN_CATALOG[0]}"
}


backup_plan_validate_catalog() {
  local spec
  local schedule_required="false"

  backup_schedule_required && schedule_required="true"
  backup_plan_build_catalog

  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    backup_plan_validate_active "${schedule_required}"
  done

  if [[ "${ACTION}" == "restore" || "${ACTION}" == "verify-backup-restore" ]]; then
    if [[ "${BACKUP_RESTORE_SOURCE}" != "auto" ]]; then
      backup_plan_spec_by_name "${BACKUP_RESTORE_SOURCE}" >/dev/null || die "未找到 restore-source=${BACKUP_RESTORE_SOURCE} 对应的 backup plan"
    fi
  fi

  if (( ${#BACKUP_PLAN_CATALOG[@]} > 0 )); then
    backup_plan_activate_spec "${BACKUP_PLAN_CATALOG[0]}"
  fi
}


backup_plan_spec_by_name() {
  local plan_name="$1"
  local index

  backup_plan_build_catalog
  for ((index=0; index<${#BACKUP_PLAN_NAMES[@]}; index++)); do
    if [[ "${BACKUP_PLAN_NAMES[$index]}" == "${plan_name}" ]]; then
      printf '%s' "${BACKUP_PLAN_CATALOG[$index]}"
      return 0
    fi
  done

  return 1
}


backup_plan_specs_for_restore() {
  local spec

  backup_plan_build_catalog
  if [[ "${BACKUP_RESTORE_SOURCE}" == "auto" ]]; then
    printf '%s\n' "${BACKUP_PLAN_CATALOG[@]}"
    return 0
  fi

  spec="$(backup_plan_spec_by_name "${BACKUP_RESTORE_SOURCE}")" || return 1
  printf '%s\n' "${spec}"
}


backup_plan_any_uses_backend() {
  local backend_name="$1"
  local spec

  backup_plan_build_catalog
  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    if [[ "${BACKUP_BACKEND}" == "${backend_name}" ]]; then
      return 0
    fi
  done

  return 1
}


csv_list_contains() {
  local csv_list="$1"
  local expected="$2"
  local item

  IFS=',' read -r -a items <<< "${csv_list}"
  for item in "${items[@]}"; do
    item="$(trim_string "${item}")"
    [[ -n "${item}" ]] || continue
    [[ "${item}" == "${expected}" ]] && return 0
  done

  return 1
}


backup_plan_supports_wipe_restore() {
  [[ "$(backup_plan_scope_type)" == "all" ]]
}


backup_plan_contains_database() {
  local database_name="$1"
  local scope_type

  scope_type="$(backup_plan_scope_type)"
  case "${scope_type}" in
    all)
      return 0
      ;;
    databases)
      csv_list_contains "${BACKUP_DATABASES}" "${database_name}"
      return
      ;;
    tables)
      local item
      IFS=',' read -r -a items <<< "${BACKUP_TABLES}"
      for item in "${items[@]}"; do
        item="$(trim_string "${item}")"
        [[ -n "${item}" ]] || continue
        [[ "${item}" == "${database_name}."* ]] && return 0
      done
      ;;
  esac

  return 1
}


backup_plan_contains_table() {
  local table_selector="$1"
  local database_name="${table_selector%%.*}"

  if [[ "$(backup_plan_scope_type)" == "all" ]]; then
    return 0
  fi

  if [[ "$(backup_plan_scope_type)" == "databases" ]]; then
    csv_list_contains "${BACKUP_DATABASES}" "${database_name}"
    return
  fi

  csv_list_contains "${BACKUP_TABLES}" "${table_selector}"
}


backup_plan_supports_verify_marker() {
  backup_plan_contains_table "offline_validation.backup_restore_check" && return 0
  backup_plan_contains_database "offline_validation"
}


backup_plan_scope_summary() {
  case "$(backup_plan_scope_type)" in
    all)
      echo "all"
      ;;
    databases)
      echo "databases:${BACKUP_DATABASES}"
      ;;
    tables)
      echo "tables:${BACKUP_TABLES}"
      ;;
  esac
}


backup_plan_summary_lines() {
  local spec
  local index=1

  backup_plan_build_catalog
  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    printf '  %s. %s | backend=%s | store=%s | schedule=%s | scope=%s\n' \
      "${index}" \
      "${BACKUP_PLAN_NAME}" \
      "${BACKUP_BACKEND}" \
      "${BACKUP_STORE_NAME}" \
      "${BACKUP_SCHEDULE:-manual-only}" \
      "$(backup_plan_scope_summary)"
    index=$((index + 1))
  done
}

secret_has_key() {
  local secret_name="$1"
  local key_name="$2"
  kubectl get secret -n "${NAMESPACE}" "${secret_name}" -o "jsonpath={.data.${key_name}}" >/dev/null 2>&1
}


runtime_action_requires_explicit_mysql_auth() {
  case "${ACTION}" in
    backup|restore|verify-backup-restore)
      return 0
      ;;
    addon-install)
      addon_selected backup && return 0
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

prepare_runtime_auth_secret() {
  action_needs_mysql_auth || return 0

  if [[ -n "${MYSQL_PASSWORD}" ]]; then
    kubectl create secret generic "${MYSQL_AUTH_SECRET}" \
      -n "${NAMESPACE}" \
      --from-literal="${MYSQL_PASSWORD_KEY}=${MYSQL_PASSWORD}" \
      --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    return 0
  fi

  if secret_has_key "${MYSQL_AUTH_SECRET}" "${MYSQL_PASSWORD_KEY}"; then
    return 0
  fi

  if runtime_action_requires_explicit_mysql_auth; then
    die "当前动作要求显式提供可用的 MySQL 凭据，请传 --mysql-password，或提供已有的 --mysql-auth-secret/--mysql-password-key。"
  fi

  if [[ "${MYSQL_ROOT_PASSWORD_EXPLICIT}" == "true" && "${MYSQL_AUTH_SECRET}" == "${AUTH_SECRET}" && "${MYSQL_PASSWORD_KEY}" == "mysql-root-password" ]]; then
    warn "未找到 Secret/${MYSQL_AUTH_SECRET}，将使用显式传入的 --root-password 创建。"
    kubectl create secret generic "${MYSQL_AUTH_SECRET}" \
      -n "${NAMESPACE}" \
      --from-literal="${MYSQL_PASSWORD_KEY}=${MYSQL_ROOT_PASSWORD}" \
      --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    return 0
  fi

  die "命名空间 ${NAMESPACE} 中未找到 Secret/${MYSQL_AUTH_SECRET} 的键 ${MYSQL_PASSWORD_KEY}，请显式传 --mysql-password，或指定正确的 --mysql-auth-secret/--mysql-password-key。"
}

prompt_missing_values() {
  if needs_backup_storage && backup_plan_default_requested && backup_backend_is_nfs && [[ -z "${BACKUP_NFS_SERVER}" ]]; then
    echo -ne "${YELLOW}请输入 NFS 服务器地址:${NC} "
    read -r BACKUP_NFS_SERVER
  fi

  if needs_backup_storage && backup_plan_default_requested && backup_backend_is_s3; then
    if [[ -z "${S3_ENDPOINT}" ]]; then
      echo -ne "${YELLOW}请输入 S3 Endpoint（如 https://minio.example.com）:${NC} "
      read -r S3_ENDPOINT
    fi
    if [[ -z "${S3_BUCKET}" ]]; then
      echo -ne "${YELLOW}请输入 S3 Bucket:${NC} "
      read -r S3_BUCKET
    fi
    if [[ -z "${S3_ACCESS_KEY}" ]]; then
      echo -ne "${YELLOW}请输入 S3 Access Key:${NC} "
      read -r S3_ACCESS_KEY
    fi
    if [[ -z "${S3_SECRET_KEY}" ]]; then
      echo -ne "${YELLOW}请输入 S3 Secret Key:${NC} "
      read -rs S3_SECRET_KEY
      echo
    fi
  fi

  if needs_backup_storage && backup_plan_default_requested; then
    [[ -n "${BACKUP_NFS_PATH}" ]] || BACKUP_NFS_PATH="/data/nfs-share"
  fi
}


validate_environment() {
  command -v kubectl >/dev/null 2>&1 || die "未找到 kubectl"

  if action_needs_image_prepare && [[ "${SKIP_IMAGE_PREPARE}" != "true" ]]; then
    command -v docker >/dev/null 2>&1 || die "未找到 docker"
    command -v jq >/dev/null 2>&1 || die "未找到 jq"
  fi
}


validate_inputs() {
  [[ "${NODEPORT_ENABLED}" =~ ^(true|false)$ ]] || die "--nodeport-enabled 仅支持 true 或 false"
  [[ "${BACKUP_DEFAULT_PLAN_ENABLED}" =~ ^(true|false)$ ]] || die "default backup plan 开关仅支持 true 或 false"

  if [[ "${ACTION}" != "addon-status" ]]; then
    [[ "${MYSQL_REPLICAS}" =~ ^[0-9]+$ ]] || die "mysql 副本数必须是数字"
    if [[ "${NODEPORT_ENABLED}" == "true" ]]; then
      [[ "${NODE_PORT}" =~ ^[0-9]+$ ]] || die "nodePort 必须是数字"
      (( NODE_PORT >= 30000 && NODE_PORT <= 32767 )) || die "nodePort 必须在 30000-32767 之间"
    fi
  fi

  [[ "${MYSQL_PORT}" =~ ^[0-9]+$ ]] || die "MySQL 端口必须是数字"
  [[ "${BACKUP_RETENTION}" =~ ^[0-9]+$ ]] || die "备份保留数量必须是数字"
  [[ "${BENCHMARK_THREADS}" =~ ^[0-9]+$ ]] || die "压测线程数必须是数字"
  [[ "${BENCHMARK_TIME}" =~ ^[0-9]+$ ]] || die "压测时长必须是数字"
  [[ "${BENCHMARK_WARMUP_TIME}" =~ ^[0-9]+$ ]] || die "压测 warmup 时长必须是数字"
  [[ "${BENCHMARK_WARMUP_ROWS}" =~ ^[0-9]+$ ]] || die "压测 warmup 数据量必须是数字"
  [[ "${BENCHMARK_TABLES}" =~ ^[0-9]+$ ]] || die "压测表数必须是数字"
  [[ "${BENCHMARK_TABLE_SIZE}" =~ ^[0-9]+$ ]] || die "压测单表数据量必须是数字"
  [[ "${MYSQL_SLOW_QUERY_TIME}" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "慢查询阈值必须是数字"
  [[ "${MYSQL_RESTORE_MODE}" =~ ^(merge|wipe-all-user-databases)$ ]] || die "restore-mode 仅支持 merge 或 wipe-all-user-databases"
  [[ "${BENCHMARK_PROFILE}" =~ ^(standard|oltp-point-select|oltp-read-only|oltp-read-write)$ ]] || die "benchmark-profile 仅支持 standard、oltp-point-select、oltp-read-only、oltp-read-write"

  if needs_backup_storage && backup_plan_default_requested; then
    [[ "${BACKUP_BACKEND}" == "nfs" || "${BACKUP_BACKEND}" == "s3" ]] || die "备份后端仅支持 nfs 或 s3"
    [[ "${BACKUP_RETENTION}" =~ ^[0-9]+$ ]] || die "备份保留数量必须是数字"

    if backup_backend_is_nfs && [[ -z "${BACKUP_NFS_SERVER}" ]]; then
      die "使用 NFS 备份时必须提供 --backup-nfs-server"
    fi

    if backup_backend_is_s3; then
      [[ -n "${S3_ENDPOINT}" ]] || die "使用 S3 备份时必须提供 --s3-endpoint"
      [[ -n "${S3_BUCKET}" ]] || die "使用 S3 备份时必须提供 --s3-bucket"
      [[ -n "${S3_ACCESS_KEY}" ]] || die "使用 S3 备份时必须提供 --s3-access-key"
      [[ -n "${S3_SECRET_KEY}" ]] || die "使用 S3 备份时必须提供 --s3-secret-key"
    fi
  fi

  backup_plan_validate_catalog

  validate_action_feature_gates
}

mysql_auth_source_summary() {
  if [[ -n "${MYSQL_PASSWORD}" ]]; then
    echo "显式密码参数"
  else
    echo "Secret/${MYSQL_AUTH_SECRET}:${MYSQL_PASSWORD_KEY}"
  fi
}


print_plan() {
  section "执行计划"
  echo "动作                    : ${ACTION}"
  echo "产物包                  : $(package_profile_label)"
  echo "命名空间                : ${NAMESPACE}"
  echo "等待超时                : ${WAIT_TIMEOUT}"

  case "${ACTION}" in
    install)
      echo "StatefulSet             : ${STS_NAME}"
      echo "服务名                  : ${SERVICE_NAME}"
      echo "NodePort 开关           : ${NODEPORT_ENABLED}"
      if [[ "${NODEPORT_ENABLED}" == "true" ]]; then
        echo "NodePort 服务名         : ${NODEPORT_SERVICE_NAME}"
        echo "NodePort                : ${NODE_PORT}"
      fi
      echo "副本数                  : ${MYSQL_REPLICAS}"
      echo "StorageClass            : ${STORAGE_CLASS}"
      echo "存储大小                : ${STORAGE_SIZE}"
      echo "数据目录                : /var/lib/mysql（固定）"
      echo "镜像前缀                : ${REGISTRY_REPO}"
      echo "监控 exporter           : ${MONITORING_ENABLED}"
      echo "ServiceMonitor          : ${SERVICE_MONITOR_ENABLED}"
      echo "Fluent Bit              : ${FLUENTBIT_ENABLED}"
      echo "备份组件                : ${BACKUP_ENABLED}"
      echo "压测能力                : ${BENCHMARK_ENABLED}"
      echo "默认特性开关            : monitoring/service-monitor/fluentbit/backup/benchmark"
      echo "业务影响                : install 会整体对齐 StatefulSet，配置变化时可能触发滚动更新"
      ;;
    addon-install|addon-uninstall)
      echo "Addon 列表              : ${ADDONS}"
      echo "业务影响                : 默认只新增或删除外置资源，不修改 MySQL StatefulSet"
      if addon_selected monitoring; then
        echo "监控目标                : ${ADDON_MONITORING_TARGET}"
        echo "监控账号                : ${ADDON_EXPORTER_USERNAME}"
      fi
      if addon_selected backup; then
        echo "备份目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
        echo "备份账号                : ${MYSQL_USER}"
        echo "认证来源                : $(mysql_auth_source_summary)"
        echo "逻辑实例名              : ${MYSQL_TARGET_NAME}"
      fi
      ;;
    backup)
      echo "执行模式                : 立即执行一次备份 Job"
      echo "备份目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
      echo "备份账号                : ${MYSQL_USER}"
      echo "认证来源                : $(mysql_auth_source_summary)"
      echo "逻辑实例名              : ${MYSQL_TARGET_NAME}"
      echo "备份后端                : ${BACKUP_BACKEND}"
      echo "保留数量                : ${BACKUP_RETENTION}"
      echo "业务影响                : 只创建一次性备份 Job，不会安装 CronJob"
      ;;
    restore)
      echo "执行模式                : 立即执行一次恢复 Job"
      echo "恢复目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
      echo "恢复账号                : ${MYSQL_USER}"
      echo "认证来源                : $(mysql_auth_source_summary)"
      echo "逻辑实例名              : ${MYSQL_TARGET_NAME}"
      echo "恢复快照                : ${RESTORE_SNAPSHOT}"
      echo "恢复模式                : ${MYSQL_RESTORE_MODE}"
      echo "业务影响                : 会向目标实例导入 SQL，建议在维护窗口执行"
      ;;
    verify-backup-restore)
      echo "执行模式                : 备份/恢复闭环校验"
      echo "校验目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
      echo "校验账号                : ${MYSQL_USER}"
      echo "认证来源                : $(mysql_auth_source_summary)"
      echo "逻辑实例名              : ${MYSQL_TARGET_NAME}"
      echo "业务影响                : 会写入 offline_validation 库表用于校验"
      ;;
    benchmark)
      echo "执行模式                : 工程化压测 Job"
      echo "压测目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
      echo "压测账号                : ${MYSQL_USER}"
      echo "认证来源                : $(mysql_auth_source_summary)"
      echo "压测模型                : ${BENCHMARK_PROFILE}"
      echo "压测线程数              : ${BENCHMARK_THREADS}"
      echo "正式压测时长(秒)        : ${BENCHMARK_TIME}"
      echo "Warmup 时长(秒)         : ${BENCHMARK_WARMUP_TIME}"
      echo "Warmup 数据量(行)       : ${BENCHMARK_WARMUP_ROWS}"
      echo "压测表数                : ${BENCHMARK_TABLES}"
      echo "正式数据量(行)          : ${BENCHMARK_TABLE_SIZE}"
      echo "压测数据库              : ${BENCHMARK_DB}"
      echo "随机分布                : ${BENCHMARK_RAND_TYPE}"
      echo "保留测试数据            : ${BENCHMARK_KEEP_DATA}"
      echo "报告目录                : ${REPORT_DIR}"
      echo "自动等待超时            : $(job_wait_timeout benchmark)"
      ;;
  esac

  if needs_backup_storage; then
    if [[ -n "${BACKUP_PLAN_FILE}" ]]; then
      echo "backup plan file         : ${BACKUP_PLAN_FILE}"
    fi
    echo "backup plans            : ${#BACKUP_PLAN_CATALOG[@]}"
    backup_plan_summary_lines
    if [[ "${ACTION}" == "restore" || "${ACTION}" == "verify-backup-restore" ]]; then
      echo "restore source          : ${BACKUP_RESTORE_SOURCE}"
    fi
  fi
}

confirm_plan() {
  [[ "${AUTO_YES}" == "true" ]] && return 0
  print_plan
  echo
  echo -ne "${YELLOW}确认继续执行？[y/N]:${NC} "
  read -r answer
  [[ "${answer}" =~ ^[Yy]$ ]] || die "用户取消执行"
}

docker_login() {
  log "登录镜像仓库 ${REGISTRY_ADDR}"
  if echo "${REGISTRY_PASS}" | docker login "${REGISTRY_ADDR}" -u "${REGISTRY_USER}" --password-stdin >/dev/null 2>&1; then
    success "镜像仓库登录成功"
  else
    warn "镜像仓库登录失败，继续尝试后续流程"
  fi
}


payload_signature() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$0" | awk '{print $1}'
    return 0
  fi

  cksum "$0" | awk '{print $1 "-" $2}'
}


payload_start_offset() {
  if [[ -n "${PAYLOAD_OFFSET:-}" ]]; then
    printf '%s' "${PAYLOAD_OFFSET}"
    return 0
  fi

  local marker_line payload_offset skip_bytes byte_hex
  marker_line="$(awk '/^__PAYLOAD_BELOW__$/ { print NR; exit }' "$0")"
  [[ -n "${marker_line}" ]] || die "未找到载荷标记"
  payload_offset="$(( $(head -n "${marker_line}" "$0" | wc -c | tr -d ' ') + 1 ))"

  skip_bytes=0
  while :; do
    byte_hex="$(dd if="$0" bs=1 skip="$((payload_offset + skip_bytes - 1))" count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
    case "${byte_hex}" in
      0a|0d)
        skip_bytes=$((skip_bytes + 1))
        ;;
      "")
        die "载荷边界异常，未找到有效的压缩数据"
        ;;
      *)
        break
        ;;
    esac
  done

  PAYLOAD_OFFSET="$((payload_offset + skip_bytes))"
  printf '%s' "${PAYLOAD_OFFSET}"
}


payload_extract_entries() {
  local destination="$1"
  shift

  local payload_offset
  payload_offset="$(payload_start_offset)"
  tail -c +"${payload_offset}" "$0" | tar -xz -C "${destination}" "$@" >/dev/null 2>&1
}


payload_signature_file() {
  printf '%s/.payload-signature' "${WORKDIR}"
}


payload_cache_ready() {
  local expected_signature="$1"
  local signature_file
  signature_file="$(payload_signature_file)"

  [[ -f "${signature_file}" ]] || return 1
  [[ "$(cat "${signature_file}")" == "${expected_signature}" ]] || return 1
  [[ -f "${IMAGE_JSON}" ]] || return 1
}


ensure_image_archive_available() {
  local tar_name="$1"
  local tar_path="${IMAGE_DIR}/${tar_name}"

  if [[ -f "${tar_path}" ]]; then
    return 0
  fi

  log "按需解压镜像归档 ${tar_name}"
  payload_extract_entries "${WORKDIR}" "./images/${tar_name}" || die "解压镜像归档失败: ${tar_name}"
  [[ -f "${tar_path}" ]] || die "解压后仍未找到镜像归档: ${tar_name}"
}


docker_image_exists() {
  docker image inspect "$1" >/dev/null 2>&1
}


resolve_target_image_tag() {
  local source_tag="$1"
  local suffix="${source_tag#*/kube4/}"

  if [[ "${suffix}" == "${source_tag}" ]]; then
    suffix="${source_tag##*/}"
  fi

  printf '%s/%s' "${REGISTRY_REPO}" "${suffix}"
}

prepare_images() {
  [[ "${SKIP_IMAGE_PREPARE}" == "true" ]] && {
    warn "已按要求跳过镜像导入与推送"
    return 0
  }

  section "准备离线镜像"
  docker_login

  local count=0
  while IFS= read -r item; do
    [[ -n "${item}" ]] || continue

    local tar_name image_tag target_tag tar_path
    tar_name="$(jq -r '.tar' <<<"${item}")"
    image_tag="$(jq -r '.tag // .pull' <<<"${item}")"
    target_tag="$(resolve_target_image_tag "${image_tag}")"
    tar_path="${IMAGE_DIR}/${tar_name}"

    image_needed_for_current_action "${image_tag}" || continue

    if docker_image_exists "${target_tag}"; then
      log "复用本地镜像 ${target_tag}"
    else
      if docker_image_exists "${image_tag}"; then
        log "复用本地镜像 ${image_tag}"
      else
        ensure_image_archive_available "${tar_name}"
        log "导入镜像归档 ${tar_name}"
        docker load -i "${tar_path}" >/dev/null
      fi

      if [[ "${target_tag}" != "${image_tag}" ]]; then
        log "重打标签 ${image_tag} -> ${target_tag}"
        docker tag "${image_tag}" "${target_tag}"
      fi
    fi

    log "推送镜像 ${target_tag}"
    docker push "${target_tag}" >/dev/null
    count=$((count + 1))
  done < <(jq -c '.[]' "${IMAGE_JSON}")

  (( count > 0 )) || die "载荷中未发现可导入的镜像归档"
  success "已准备 ${count} 个镜像归档"
}

ensure_namespace() {
  if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    return 0
  fi
  log "创建命名空间 ${NAMESPACE}"
  kubectl create namespace "${NAMESPACE}" >/dev/null
}


render_optional_block() {
  local feature_name="$1"
  local enabled="$2"

  awk \
    -v start_marker="#__${feature_name}_START__" \
    -v end_marker="#__${feature_name}_END__" \
    -v enabled="${enabled}" '
      {
        marker=$0
        sub(/^[[:space:]]+/, "", marker)
      }
      marker == start_marker { skip=(enabled != "true"); next }
      marker == end_marker { skip=0; next }
      !skip { print }
    '
}


render_feature_blocks() {
  local file_path="$1"
  local backup_nfs_enabled="false"
  local backup_s3_enabled="false"
  local nodeport_enabled="${NODEPORT_ENABLED}"

  if backup_backend_is_nfs; then
    backup_nfs_enabled="true"
  else
    backup_s3_enabled="true"
  fi

  cat "${file_path}" \
    | render_optional_block "FEATURE_MONITORING" "${MONITORING_ENABLED}" \
    | render_optional_block "FEATURE_SERVICE_MONITOR" "${SERVICE_MONITOR_ENABLED}" \
    | render_optional_block "FEATURE_FLUENTBIT" "${FLUENTBIT_ENABLED}" \
    | render_optional_block "FEATURE_NODEPORT" "${nodeport_enabled}" \
    | render_optional_block "BACKUP_NFS" "${backup_nfs_enabled}" \
    | render_optional_block "BACKUP_S3" "${backup_s3_enabled}"
}

render_manifest() {
  local file_path="$1"
  render_feature_blocks "${file_path}" | template_replace
}


apply_mysql_manifests() {
  require_manifest_file "${MYSQL_MANIFEST}"
  render_manifest "${MYSQL_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_backup_manifests() {
  render_manifest "${BACKUP_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_monitoring_addon_manifests() {
  require_manifest_file "${MONITORING_ADDON_MANIFEST}"
  render_manifest "${MONITORING_ADDON_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


cleanup_disabled_optional_resources() {
  if [[ "${BACKUP_ENABLED}" != "true" ]]; then
    delete_backup_resources
  fi

  if [[ "${BACKUP_ENABLED}" == "true" && ! backup_backend_is_s3 ]]; then
    kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "${BACKUP_STORAGE_SECRET}" >/dev/null 2>&1 || true
  fi

  if [[ "${MONITORING_ENABLED}" != "true" ]]; then
    kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${METRICS_SERVICE_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${SERVICE_MONITOR_ENABLED}" != "true" ]] && cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${FLUENTBIT_ENABLED}" != "true" ]]; then
    kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${FLUENTBIT_CONFIGMAP}" >/dev/null 2>&1 || true
  fi
}


extract_payload() {
  section "解压安装载荷"
  local expected_signature signature_file
  expected_signature="$(payload_signature)"
  signature_file="$(payload_signature_file)"

  if payload_cache_ready "${expected_signature}"; then
    success "复用已解压载荷缓存"
    return 0
  fi

  rm -rf "${WORKDIR}"
  mkdir -p "${WORKDIR}" "${IMAGE_DIR}" "${MANIFEST_DIR}"

  log "正在解压元数据到 ${WORKDIR}"
  payload_extract_entries "${WORKDIR}" "./manifests" "./images/image.json" || die "解压载荷元数据失败"

  [[ -f "${IMAGE_JSON}" ]] || die "缺少 image.json"

  printf '%s\n' "${expected_signature}" > "${signature_file}"
  success "载荷元数据解压完成"
}


image_needed_for_current_action() {
  local image_tag="$1"

  case "${ACTION}" in
    install)
      return 0
      ;;
    addon-install)
      if addon_selected monitoring && [[ "${image_tag}" == */mysqld-exporter:* ]]; then
        return 0
      fi
      if addon_selected monitoring && [[ "${image_tag}" == */mysql:* ]]; then
        return 0
      fi
      if addon_selected backup && [[ "${image_tag}" == */mysql:* ]]; then
        return 0
      fi
      if addon_selected backup && backup_plan_any_uses_backend s3 && [[ "${image_tag}" == */minio-mc:* ]]; then
        return 0
      fi
      return 1
      ;;
    backup|restore|verify-backup-restore)
      if [[ "${image_tag}" == */mysql:* ]]; then
        return 0
      fi
      if backup_plan_any_uses_backend s3 && [[ "${image_tag}" == */minio-mc:* ]]; then
        return 0
      fi
      return 1
      ;;
    benchmark)
      if [[ "${image_tag}" == */mysql:* || "${image_tag}" == */sysbench:* ]]; then
        return 0
      fi
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}


template_replace() {
  sed \
    -e "s#__APP_NAME__#${APP_NAME}#g" \
    -e "s#__NAMESPACE__#${NAMESPACE}#g" \
    -e "s#__MYSQL_REPLICAS__#${MYSQL_REPLICAS}#g" \
    -e "s#__STORAGE_CLASS__#${STORAGE_CLASS}#g" \
    -e "s#__STORAGE_SIZE__#${STORAGE_SIZE}#g" \
    -e "s#__MYSQL_ROOT_PASSWORD__#${MYSQL_ROOT_PASSWORD}#g" \
    -e "s#__SERVICE_NAME__#${SERVICE_NAME}#g" \
    -e "s#__STS_NAME__#${STS_NAME}#g" \
    -e "s#__AUTH_SECRET__#${AUTH_SECRET}#g" \
    -e "s#__PROBE_CONFIGMAP__#${PROBE_CONFIGMAP}#g" \
    -e "s#__INIT_CONFIGMAP__#${INIT_CONFIGMAP}#g" \
    -e "s#__MYSQL_CONFIGMAP__#${MYSQL_CONFIGMAP}#g" \
    -e "s#__NODEPORT_SERVICE_NAME__#${NODEPORT_SERVICE_NAME}#g" \
    -e "s#__NODE_PORT__#${NODE_PORT}#g" \
    -e "s#__METRICS_SERVICE_NAME__#${METRICS_SERVICE_NAME}#g" \
    -e "s#__METRICS_PORT__#${METRICS_PORT}#g" \
    -e "s#__SERVICE_MONITOR_NAME__#${SERVICE_MONITOR_NAME}#g" \
    -e "s#__SERVICE_MONITOR_INTERVAL__#${SERVICE_MONITOR_INTERVAL}#g" \
    -e "s#__SERVICE_MONITOR_SCRAPE_TIMEOUT__#${SERVICE_MONITOR_SCRAPE_TIMEOUT}#g" \
    -e "s#__ADDON_EXPORTER_DEPLOYMENT_NAME__#${ADDON_EXPORTER_DEPLOYMENT_NAME}#g" \
    -e "s#__ADDON_EXPORTER_SERVICE_NAME__#${ADDON_EXPORTER_SERVICE_NAME}#g" \
    -e "s#__ADDON_EXPORTER_SECRET__#${ADDON_EXPORTER_SECRET}#g" \
    -e "s#__ADDON_EXPORTER_USERNAME__#${ADDON_EXPORTER_USERNAME}#g" \
    -e "s#__ADDON_EXPORTER_PASSWORD__#${ADDON_EXPORTER_PASSWORD}#g" \
    -e "s#__ADDON_MONITORING_TARGET__#${ADDON_MONITORING_TARGET}#g" \
    -e "s#__ADDON_SERVICE_MONITOR_NAME__#${ADDON_SERVICE_MONITOR_NAME}#g" \
    -e "s#__FLUENTBIT_CONFIGMAP__#${FLUENTBIT_CONFIGMAP}#g" \
    -e "s#__MYSQL_SLOW_QUERY_TIME__#${MYSQL_SLOW_QUERY_TIME}#g" \
    -e "s#__BACKUP_SCRIPT_CONFIGMAP__#${BACKUP_SCRIPT_CONFIGMAP}#g" \
    -e "s#__BACKUP_CRONJOB_NAME__#${BACKUP_CRONJOB_NAME}#g" \
    -e "s#__BACKUP_JOB_NAME__#${BACKUP_JOB_NAME:-mysql-backup-manual}#g" \
    -e "s#__BACKUP_STORAGE_SECRET__#${BACKUP_STORAGE_SECRET}#g" \
    -e "s#__BACKUP_PLAN_NAME__#${BACKUP_PLAN_NAME}#g" \
    -e "s#__BACKUP_STORE_NAME__#${BACKUP_STORE_NAME}#g" \
    -e "s#__BACKUP_NFS_SERVER__#${BACKUP_NFS_SERVER}#g" \
    -e "s#__BACKUP_NFS_PATH__#${BACKUP_NFS_PATH}#g" \
    -e "s#__BACKUP_ROOT_DIR__#${BACKUP_ROOT_DIR}#g" \
    -e "s#__BACKUP_SCHEDULE__#${BACKUP_SCHEDULE}#g" \
    -e "s#__BACKUP_RETENTION__#${BACKUP_RETENTION}#g" \
    -e "s#__BACKUP_DATABASES__#${BACKUP_DATABASES}#g" \
    -e "s#__BACKUP_TABLES__#${BACKUP_TABLES}#g" \
    -e "s#__RESTORE_SNAPSHOT__#${RESTORE_SNAPSHOT}#g" \
    -e "s#__MYSQL_RESTORE_MODE__#${MYSQL_RESTORE_MODE}#g" \
    -e "s#__S3_ENDPOINT__#${S3_ENDPOINT}#g" \
    -e "s#__S3_BUCKET__#${S3_BUCKET}#g" \
    -e "s#__S3_PREFIX__#${S3_PREFIX}#g" \
    -e "s#__S3_ACCESS_KEY__#${S3_ACCESS_KEY}#g" \
    -e "s#__S3_SECRET_KEY__#${S3_SECRET_KEY}#g" \
    -e "s#__S3_INSECURE__#${S3_INSECURE}#g" \
    -e "s#__MYSQL_HOST__#${MYSQL_HOST}#g" \
    -e "s#__MYSQL_PORT__#${MYSQL_PORT}#g" \
    -e "s#__MYSQL_USER__#${MYSQL_USER}#g" \
    -e "s#__MYSQL_AUTH_SECRET__#${MYSQL_AUTH_SECRET}#g" \
    -e "s#__MYSQL_PASSWORD_KEY__#${MYSQL_PASSWORD_KEY}#g" \
    -e "s#__MYSQL_TARGET_NAME__#${MYSQL_TARGET_NAME}#g" \
    -e "s#__MYSQL_IMAGE__#${MYSQL_IMAGE}#g" \
    -e "s#__MYSQL_EXPORTER_IMAGE__#${MYSQL_EXPORTER_IMAGE}#g" \
    -e "s#__FLUENTBIT_IMAGE__#${FLUENTBIT_IMAGE}#g" \
    -e "s#__S3_CLIENT_IMAGE__#${S3_CLIENT_IMAGE}#g" \
    -e "s#__BUSYBOX_IMAGE__#${BUSYBOX_IMAGE}#g" \
    -e "s#__SYSBENCH_IMAGE__#${SYSBENCH_IMAGE}#g" \
    -e "s#__RESTORE_JOB_NAME__#${RESTORE_JOB_NAME:-mysql-restore}#g" \
    -e "s#__BENCHMARK_JOB_NAME__#${BENCHMARK_JOB_NAME:-mysql-benchmark}#g" \
    -e "s#__BENCHMARK_CONCURRENCY__#${BENCHMARK_THREADS}#g" \
    -e "s#__BENCHMARK_THREADS__#${BENCHMARK_THREADS}#g" \
    -e "s#__BENCHMARK_TIME__#${BENCHMARK_TIME}#g" \
    -e "s#__BENCHMARK_WARMUP_TIME__#${BENCHMARK_WARMUP_TIME}#g" \
    -e "s#__BENCHMARK_WARMUP_ROWS__#${BENCHMARK_WARMUP_ROWS}#g" \
    -e "s#__BENCHMARK_TABLES__#${BENCHMARK_TABLES}#g" \
    -e "s#__BENCHMARK_TABLE_SIZE__#${BENCHMARK_TABLE_SIZE}#g" \
    -e "s#__BENCHMARK_DB__#${BENCHMARK_DB}#g" \
    -e "s#__BENCHMARK_RAND_TYPE__#${BENCHMARK_RAND_TYPE}#g" \
    -e "s#__BENCHMARK_KEEP_DATA__#${BENCHMARK_KEEP_DATA}#g" \
    -e "s#__BENCHMARK_PROFILE__#${BENCHMARK_PROFILE}#g" \
    -e "s#__BENCHMARK_HOST__#${BENCHMARK_HOST}#g" \
    -e "s#__BENCHMARK_PORT__#${BENCHMARK_PORT}#g" \
    -e "s#__BENCHMARK_USER__#${BENCHMARK_USER}#g"
}

require_manifest_file() {
  local file_path="$1"
  [[ -f "${file_path}" ]] || die "当前产物包缺少必需 manifest: ${file_path}"
}


apply_backup_support_manifests() {
  require_manifest_file "${BACKUP_SUPPORT_MANIFEST}"
  render_manifest "${BACKUP_SUPPORT_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_backup_schedule_manifests() {
  require_manifest_file "${BACKUP_MANIFEST}"
  render_manifest "${BACKUP_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_restore_job() {
  require_manifest_file "${RESTORE_MANIFEST}"
  render_manifest "${RESTORE_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_benchmark_job() {
  require_manifest_file "${BENCHMARK_MANIFEST}"
  render_manifest "${BENCHMARK_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}

wait_for_statefulset_ready() {
  log "等待 StatefulSet/${STS_NAME} 就绪"
  kubectl rollout status "statefulset/${STS_NAME}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}"
}


mysql_pod_name() {
  echo "${STS_NAME}-0"
}


wait_for_mysql_ready() {
  local pod_name
  pod_name="$(mysql_pod_name)"

  log "等待 Pod/${pod_name} Ready"
  kubectl wait --for=condition=ready "pod/${pod_name}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}" >/dev/null

  log "等待 MySQL 接受连接"
  local retries=60
  local attempt
  for (( attempt=1; attempt<=retries; attempt++ )); do
    if kubectl exec -n "${NAMESPACE}" "${pod_name}" -- env MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysqladmin -uroot ping >/dev/null 2>&1; then
      success "MySQL 已就绪"
      return 0
    fi
    sleep 5
  done

  die "MySQL 在超时时间内未就绪"
}


wait_for_job() {
  local job_name="$1"
  local job_mode="${2:-generic}"
  local timeout_value progress_pid=""

  timeout_value="$(job_wait_timeout "${job_mode}")"

  log "等待 Job/${job_name} 完成"
  if [[ "${job_mode}" == "benchmark" ]]; then
    echo "压测目标                : ${MYSQL_HOST}:${MYSQL_PORT}"
    echo "压测账号                : ${MYSQL_USER}"
    echo "压测 Profile            : ${BENCHMARK_PROFILE}"
    echo "压测并发                : ${BENCHMARK_THREADS}"
    echo "压测时长(秒)            : ${BENCHMARK_TIME}"
    echo "Warmup(秒)              : ${BENCHMARK_WARMUP_TIME}"
    echo "压测表数                : ${BENCHMARK_TABLES}"
    echo "每表数据量              : ${BENCHMARK_TABLE_SIZE}"
    echo "实时日志命令            : kubectl logs -n ${NAMESPACE} -f job/${job_name}"
    echo "状态观察命令            : kubectl get pod -n ${NAMESPACE} -l job-name=${job_name} -w"
    echo "等待超时                : ${timeout_value}"
    follow_benchmark_job "${job_name}" &
    progress_pid=$!
  fi

  if kubectl wait --for=condition=complete "job/${job_name}" -n "${NAMESPACE}" --timeout="${timeout_value}" >/dev/null 2>&1; then
    stop_background_task "${progress_pid}"
    success "Job/${job_name} 已完成"
    return 0
  fi

  stop_background_task "${progress_pid}"
  if job_failed "${job_name}"; then
    warn "Job/${job_name} 执行失败，输出日志如下"
    kubectl logs -n "${NAMESPACE}" "job/${job_name}" --tail=-1 || true
    local pod_name
    pod_name="$(job_pod_name "${job_name}")"
    if [[ -n "${pod_name}" ]]; then
      echo
      kubectl describe pod -n "${NAMESPACE}" "${pod_name}" || true
    fi
    return 1
  fi

  if [[ "${job_mode}" == "benchmark" ]]; then
    warn "压测在等待上限 ${timeout_value} 内未结束，但 Job 仍可能在运行"
    echo "继续查看日志            : kubectl logs -n ${NAMESPACE} -f job/${job_name}"
    echo "继续查看状态            : kubectl get pod -n ${NAMESPACE} -l job-name=${job_name} -w"
    kubectl get job -n "${NAMESPACE}" "${job_name}" || true
    local pod_name
    pod_name="$(job_pod_name "${job_name}")"
    if [[ -n "${pod_name}" ]]; then
      kubectl get pod -n "${NAMESPACE}" "${pod_name}" -o wide || true
    fi
    return 1
  fi

  warn "Job/${job_name} 未正常完成，输出日志如下"
  kubectl logs -n "${NAMESPACE}" "job/${job_name}" --tail=-1 || true
  return 1
}


job_wait_timeout() {
  local job_mode="${1:-generic}"
  local profile_count prepare_buffer cleanup_buffer safety_buffer total_seconds data_points

  if [[ "${job_mode}" != "benchmark" || "${WAIT_TIMEOUT_EXPLICIT}" == "true" ]]; then
    printf '%s' "${WAIT_TIMEOUT}"
    return 0
  fi

  case "${BENCHMARK_PROFILE}" in
    standard)
      profile_count=3
      ;;
    *)
      profile_count=1
      ;;
  esac

  data_points=$((BENCHMARK_TABLES * BENCHMARK_TABLE_SIZE))
  prepare_buffer=$(((data_points + 1499) / 1500))
  if (( prepare_buffer < 120 )); then
    prepare_buffer=120
  fi
  cleanup_buffer=120
  safety_buffer=180
  total_seconds=$((profile_count * (BENCHMARK_TIME + BENCHMARK_WARMUP_TIME) + prepare_buffer + cleanup_buffer + safety_buffer))
  if (( total_seconds < 1800 )); then
    total_seconds=1800
  fi

  printf '%ss' "${total_seconds}"
}

job_failed() {
  local job_name="$1"
  kubectl get job -n "${NAMESPACE}" "${job_name}" -o "jsonpath={range .status.conditions[*]}{.type}={.status}{'\n'}{end}" 2>/dev/null \
    | grep -q '^Failed=True$'
}


job_completed() {
  local job_name="$1"
  kubectl get job -n "${NAMESPACE}" "${job_name}" -o "jsonpath={range .status.conditions[*]}{.type}={.status}{'\n'}{end}" 2>/dev/null \
    | grep -q '^Complete=True$'
}


job_pod_name() {
  local job_name="$1"
  kubectl get pod -n "${NAMESPACE}" -l "job-name=${job_name}" -o "jsonpath={.items[0].metadata.name}" 2>/dev/null || true
}


job_pod_summary() {
  local pod_name="$1"
  kubectl get pod -n "${NAMESPACE}" "${pod_name}" \
    -o "jsonpath={.status.phase}{' | init='}{range .status.initContainerStatuses[*]}{.name}:{.ready}:{.state.waiting.reason}{.state.terminated.reason}{' '}{end}{'| main='}{range .status.containerStatuses[*]}{.name}:{.ready}:{.state.waiting.reason}{.state.terminated.reason}{' '}{end}" 2>/dev/null || true
}


stop_background_task() {
  local task_pid="${1:-}"
  if [[ -n "${task_pid}" ]] && kill -0 "${task_pid}" >/dev/null 2>&1; then
    kill "${task_pid}" >/dev/null 2>&1 || true
    wait "${task_pid}" >/dev/null 2>&1 || true
  fi
}


follow_benchmark_job() {
  local job_name="$1"
  local pod_name="" last_summary="" last_prepare_logs="" last_benchmark_logs=""

  while true; do
    if job_completed "${job_name}" || job_failed "${job_name}"; then
      return 0
    fi

    pod_name="$(job_pod_name "${job_name}")"
    if [[ -n "${pod_name}" ]]; then
      local summary prepare_logs benchmark_logs
      summary="$(job_pod_summary "${pod_name}")"
      if [[ -n "${summary}" && "${summary}" != "${last_summary}" ]]; then
        log "压测 Pod 状态 ${pod_name} ${summary}"
        last_summary="${summary}"
      fi

      prepare_logs="$(kubectl logs -n "${NAMESPACE}" "pod/${pod_name}" -c mysql-prepare --tail=10 2>/dev/null || true)"
      if [[ -n "${prepare_logs}" && "${prepare_logs}" != "${last_prepare_logs}" ]]; then
        echo "${prepare_logs}"
        last_prepare_logs="${prepare_logs}"
      fi

      benchmark_logs="$(kubectl logs -n "${NAMESPACE}" "pod/${pod_name}" -c mysql-benchmark --tail=10 2>/dev/null || true)"
      if [[ -n "${benchmark_logs}" && "${benchmark_logs}" != "${last_benchmark_logs}" ]]; then
        echo "${benchmark_logs}"
        last_benchmark_logs="${benchmark_logs}"
      fi
    fi

    sleep 5
  done
}

ensure_report_dir() {
  mkdir -p "${REPORT_DIR}"
}


write_report() {
  local report_name="$1"
  local body="$2"
  ensure_report_dir
  local report_path="${REPORT_DIR}/${report_name}"
  printf '%s\n' "${body}" > "${report_path}"
  echo "${report_path}"
}


resource_exists() {
  local kind="$1"
  local name="$2"
  kubectl get "${kind}" "${name}" -n "${NAMESPACE}" >/dev/null 2>&1
}


namespace_exists() {
  kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1
}


require_namespace_exists() {
  namespace_exists || die "未找到命名空间 ${NAMESPACE}"
}


statefulset_has_container() {
  local container_name="$1"
  local containers
  containers="$(kubectl get statefulset "${STS_NAME}" -n "${NAMESPACE}" -o jsonpath='{.spec.template.spec.containers[*].name}' 2>/dev/null || true)"
  [[ " ${containers} " == *" ${container_name} "* ]]
}


ensure_statefulset_exists() {
  kubectl get statefulset "${STS_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1 || die "未找到 StatefulSet/${STS_NAME}，请先确认 MySQL 已存在"
}


sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}


ensure_addon_exporter_user() {
  local exporter_user exporter_password
  exporter_user="$(sql_escape "${ADDON_EXPORTER_USERNAME}")"
  exporter_password="$(sql_escape "${ADDON_EXPORTER_PASSWORD}")"

  section "补齐监控账号"
  mysql_exec "CREATE USER IF NOT EXISTS '${exporter_user}'@'%' IDENTIFIED BY '${exporter_password}';"
  mysql_exec "GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO '${exporter_user}'@'%';"
  mysql_exec "FLUSH PRIVILEGES;"
  success "监控账号已就绪"
}


delete_external_monitoring_resources() {
  kubectl delete deployment -n "${NAMESPACE}" --ignore-not-found "${ADDON_EXPORTER_DEPLOYMENT_NAME}" >/dev/null 2>&1 || true
  kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${ADDON_EXPORTER_SERVICE_NAME}" >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "${ADDON_EXPORTER_SECRET}" >/dev/null 2>&1 || true
}


current_mysql_password() {
  if [[ -n "${MYSQL_PASSWORD}" ]]; then
    printf '%s' "${MYSQL_PASSWORD}"
    return 0
  fi

  kubectl get secret -n "${NAMESPACE}" "${MYSQL_AUTH_SECRET}" -o "jsonpath={.data.${MYSQL_PASSWORD_KEY}}" | base64 -d
}


mysql_exec() {
  local sql="$1"
  local password runner_name
  password="$(current_mysql_password)"
  runner_name="mysql-client-$(date +%s)-$RANDOM"

  kubectl run "${runner_name}" \
    -n "${NAMESPACE}" \
    --image="${MYSQL_IMAGE}" \
    --restart=Never \
    --env="MYSQL_PWD=${password}" \
    --env="MYSQL_HOST=${MYSQL_HOST}" \
    --env="MYSQL_PORT=${MYSQL_PORT}" \
    --env="MYSQL_USER=${MYSQL_USER}" \
    --env="SQL_QUERY=${sql}" \
    --command -- /bin/sh -lc \
    'mysql --host="${MYSQL_HOST}" --port="${MYSQL_PORT}" --protocol=TCP --user="${MYSQL_USER}" -Nse "$SQL_QUERY"' >/dev/null

  if ! kubectl wait -n "${NAMESPACE}" --for=jsonpath='{.status.phase}'=Succeeded "pod/${runner_name}" --timeout="${WAIT_TIMEOUT}" >/dev/null 2>&1; then
    kubectl logs -n "${NAMESPACE}" "pod/${runner_name}" --tail=-1 || true
    kubectl delete pod -n "${NAMESPACE}" --ignore-not-found "${runner_name}" >/dev/null 2>&1 || true
    die "临时 MySQL 客户端 Pod/${runner_name} 执行失败"
  fi

  local result
  result="$(kubectl logs -n "${NAMESPACE}" "pod/${runner_name}" --tail=-1 || true)"
  kubectl delete pod -n "${NAMESPACE}" --ignore-not-found "${runner_name}" >/dev/null 2>&1 || true
  printf '%s' "${result}"
}

preflight_mysql_connection() {
  local phase="${1:-预检 MySQL 连接}"

  section "${phase}"
  mysql_exec "SELECT 1;" >/dev/null
  success "MySQL 连接预检通过"
}


monitoring_bootstrap_auth_available() {
  if [[ -n "${MYSQL_PASSWORD}" ]]; then
    return 0
  fi

  secret_has_key "${MYSQL_AUTH_SECRET}" "${MYSQL_PASSWORD_KEY}"
}


uninstall_addons() {
  require_namespace_exists

  if addon_selected service-monitor && cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${ADDON_SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi

  if addon_selected monitoring; then
    section "移除 monitoring addon"
    delete_external_monitoring_resources
    success "monitoring addon 已移除"
  fi

  if addon_selected backup; then
    section "移除 backup addon"
    delete_backup_resources
    success "backup addon 已移除"
  fi
}


show_addon_status() {
  local external_monitoring="未安装"
  local embedded_monitoring="未安装"
  local backup_addon="未安装"
  local embedded_logging="未安装"
  local addon_service_monitor="未安装"
  local embedded_service_monitor="未安装"
  local backup_selector

  require_namespace_exists

  resource_exists deployment "${ADDON_EXPORTER_DEPLOYMENT_NAME}" && external_monitoring="已安装"
  backup_selector="$(backup_resource_selector)"
  kubectl get cronjob -n "${NAMESPACE}" -l "${backup_selector}" -o name 2>/dev/null | grep -q . && backup_addon="已安装"

  if resource_exists statefulset "${STS_NAME}"; then
    statefulset_has_container "mysqld-exporter" && embedded_monitoring="已安装"
    statefulset_has_container "fluent-bit" && embedded_logging="已安装"
  fi

  if cluster_supports_service_monitor; then
    resource_exists servicemonitor "${ADDON_SERVICE_MONITOR_NAME}" && addon_service_monitor="已安装"
    resource_exists servicemonitor "${SERVICE_MONITOR_NAME}" && embedded_service_monitor="已安装"
  else
    addon_service_monitor="集群未安装 CRD"
    embedded_service_monitor="集群未安装 CRD"
  fi

  section "Addon 状态"
  echo "外置 monitoring addon   : ${external_monitoring}"
  echo "内嵌 monitoring sidecar : ${embedded_monitoring}"
  echo "外置 ServiceMonitor     : ${addon_service_monitor}"
  echo "内嵌 ServiceMonitor     : ${embedded_service_monitor}"
  echo "backup addon            : ${backup_addon}"
  echo "Fluent Bit sidecar      : ${embedded_logging}"
  echo
  echo "推荐结论:"
  echo "1. 已有 MySQL 若补监控/备份，优先使用 addon-install，新资源以 Deployment/CronJob 形式补齐。"
  echo "2. 日志推荐接入平台级 DaemonSet 日志体系，不建议默认叠加 sidecar。"
  echo "3. 只有在必须采集容器内 slow log 文件时，才建议走 install --enable-fluentbit。"
}


show_status() {
  section "运行状态"
  kubectl get statefulset -n "${NAMESPACE}" || true
  echo
  kubectl get deployment -n "${NAMESPACE}" || true
  echo
  kubectl get pods -n "${NAMESPACE}" -o wide || true
  echo
  kubectl get svc -n "${NAMESPACE}" || true
  echo
  kubectl get pvc -n "${NAMESPACE}" || true
  echo
  kubectl get cronjob -n "${NAMESPACE}" || true
  echo
  if cluster_supports_service_monitor; then
    kubectl get servicemonitor -n "${NAMESPACE}" || true
    echo
  fi
  kubectl get jobs -n "${NAMESPACE}" || true
}


delete_pvcs_if_requested() {
  [[ "${DELETE_PVC}" == "true" ]] || return 0

  log "删除 StatefulSet/${STS_NAME} 关联 PVC"
  mapfile -t pvcs < <(kubectl get pvc -n "${NAMESPACE}" -o name | grep "^persistentvolumeclaim/data-${STS_NAME}-" || true)
  if [[ ${#pvcs[@]} -eq 0 ]]; then
    return 0
  fi
  kubectl delete -n "${NAMESPACE}" "${pvcs[@]}" >/dev/null || true
}


uninstall_app() {
  extract_payload
  section "卸载 MySQL"

  if ! cluster_supports_service_monitor; then
    SERVICE_MONITOR_ENABLED="false"
  fi

  render_manifest "${MYSQL_MANIFEST}" | kubectl delete -n "${NAMESPACE}" --ignore-not-found -f - >/dev/null || true
  delete_backup_resources
  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found "mysql-restore" >/dev/null 2>&1 || true
  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found "mysql-benchmark" >/dev/null 2>&1 || true
  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found -l job-name >/dev/null 2>&1 || true
  kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${METRICS_SERVICE_NAME}" >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${FLUENTBIT_CONFIGMAP}" >/dev/null 2>&1 || true
  if cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi
  delete_pvcs_if_requested

  success "MySQL 卸载完成"
}


install_app() {
  extract_payload
  prepare_images
  ensure_namespace

  if [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && ! cluster_supports_service_monitor; then
    warn "集群中未安装 ServiceMonitor CRD，本次跳过 ServiceMonitor 资源"
    SERVICE_MONITOR_ENABLED="false"
  fi

  section "安装 / 对齐 MySQL"
  apply_mysql_manifests
  if [[ "${BACKUP_ENABLED}" == "true" ]]; then
    apply_backup_support_manifests_for_all_plans
    apply_backup_schedule_manifests_for_all_plans
  else
    warn "当前关闭了备份组件，将清理 backup CronJob 及支持资源"
  fi
  cleanup_disabled_optional_resources
  wait_for_statefulset_ready
  wait_for_mysql_ready
  success "MySQL 安装/对齐完成"
}


install_addons() {
  extract_payload
  prepare_images
  ensure_namespace

  if addon_selected monitoring; then
    if resource_exists statefulset "${STS_NAME}" && statefulset_has_container "mysqld-exporter"; then
      die "当前 MySQL 已启用内嵌 exporter sidecar，不建议再叠加外置 monitoring addon"
    fi

    if addon_selected service-monitor && ! cluster_supports_service_monitor; then
      warn "集群中未安装 ServiceMonitor CRD，本次仅安装 monitoring addon，跳过 service-monitor"
      ADDONS="${ADDONS//service-monitor/}"
      ADDONS="${ADDONS//,,/,}"
      ADDONS="${ADDONS#,}"
      ADDONS="${ADDONS%,}"
      SERVICE_MONITOR_ENABLED="false"
    fi

    if ! resource_exists statefulset "${STS_NAME}" && [[ "${ADDON_MONITORING_TARGET_EXPLICIT}" != "true" ]]; then
      die "为已有外部 MySQL 安装 monitoring addon 时，请显式提供 --monitoring-target"
    fi

    if monitoring_bootstrap_auth_available; then
      ensure_addon_exporter_user
    else
      warn "未提供可写 MySQL 管理凭据，跳过 exporter 用户自动创建；请确保目标实例已存在 ${ADDON_EXPORTER_USERNAME} 账号"
    fi

    section "安装 monitoring addon"
    apply_monitoring_addon_manifests
    kubectl rollout status "deployment/${ADDON_EXPORTER_DEPLOYMENT_NAME}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}"
    success "monitoring addon 安装完成"
  fi

  if addon_selected backup; then
    if ! resource_exists statefulset "${STS_NAME}" && [[ "${MYSQL_HOST_EXPLICIT}" != "true" ]]; then
      die "为已有外部 MySQL 安装 backup addon 时，请显式提供 --mysql-host"
    fi

    apply_backup_support_manifests_for_all_plans
    preflight_mysql_connection "预检 backup addon 目标连接"

    section "安装 backup addon"
    apply_backup_schedule_manifests_for_all_plans
    success "backup addon 安装完成"
  fi
}

backup_resource_selector() {
  echo "app.kubernetes.io/component=backup"
}


apply_backup_support_manifests_for_all_plans() {
  local spec

  backup_plan_build_catalog
  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    apply_backup_support_manifests
  done
}


apply_backup_schedule_manifests_for_all_plans() {
  local spec

  backup_plan_build_catalog
  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    apply_backup_schedule_manifests
  done
}


create_manual_backup_job() {
  local job_name="${BACKUP_CRONJOB_NAME}-manual-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建手工备份 Job ${job_name} (plan=${BACKUP_PLAN_NAME})" >&2
  BACKUP_JOB_NAME="${job_name}" render_manifest "${BACKUP_JOB_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${job_name}"
}


create_restore_job() {
  local restore_job_name="mysql-restore-${BACKUP_PLAN_NAME}-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建恢复 Job ${restore_job_name} (plan=${BACKUP_PLAN_NAME})" >&2
  RESTORE_JOB_NAME="${restore_job_name}" render_manifest "${RESTORE_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${restore_job_name}"
}


create_benchmark_job() {
  local benchmark_job_name="mysql-benchmark-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建压测 Job ${benchmark_job_name}" >&2
  BENCHMARK_JOB_NAME="${benchmark_job_name}" render_manifest "${BENCHMARK_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${benchmark_job_name}"
}


delete_backup_resources() {
  local selector
  selector="$(backup_resource_selector)"
  kubectl delete cronjob -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete job -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
}


run_backup() {
  local spec job_name
  local completed_jobs=()

  extract_payload
  prepare_images
  ensure_namespace
  preflight_mysql_connection "预检备份目标连接"

  section "执行手工备份"
  backup_plan_build_catalog
  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    apply_backup_support_manifests
    job_name="$(create_manual_backup_job)"
    wait_for_job "${job_name}" || die "备份任务失败，plan=${BACKUP_PLAN_NAME}"
    completed_jobs+=("${BACKUP_PLAN_NAME}:${job_name}")
  done

  success "所有 backup plan 执行完成"
  printf '%s\n' "${completed_jobs[@]}"
}


run_restore() {
  local spec restore_job_name

  extract_payload
  prepare_images
  ensure_namespace
  preflight_mysql_connection "预检恢复目标连接"

  section "执行数据恢复"
  while IFS= read -r spec; do
    [[ -n "${spec}" ]] || continue
    backup_plan_activate_spec "${spec}"

    if [[ "${MYSQL_RESTORE_MODE}" == "wipe-all-user-databases" ]] && ! backup_plan_supports_wipe_restore; then
      if [[ "${BACKUP_RESTORE_SOURCE}" != "auto" ]]; then
        die "restore-source=${BACKUP_PLAN_NAME} 是部分备份，不支持 wipe-all-user-databases；请改用 merge，或选择全量备份来源"
      fi
      warn "restore-source=${BACKUP_PLAN_NAME} 是部分备份，与 wipe-all-user-databases 不兼容，跳过"
      continue
    fi

    apply_backup_support_manifests
    restore_job_name="$(create_restore_job)"
    if wait_for_job "${restore_job_name}"; then
      success "恢复任务完成，source plan=${BACKUP_PLAN_NAME}"
      echo "恢复作业: ${restore_job_name}"
      return 0
    fi
    warn "restore-source=${BACKUP_PLAN_NAME} 恢复失败，继续尝试下一个来源"
  done < <(backup_plan_specs_for_restore)

  die "恢复任务失败，所有 restore-source 均未成功"
}


verify_backup_restore() {
  local snapshot_value changed_value restored_value backup_job restore_job report_path
  local spec
  local backup_jobs=()
  local restore_source_plan=""

  extract_payload
  prepare_images
  ensure_namespace
  preflight_mysql_connection "预检备份/恢复目标连接"

  section "执行备份/恢复闭环校验"

  snapshot_value="snapshot-$(date +%s)"
  changed_value="changed-$(date +%s)"

  log "写入校验数据"
  mysql_exec "CREATE DATABASE IF NOT EXISTS offline_validation;"
  mysql_exec "CREATE TABLE IF NOT EXISTS offline_validation.backup_restore_check (id INT PRIMARY KEY, marker VARCHAR(128) NOT NULL);"
  mysql_exec "REPLACE INTO offline_validation.backup_restore_check (id, marker) VALUES (1, '${snapshot_value}');"

  backup_plan_build_catalog
  for spec in "${BACKUP_PLAN_CATALOG[@]}"; do
    backup_plan_activate_spec "${spec}"
    apply_backup_support_manifests
    backup_job="$(create_manual_backup_job)"
    wait_for_job "${backup_job}" || die "校验用备份任务失败，plan=${BACKUP_PLAN_NAME}"
    backup_jobs+=("${BACKUP_PLAN_NAME}:${backup_job}")
  done

  log "修改数据，准备验证恢复结果"
  mysql_exec "UPDATE offline_validation.backup_restore_check SET marker='${changed_value}' WHERE id=1;"

  restore_job=""
  while IFS= read -r spec; do
    [[ -n "${spec}" ]] || continue
    backup_plan_activate_spec "${spec}"

    if ! backup_plan_supports_verify_marker; then
      if [[ "${BACKUP_RESTORE_SOURCE}" != "auto" ]]; then
        die "restore-source=${BACKUP_PLAN_NAME} 未覆盖 offline_validation.backup_restore_check，无法做闭环校验"
      fi
      warn "restore-source=${BACKUP_PLAN_NAME} 未覆盖 offline_validation 校验表，跳过"
      continue
    fi

    if [[ "${MYSQL_RESTORE_MODE}" == "wipe-all-user-databases" ]] && ! backup_plan_supports_wipe_restore; then
      if [[ "${BACKUP_RESTORE_SOURCE}" != "auto" ]]; then
        die "restore-source=${BACKUP_PLAN_NAME} 是部分备份，不支持 wipe-all-user-databases 闭环校验"
      fi
      warn "restore-source=${BACKUP_PLAN_NAME} 是部分备份，与 wipe-all-user-databases 不兼容，跳过"
      continue
    fi

    apply_backup_support_manifests
    restore_job="$(create_restore_job)"
    if wait_for_job "${restore_job}"; then
      restore_source_plan="${BACKUP_PLAN_NAME}"
      break
    fi
    restore_job=""
    warn "校验恢复在 plan=${BACKUP_PLAN_NAME} 失败，继续尝试下一个来源"
  done < <(backup_plan_specs_for_restore)

  [[ -n "${restore_job}" ]] || die "校验用恢复任务失败"

  restored_value="$(mysql_exec "SELECT marker FROM offline_validation.backup_restore_check WHERE id=1;")"
  [[ "${restored_value}" == "${snapshot_value}" ]] || die "备份/恢复闭环校验失败，期望 ${snapshot_value}，实际 ${restored_value}"

  report_path="$(write_report "backup-restore-${NAMESPACE}-$(date +%Y%m%d%H%M%S).txt" "$(cat <<EOF
mysql backup/restore verification report
generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
namespace=${NAMESPACE}
mysql_target=${MYSQL_TARGET_NAME}
backup_jobs=${backup_jobs[*]}
restore_job=${restore_job}
restore_source=${restore_source_plan:-${BACKUP_RESTORE_SOURCE}}
restore_mode=${MYSQL_RESTORE_MODE}
snapshot_value=${snapshot_value}
restored_value=${restored_value}
status=success
EOF
)")"

  success "备份/恢复闭环校验成功"
  echo "报告文件: ${report_path}"
}

extract_benchmark_report_block() {
  local content="$1"
  local start_marker="$2"
  local end_marker="$3"

  printf '%s\n' "${content}" | awk -v start="${start_marker}" -v end="${end_marker}" '
    $0 == start { in_block=1; next }
    $0 == end { in_block=0; exit }
    in_block { print }
  '
}

run_benchmark() {
  extract_payload
  prepare_images
  ensure_namespace
  preflight_mysql_connection "预检压测目标连接"

  section "执行压测"
  local benchmark_job report_body report_text report_json log_path text_path json_path
  benchmark_job="$(create_benchmark_job)"
  wait_for_job "${benchmark_job}" "benchmark" || die "压测任务失败，请根据上面的 Job/Pod 日志继续排查"

  report_body="$(kubectl logs -n "${NAMESPACE}" "job/${benchmark_job}" --tail=-1)"
  log_path="$(write_report "${benchmark_job}.log" "${report_body}")"
  report_text="$(extract_benchmark_report_block "${report_body}" "__MYSQL_BENCHMARK_REPORT_TEXT_START__" "__MYSQL_BENCHMARK_REPORT_TEXT_END__")"
  report_json="$(extract_benchmark_report_block "${report_body}" "__MYSQL_BENCHMARK_REPORT_JSON_START__" "__MYSQL_BENCHMARK_REPORT_JSON_END__")"

  if [[ -z "${report_text}" ]]; then
    report_text="${report_body}"
  fi

  text_path="$(write_report "${benchmark_job}.txt" "${report_text}")"
  if [[ -n "${report_json}" ]]; then
    json_path="$(write_report "${benchmark_job}.json" "${report_json}")"
  fi

  success "压测完成"
  echo "完整日志: ${log_path}"
  echo "文本报告: ${text_path}"
  [[ -n "${json_path:-}" ]] && echo "JSON 报告: ${json_path}"
}

show_post_install_notes() {
  section "后续建议"

  if [[ "${NODEPORT_ENABLED}" == "true" ]]; then
    cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}
kubectl get pvc -n ${NAMESPACE}
$( [[ "${BACKUP_ENABLED}" == "true" ]] && echo "kubectl get cronjob -n ${NAMESPACE}" )
$( [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && echo "kubectl get servicemonitor -n ${NAMESPACE}" )

集群内访问地址:
${STS_NAME}-0.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:3306

NodePort 访问地址:
<node-ip>:${NODE_PORT}

数据复用关键条件:
1. uninstall 时不要加 --delete-pvc
2. namespace 与 --sts-name 保持不变
3. 再次执行 install 即可按当前开关重新对齐
EOF
    return 0
  fi

  cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}
kubectl get pvc -n ${NAMESPACE}
$( [[ "${BACKUP_ENABLED}" == "true" ]] && echo "kubectl get cronjob -n ${NAMESPACE}" )
$( [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && echo "kubectl get servicemonitor -n ${NAMESPACE}" )

集群内访问地址:
${STS_NAME}-0.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:3306

NodePort 访问:
已关闭

数据复用关键条件:
1. uninstall 时不要加 --delete-pvc
2. namespace 与 --sts-name 保持不变
3. 再次执行 install 即可按当前开关重新对齐
EOF
}

show_post_addon_notes() {
  local backup_line="3. backup addon 会额外创建 CronJob"
  if needs_backup_storage; then
    backup_plan_build_catalog
    backup_line="3. backup addon 会额外创建 ${#BACKUP_PLAN_CATALOG[@]} 个备份计划资源（CronJob/Secret）"
  fi

  section "Addon 后续建议"
  cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get deploy -n ${NAMESPACE}
kubectl get cronjob -n ${NAMESPACE}
$( cluster_supports_service_monitor && echo "kubectl get servicemonitor -n ${NAMESPACE}" )

业务影响说明:
1. addon-install 默认不修改 MySQL StatefulSet
2. monitoring addon 会额外创建 exporter Deployment
${backup_line}
4. 如需日志 sidecar，请改用 install，并提前评估滚动更新窗口
EOF
}


cleanup() {
  :
}


main() {
  trap cleanup EXIT

  parse_args "$@"

  banner
  if [[ "${ACTION}" == "help" ]]; then
    show_help
    exit 0
  fi

  resolve_feature_dependencies
  needs_backup_storage && load_backup_plan_file_if_requested
  prompt_missing_values
  validate_environment
  validate_inputs
  prepare_runtime_auth_secret

  if [[ "${ACTION}" != "status" && "${ACTION}" != "addon-status" ]]; then
    confirm_plan
  fi

  case "${ACTION}" in
    install)
      install_app
      show_post_install_notes
      ;;
    addon-install)
      install_addons
      show_post_addon_notes
      ;;
    addon-uninstall)
      uninstall_addons
      ;;
    addon-status)
      show_addon_status
      ;;
    uninstall)
      uninstall_app
      ;;
    status)
      show_status
      ;;
    backup)
      run_backup
      ;;
    restore)
      run_restore
      ;;
    verify-backup-restore)
      verify_backup_restore
      ;;
    benchmark)
      run_benchmark
      ;;
    *)
      die "不支持的动作: ${ACTION}"
      ;;
  esac
}

main "$@"

exit 0

__PAYLOAD_BELOW__

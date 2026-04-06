#!/usr/bin/env bash

# Generated source layout:
# - edit scripts/install/modules/*.sh
# - regenerate install.sh via scripts/assemble-install.sh

set -Eeuo pipefail

APP_NAME="mysql"
APP_VERSION="1.5.3"
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
}


backup_backend_is_nfs() {
  [[ "${BACKUP_BACKEND}" == "nfs" ]]
}


backup_backend_is_s3() {
  [[ "${BACKUP_BACKEND}" == "s3" ]]
}




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
  case "${ACTION}" in
    addon-install|addon-uninstall)
      [[ -n "${ADDONS}" ]] || die "动作 ${ACTION} 需要提供 --addons"
      ;;
  esac
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
  if needs_backup_storage && backup_backend_is_nfs && [[ -z "${BACKUP_NFS_SERVER}" ]]; then
    echo -ne "${YELLOW}请输入 NFS 服务器地址:${NC} "
    read -r BACKUP_NFS_SERVER
  fi

  if needs_backup_storage && backup_backend_is_s3; then
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

  [[ -n "${BACKUP_NFS_PATH}" ]] || BACKUP_NFS_PATH="/data/nfs-share"
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
  [[ "${BACKUP_BACKEND}" == "nfs" || "${BACKUP_BACKEND}" == "s3" ]] || die "备份后端仅支持 nfs 或 s3"
  [[ "${MYSQL_RESTORE_MODE}" =~ ^(merge|wipe-all-user-databases)$ ]] || die "restore-mode 仅支持 merge 或 wipe-all-user-databases"
  [[ "${BENCHMARK_PROFILE}" =~ ^(standard|oltp-point-select|oltp-read-only|oltp-read-write)$ ]] || die "benchmark-profile 仅支持 standard、oltp-point-select、oltp-read-only、oltp-read-write"

  if needs_backup_storage && backup_backend_is_nfs && [[ -z "${BACKUP_NFS_SERVER}" ]]; then
    die "使用 NFS 备份时必须提供 --backup-nfs-server"
  fi

  if needs_backup_storage && backup_backend_is_s3; then
    [[ -n "${S3_ENDPOINT}" ]] || die "使用 S3 备份时必须提供 --s3-endpoint"
    [[ -n "${S3_BUCKET}" ]] || die "使用 S3 备份时必须提供 --s3-bucket"
    [[ -n "${S3_ACCESS_KEY}" ]] || die "使用 S3 备份时必须提供 --s3-access-key"
    [[ -n "${S3_SECRET_KEY}" ]] || die "使用 S3 备份时必须提供 --s3-secret-key"
  fi

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
    echo "备份根目录              : ${BACKUP_ROOT_DIR}"
    if backup_schedule_required; then
      echo "备份计划                : ${BACKUP_SCHEDULE}"
    fi
    if backup_backend_is_nfs; then
      echo "NFS 服务地址            : ${BACKUP_NFS_SERVER}"
      echo "NFS 导出路径            : ${BACKUP_NFS_PATH}"
    else
      echo "S3 Endpoint             : ${S3_ENDPOINT}"
      echo "S3 Bucket               : ${S3_BUCKET}"
      echo "S3 Prefix               : ${S3_PREFIX:-<空>}"
      echo "S3 Insecure             : ${S3_INSECURE}"
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
    [[ -f "${tar_path}" ]] || continue

    log "导入镜像归档 ${tar_name}"
    docker load -i "${tar_path}" >/dev/null
    if [[ "${target_tag}" != "${image_tag}" ]]; then
      log "重打标签 ${image_tag} -> ${target_tag}"
      docker tag "${image_tag}" "${target_tag}"
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
  render_manifest "${MYSQL_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_backup_manifests() {
  render_manifest "${BACKUP_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_monitoring_addon_manifests() {
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
  rm -rf "${WORKDIR}"
  mkdir -p "${WORKDIR}" "${IMAGE_DIR}" "${MANIFEST_DIR}"

  local payload_line
  payload_line="$(awk '/^__PAYLOAD_BELOW__$/ { print NR + 1; exit }' "$0")"
  [[ -n "${payload_line}" ]] || die "未找到载荷标记"

  log "正在解压到 ${WORKDIR}"
  tail -n +"${payload_line}" "$0" | tar -xz -C "${WORKDIR}" >/dev/null 2>&1 || die "解压载荷失败"

  [[ -f "${MYSQL_MANIFEST}" ]] || die "缺少 MySQL manifest"
  [[ -f "${BACKUP_MANIFEST}" ]] || die "缺少 backup cronjob manifest"
  [[ -f "${BACKUP_SUPPORT_MANIFEST}" ]] || die "缺少 backup support manifest"
  [[ -f "${BACKUP_JOB_MANIFEST}" ]] || die "缺少 backup job manifest"
  [[ -f "${RESTORE_MANIFEST}" ]] || die "缺少 restore manifest"
  [[ -f "${BENCHMARK_MANIFEST}" ]] || die "缺少 benchmark manifest"
  [[ -f "${MONITORING_ADDON_MANIFEST}" ]] || die "缺少 monitoring addon manifest"
  [[ -f "${IMAGE_JSON}" ]] || die "缺少 image.json"
  success "载荷解压完成"
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
      if addon_selected backup && [[ "${image_tag}" == */mysql:* ]]; then
        return 0
      fi
      if addon_selected backup && backup_backend_is_s3 && [[ "${image_tag}" == */minio-mc:* ]]; then
        return 0
      fi
      return 1
      ;;
    backup|restore|verify-backup-restore)
      if [[ "${image_tag}" == */mysql:* ]]; then
        return 0
      fi
      if backup_backend_is_s3 && [[ "${image_tag}" == */minio-mc:* ]]; then
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
    -e "s#__BACKUP_NFS_SERVER__#${BACKUP_NFS_SERVER}#g" \
    -e "s#__BACKUP_NFS_PATH__#${BACKUP_NFS_PATH}#g" \
    -e "s#__BACKUP_ROOT_DIR__#${BACKUP_ROOT_DIR}#g" \
    -e "s#__BACKUP_SCHEDULE__#${BACKUP_SCHEDULE}#g" \
    -e "s#__BACKUP_RETENTION__#${BACKUP_RETENTION}#g" \
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

apply_backup_support_manifests() {
  render_manifest "${BACKUP_SUPPORT_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_backup_schedule_manifests() {
  render_manifest "${BACKUP_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_restore_job() {
  render_manifest "${RESTORE_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_benchmark_job() {
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

  require_namespace_exists

  resource_exists deployment "${ADDON_EXPORTER_DEPLOYMENT_NAME}" && external_monitoring="已安装"
  resource_exists cronjob "${BACKUP_CRONJOB_NAME}" && backup_addon="已安装"

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
    apply_backup_support_manifests
    apply_backup_schedule_manifests
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

    apply_backup_support_manifests
    preflight_mysql_connection "预检 backup addon 目标连接"

    section "安装 backup addon"
    apply_backup_schedule_manifests
    success "backup addon 安装完成"
  fi
}



create_manual_backup_job() {
  local job_name="${BACKUP_CRONJOB_NAME}-manual-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建手工备份 Job ${job_name}" >&2
  BACKUP_JOB_NAME="${job_name}" render_manifest "${BACKUP_JOB_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${job_name}"
}


create_restore_job() {
  local restore_job_name="mysql-restore-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建恢复 Job ${restore_job_name}" >&2
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
  kubectl delete cronjob -n "${NAMESPACE}" --ignore-not-found "${BACKUP_CRONJOB_NAME}" >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${BACKUP_SCRIPT_CONFIGMAP}" >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "${BACKUP_STORAGE_SECRET}" >/dev/null 2>&1 || true
}


run_backup() {
  extract_payload
  prepare_images
  ensure_namespace
  apply_backup_support_manifests
  preflight_mysql_connection "预检备份目标连接"

  section "执行手工备份"
  local job_name
  job_name="$(create_manual_backup_job)"
  wait_for_job "${job_name}" || die "备份任务失败"
}

run_restore() {
  extract_payload
  prepare_images
  ensure_namespace
  apply_backup_support_manifests
  preflight_mysql_connection "预检恢复目标连接"

  section "执行数据恢复"
  local restore_job_name
  restore_job_name="$(create_restore_job)"
  wait_for_job "${restore_job_name}" || die "恢复任务失败"
}

verify_backup_restore() {
  extract_payload
  prepare_images
  ensure_namespace
  apply_backup_support_manifests
  preflight_mysql_connection "预检备份/恢复目标连接"

  section "执行备份/恢复闭环校验"

  local snapshot_value changed_value restored_value backup_job restore_job report_path
  snapshot_value="snapshot-$(date +%s)"
  changed_value="changed-$(date +%s)"

  log "写入校验数据"
  mysql_exec "CREATE DATABASE IF NOT EXISTS offline_validation;"
  mysql_exec "CREATE TABLE IF NOT EXISTS offline_validation.backup_restore_check (id INT PRIMARY KEY, marker VARCHAR(128) NOT NULL);"
  mysql_exec "REPLACE INTO offline_validation.backup_restore_check (id, marker) VALUES (1, '${snapshot_value}');"

  backup_job="$(create_manual_backup_job)"
  wait_for_job "${backup_job}" || die "校验用备份任务失败"

  log "修改数据，准备验证恢复结果"
  mysql_exec "UPDATE offline_validation.backup_restore_check SET marker='${changed_value}' WHERE id=1;"

  restore_job="$(create_restore_job)"
  wait_for_job "${restore_job}" || die "校验用恢复任务失败"

  restored_value="$(mysql_exec "SELECT marker FROM offline_validation.backup_restore_check WHERE id=1;")"
  [[ "${restored_value}" == "${snapshot_value}" ]] || die "备份/恢复闭环校验失败，期望 ${snapshot_value}，实际 ${restored_value}"

  report_path="$(write_report "backup-restore-${NAMESPACE}-$(date +%Y%m%d%H%M%S).txt" "$(cat <<EOF
mysql backup/restore verification report
generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
namespace=${NAMESPACE}
mysql_target=${MYSQL_TARGET_NAME}
backup_job=${backup_job}
restore_job=${restore_job}
backup_backend=${BACKUP_BACKEND}
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
  section "Addon 后续建议"
  cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get deploy -n ${NAMESPACE}
kubectl get cronjob -n ${NAMESPACE}
$( cluster_supports_service_monitor && echo "kubectl get servicemonitor -n ${NAMESPACE}" )

业务影响说明:
1. addon-install 默认不修改 MySQL StatefulSet
2. monitoring addon 会额外创建 exporter Deployment
3. backup addon 会额外创建 CronJob
4. 如需日志 sidecar，请改用 install，并提前评估滚动更新窗口
EOF
}


cleanup() {
  rm -rf "${WORKDIR}" >/dev/null 2>&1 || true
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




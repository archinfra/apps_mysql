#!/usr/bin/env bash

# Generated source layout:
# - edit scripts/install/modules/*.sh
# - regenerate install.sh via scripts/assemble-install.sh

set -Eeuo pipefail

APP_NAME="mysql"
APP_VERSION="1.5.13"
PACKAGE_PROFILE="${PACKAGE_PROFILE:-integrated}"
WORKDIR="/tmp/${APP_NAME}-installer"
IMAGE_DIR="${WORKDIR}/images"
MANIFEST_DIR="${WORKDIR}/manifests"

IMAGE_JSON="${IMAGE_DIR}/image.json"
IMAGE_INDEX="${IMAGE_DIR}/image-index.tsv"
MYSQL_MANIFEST="${MANIFEST_DIR}/innodb-mysql.yaml"
BENCHMARK_MANIFEST="${MANIFEST_DIR}/mysql-benchmark-job.yaml"
MONITORING_ADDON_MANIFEST="${MANIFEST_DIR}/mysql-addon-monitoring.yaml"

REGISTRY_ADDR="${REGISTRY_ADDR:-sealos.hub:5000}"
REGISTRY_USER="${REGISTRY_USER:-admin}"
REGISTRY_PASS="${REGISTRY_PASS:-passw0rd}"
REGISTRY_REPO="${REGISTRY_REPO:-${REGISTRY_ADDR}/kube4}"
MYSQL_IMAGE="${MYSQL_IMAGE:-${REGISTRY_REPO}/mysql:8.0.45}"
MYSQL_EXPORTER_IMAGE="${MYSQL_EXPORTER_IMAGE:-${REGISTRY_REPO}/mysqld-exporter:v0.15.1}"
FLUENTBIT_IMAGE="${FLUENTBIT_IMAGE:-${REGISTRY_REPO}/fluent-bit:3.0.7}"
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
RESOURCE_PROFILE="mid"
SERVICE_NAME="mysql"
STS_NAME="mysql"
AUTH_SECRET="mysql-auth"
MYSQL_HOST=""
MYSQL_PORT="3306"
MYSQL_USER="root"
MYSQL_PASSWORD=""
MYSQL_AUTH_SECRET=""
MYSQL_PASSWORD_KEY=""
MYSQL_RUNTIME_SECRET="mysql-runtime-auth"
MYSQL_ROOT_PASSWORD_EXPLICIT="false"
MYSQL_PASSWORD_EXPLICIT="false"
MYSQL_AUTH_SECRET_EXPLICIT="false"
MYSQL_PASSWORD_KEY_EXPLICIT="false"
MYSQL_HOST_EXPLICIT="false"
PROBE_CONFIGMAP="mysql-probes"
INIT_CONFIGMAP="mysql-init-users"
MYSQL_CONFIGMAP="mysql-config"
NODEPORT_SERVICE_NAME="mysql-nodeport"
NODE_PORT="30306"
NODEPORT_ENABLED="true"
MONITORING_ENABLED="true"
SERVICE_MONITOR_ENABLED="true"
PROMETHEUS_RULE_ENABLED="true"
FLUENTBIT_ENABLED="false"
METRICS_SERVICE_NAME="mysql-metrics"
METRICS_PORT="9104"
SERVICE_MONITOR_NAME="mysql-monitor"
PROMETHEUS_RULE_NAME="mysql-alerts"
GRAFANA_DASHBOARD_NAME="mysql-dashboard"
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
ADDON_PROMETHEUS_RULE_NAME="mysql-exporter-alerts"
ADDON_GRAFANA_DASHBOARD_NAME="mysql-exporter-dashboard"
FLUENTBIT_CONFIGMAP="mysql-fluent-bit"
MYSQL_SLOW_QUERY_TIME="2"
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

MYSQL_REQUEST_CPU="${MYSQL_REQUEST_CPU:-500m}"
MYSQL_REQUEST_MEM="${MYSQL_REQUEST_MEM:-1Gi}"
MYSQL_LIMIT_CPU="${MYSQL_LIMIT_CPU:-1}"
MYSQL_LIMIT_MEM="${MYSQL_LIMIT_MEM:-2Gi}"
MYSQL_EXPORTER_REQUEST_CPU="${MYSQL_EXPORTER_REQUEST_CPU:-100m}"
MYSQL_EXPORTER_REQUEST_MEM="${MYSQL_EXPORTER_REQUEST_MEM:-128Mi}"
MYSQL_EXPORTER_LIMIT_CPU="${MYSQL_EXPORTER_LIMIT_CPU:-200m}"
MYSQL_EXPORTER_LIMIT_MEM="${MYSQL_EXPORTER_LIMIT_MEM:-256Mi}"
FLUENTBIT_REQUEST_CPU="${FLUENTBIT_REQUEST_CPU:-100m}"
FLUENTBIT_REQUEST_MEM="${FLUENTBIT_REQUEST_MEM:-128Mi}"
FLUENTBIT_LIMIT_CPU="${FLUENTBIT_LIMIT_CPU:-200m}"
FLUENTBIT_LIMIT_MEM="${FLUENTBIT_LIMIT_MEM:-256Mi}"
MYSQL_INIT_REQUEST_CPU="${MYSQL_INIT_REQUEST_CPU:-50m}"
MYSQL_INIT_REQUEST_MEM="${MYSQL_INIT_REQUEST_MEM:-64Mi}"
MYSQL_INIT_LIMIT_CPU="${MYSQL_INIT_LIMIT_CPU:-200m}"
MYSQL_INIT_LIMIT_MEM="${MYSQL_INIT_LIMIT_MEM:-128Mi}"

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


trim_string() {
  local value="${1:-}"
  echo "${value}" | awk '{$1=$1; print}'
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
  1. apps_mysql 现在只负责 MySQL 安装、监控和压测。
  2. 备份恢复已迁移到独立数据保护系统，不再由本安装器提供。
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
  --mysql-slow-query-time <seconds> 默认: 2
  --registry <repo-prefix>          例如: harbor.example.com/kube4
  --wait-timeout <duration>         默认: 10m

说明:
  1. install 会对 StatefulSet 与相关资源做声明式对齐，配置变化可能触发滚动更新。
  2. 如果只是给已有 MySQL 补监控，优先使用 addon-install。
  3. 备份恢复已经拆到独立系统，不再通过 install 开关控制。

示例:
  ${cmd} install \
    --namespace mysql-demo \
    --root-password 'StrongPassw0rd' \
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
  --resource-profile <name>
  --mysql-slow-query-time <seconds>

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

package_profile_label() {
  case "${PACKAGE_PROFILE}" in
    integrated)
      echo "integrated"
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
      case "${action_name}" in
        install|uninstall|status|addon-install|addon-uninstall|addon-status|benchmark|help)
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
    integrated|monitoring)
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
      echo "install uninstall status addon-install addon-uninstall addon-status benchmark help"
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
      install|uninstall|status|addon-install|addon-uninstall|addon-status|benchmark)
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
      --resource-profile)
        RESOURCE_PROFILE="$2"
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
      --mysql-slow-query-time)
        MYSQL_SLOW_QUERY_TIME="$2"
        shift 2
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
        MYSQL_HOST="$2"
        MYSQL_HOST_EXPLICIT="true"
        shift 2
        ;;
      --benchmark-port)
        MYSQL_PORT="$2"
        shift 2
        ;;
      --benchmark-user)
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
  local item trimmed current exists

  [[ -n "${raw}" ]] || die "动作 ${ACTION} 需要提供 --addons，例如 --addons monitoring,service-monitor"

  if [[ "${raw}" == "all" ]]; then
    raw="monitoring,service-monitor"
  fi

  IFS=',' read -r -a items <<<"${raw}"
  for item in "${items[@]}"; do
    trimmed="$(trim_string "${item}")"
    [[ -n "${trimmed}" ]] || continue

    case "${trimmed}" in
      monitoring|service-monitor)
        exists="false"
        for current in "${normalized[@]}"; do
          if [[ "${current}" == "${trimmed}" ]]; then
            exists="true"
            break
          fi
        done
        [[ "${exists}" == "true" ]] || normalized+=("${trimmed}")
        ;;
      *)
        die "不支持的 addon: ${trimmed}，当前仅支持 monitoring, service-monitor"
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


action_needs_image_prepare() {
  case "${ACTION}" in
    install|addon-install|benchmark)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}


action_needs_mysql_auth() {
  [[ "${ACTION}" == "benchmark" ]]
}


resolve_mysql_runtime_defaults() {
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

  if [[ -z "${ADDON_MONITORING_TARGET}" ]]; then
    ADDON_MONITORING_TARGET="${MYSQL_HOST}:${MYSQL_PORT}"
  fi

  if [[ "${BENCHMARK_TIME}" == "180" && "${BENCHMARK_ITERATIONS}" != "3" ]]; then
    BENCHMARK_TIME="$((BENCHMARK_ITERATIONS * 60))"
  fi
}


cluster_supports_service_monitor() {
  kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1
}


cluster_supports_prometheus_rule() {
  kubectl get crd prometheusrules.monitoring.coreos.com >/dev/null 2>&1
}


resolve_feature_dependencies() {
  resolve_mysql_runtime_defaults

  if [[ "${MONITORING_ENABLED}" != "true" && "${SERVICE_MONITOR_ENABLED}" == "true" ]]; then
    warn "monitoring 已关闭，因此自动关闭 ServiceMonitor"
    SERVICE_MONITOR_ENABLED="false"
  fi

  if [[ "${MONITORING_ENABLED}" != "true" && "${PROMETHEUS_RULE_ENABLED}" == "true" ]]; then
    PROMETHEUS_RULE_ENABLED="false"
  fi

  if [[ "${ACTION}" == "addon-install" || "${ACTION}" == "addon-uninstall" ]]; then
    normalize_addons
    SERVICE_MONITOR_ENABLED="false"
    PROMETHEUS_RULE_ENABLED="false"

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

    if addon_selected monitoring; then
      PROMETHEUS_RULE_ENABLED="true"
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

secret_has_key() {
  local secret_name="$1"
  local key_name="$2"
  kubectl get secret -n "${NAMESPACE}" "${secret_name}" -o "jsonpath={.data.${key_name}}" >/dev/null 2>&1
}


runtime_action_requires_explicit_mysql_auth() {
  [[ "${ACTION}" == "benchmark" ]]
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
    die "当前动作要求显式提供可用的 MySQL 凭据，请传 --mysql-password，或提供已存在的 --mysql-auth-secret/--mysql-password-key"
  fi

  if [[ "${MYSQL_ROOT_PASSWORD_EXPLICIT}" == "true" && "${MYSQL_AUTH_SECRET}" == "${AUTH_SECRET}" && "${MYSQL_PASSWORD_KEY}" == "mysql-root-password" ]]; then
    warn "未找到 Secret/${MYSQL_AUTH_SECRET}，将使用显式传入的 --root-password 创建"
    kubectl create secret generic "${MYSQL_AUTH_SECRET}" \
      -n "${NAMESPACE}" \
      --from-literal="${MYSQL_PASSWORD_KEY}=${MYSQL_ROOT_PASSWORD}" \
      --dry-run=client -o yaml | kubectl apply -f - >/dev/null
    return 0
  fi

  die "命名空间 ${NAMESPACE} 中未找到 Secret/${MYSQL_AUTH_SECRET} 的键 ${MYSQL_PASSWORD_KEY}，请显式传 --mysql-password，或指定正确的 --mysql-auth-secret/--mysql-password-key"
}


prompt_missing_values() {
  :
}


apply_resource_profile() {
  case "${RESOURCE_PROFILE,,}" in
    low)
      RESOURCE_PROFILE="low"
      MYSQL_REQUEST_CPU="200m"
      MYSQL_REQUEST_MEM="512Mi"
      MYSQL_LIMIT_CPU="500m"
      MYSQL_LIMIT_MEM="1Gi"
      MYSQL_EXPORTER_REQUEST_CPU="50m"
      MYSQL_EXPORTER_REQUEST_MEM="64Mi"
      MYSQL_EXPORTER_LIMIT_CPU="100m"
      MYSQL_EXPORTER_LIMIT_MEM="128Mi"
      FLUENTBIT_REQUEST_CPU="50m"
      FLUENTBIT_REQUEST_MEM="64Mi"
      FLUENTBIT_LIMIT_CPU="100m"
      FLUENTBIT_LIMIT_MEM="128Mi"
      MYSQL_INIT_REQUEST_CPU="20m"
      MYSQL_INIT_REQUEST_MEM="32Mi"
      MYSQL_INIT_LIMIT_CPU="100m"
      MYSQL_INIT_LIMIT_MEM="64Mi"
      ;;
    mid|midd|middle|medium)
      RESOURCE_PROFILE="mid"
      MYSQL_REQUEST_CPU="500m"
      MYSQL_REQUEST_MEM="1Gi"
      MYSQL_LIMIT_CPU="1"
      MYSQL_LIMIT_MEM="2Gi"
      MYSQL_EXPORTER_REQUEST_CPU="100m"
      MYSQL_EXPORTER_REQUEST_MEM="128Mi"
      MYSQL_EXPORTER_LIMIT_CPU="200m"
      MYSQL_EXPORTER_LIMIT_MEM="256Mi"
      FLUENTBIT_REQUEST_CPU="100m"
      FLUENTBIT_REQUEST_MEM="128Mi"
      FLUENTBIT_LIMIT_CPU="200m"
      FLUENTBIT_LIMIT_MEM="256Mi"
      MYSQL_INIT_REQUEST_CPU="50m"
      MYSQL_INIT_REQUEST_MEM="64Mi"
      MYSQL_INIT_LIMIT_CPU="200m"
      MYSQL_INIT_LIMIT_MEM="128Mi"
      ;;
    high)
      RESOURCE_PROFILE="high"
      MYSQL_REQUEST_CPU="1"
      MYSQL_REQUEST_MEM="2Gi"
      MYSQL_LIMIT_CPU="2"
      MYSQL_LIMIT_MEM="4Gi"
      MYSQL_EXPORTER_REQUEST_CPU="200m"
      MYSQL_EXPORTER_REQUEST_MEM="256Mi"
      MYSQL_EXPORTER_LIMIT_CPU="500m"
      MYSQL_EXPORTER_LIMIT_MEM="512Mi"
      FLUENTBIT_REQUEST_CPU="200m"
      FLUENTBIT_REQUEST_MEM="256Mi"
      FLUENTBIT_LIMIT_CPU="500m"
      FLUENTBIT_LIMIT_MEM="512Mi"
      MYSQL_INIT_REQUEST_CPU="100m"
      MYSQL_INIT_REQUEST_MEM="128Mi"
      MYSQL_INIT_LIMIT_CPU="300m"
      MYSQL_INIT_LIMIT_MEM="256Mi"
      ;;
    *)
      die "resource-profile 仅支持 low|mid|midd|high"
      ;;
  esac
}


validate_environment() {
  command -v kubectl >/dev/null 2>&1 || die "未找到 kubectl"

  if action_needs_image_prepare && [[ "${SKIP_IMAGE_PREPARE}" != "true" ]]; then
    command -v docker >/dev/null 2>&1 || die "未找到 docker"
  fi
}


validate_inputs() {
  apply_resource_profile

  [[ "${NODEPORT_ENABLED}" =~ ^(true|false)$ ]] || die "--nodeport-enabled 仅支持 true 或 false"

  if [[ "${ACTION}" != "addon-status" ]]; then
    [[ "${MYSQL_REPLICAS}" =~ ^[0-9]+$ ]] || die "mysql 副本数必须是数字"
    if [[ "${NODEPORT_ENABLED}" == "true" ]]; then
      [[ "${NODE_PORT}" =~ ^[0-9]+$ ]] || die "nodePort 必须是数字"
      (( NODE_PORT >= 30000 && NODE_PORT <= 32767 )) || die "nodePort 必须在 30000-32767 之间"
    fi
  fi

  [[ "${MYSQL_PORT}" =~ ^[0-9]+$ ]] || die "MySQL 端口必须是数字"
  [[ "${BENCHMARK_THREADS}" =~ ^[0-9]+$ ]] || die "压测线程数必须是数字"
  [[ "${BENCHMARK_TIME}" =~ ^[0-9]+$ ]] || die "压测时长必须是数字"
  [[ "${BENCHMARK_WARMUP_TIME}" =~ ^[0-9]+$ ]] || die "压测 warmup 时长必须是数字"
  [[ "${BENCHMARK_WARMUP_ROWS}" =~ ^[0-9]+$ ]] || die "压测 warmup 数据量必须是数字"
  [[ "${BENCHMARK_TABLES}" =~ ^[0-9]+$ ]] || die "压测表数必须是数字"
  [[ "${BENCHMARK_TABLE_SIZE}" =~ ^[0-9]+$ ]] || die "压测单表数据量必须是数字"
  [[ "${MYSQL_SLOW_QUERY_TIME}" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "慢查询阈值必须是数字"
  [[ "${BENCHMARK_PROFILE}" =~ ^(standard|oltp-point-select|oltp-read-only|oltp-read-write)$ ]] || die "benchmark-profile 仅支持 standard、oltp-point-select、oltp-read-only、oltp-read-write"

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
      echo "Resource profile        : ${RESOURCE_PROFILE}"
      echo "存储大小                : ${STORAGE_SIZE}"
      echo "镜像前缀                : ${REGISTRY_REPO}"
      echo "监控 exporter           : ${MONITORING_ENABLED}"
      echo "ServiceMonitor          : ${SERVICE_MONITOR_ENABLED}"
      echo "Fluent Bit sidecar      : ${FLUENTBIT_ENABLED}"
      echo "慢日志阈值(秒)           : ${MYSQL_SLOW_QUERY_TIME}"
      echo "业务影响                : install 会整体对齐 StatefulSet，配置变化时可能触发滚动更新"
      ;;
    addon-install|addon-uninstall)
      echo "Addon 列表              : ${ADDONS}"
      echo "业务影响                : 默认只新增或删除外置资源，不修改 MySQL StatefulSet"
      if addon_selected monitoring; then
        echo "监控目标                : ${ADDON_MONITORING_TARGET}"
        echo "监控账号                : ${ADDON_EXPORTER_USERNAME}"
        echo "建账认证来源            : $(mysql_auth_source_summary)"
      fi
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
      echo "Warmup 数据量/表        : ${BENCHMARK_WARMUP_ROWS}"
      echo "压测表数                : ${BENCHMARK_TABLES}"
      echo "正式数据量/表           : ${BENCHMARK_TABLE_SIZE}"
      echo "压测数据库              : ${BENCHMARK_DB}"
      echo "随机分布                : ${BENCHMARK_RAND_TYPE}"
      echo "保留测试数据            : ${BENCHMARK_KEEP_DATA}"
      echo "报告目录                : ${REPORT_DIR}"
      echo "自动等待超时            : $(job_wait_timeout benchmark)"
      ;;
  esac
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
  [[ -f "${IMAGE_INDEX}" ]] || return 1
}


ensure_image_archive_available() {
  local tar_name="$1"
  local tar_path="${IMAGE_DIR}/${tar_name}"

  if [[ -f "${tar_path}" ]]; then
    return 0
  fi

  log "按需解压镜像归档 ${tar_name}"
  payload_extract_entries "${WORKDIR}" "./images/${tar_name}" || die "解压镜像归档失败: ${tar_name}"
  [[ -f "${tar_path}" ]] || die "解压后仍未找到镜像归档 ${tar_name}"
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
  while IFS=$'\t' read -r tar_name image_tag; do
    [[ -n "${tar_name}" ]] || continue
    [[ -n "${image_tag}" ]] || continue

    local target_tag tar_path
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
  done < "${IMAGE_INDEX}"

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
  local nodeport_enabled="${NODEPORT_ENABLED}"
  local stdout_logging_enabled="false"

  if [[ "${FLUENTBIT_ENABLED}" != "true" ]]; then
    stdout_logging_enabled="true"
  fi

  cat "${file_path}" \
    | render_optional_block "FEATURE_MONITORING" "${MONITORING_ENABLED}" \
    | render_optional_block "FEATURE_SERVICE_MONITOR" "${SERVICE_MONITOR_ENABLED}" \
    | render_optional_block "FEATURE_PROMETHEUS_RULE" "${PROMETHEUS_RULE_ENABLED}" \
    | render_optional_block "FEATURE_FLUENTBIT" "${FLUENTBIT_ENABLED}" \
    | render_optional_block "FEATURE_STDOUT_LOGGING" "${stdout_logging_enabled}" \
    | render_optional_block "FEATURE_NODEPORT" "${nodeport_enabled}"
}


render_manifest() {
  local file_path="$1"
  render_feature_blocks "${file_path}" | template_replace
}


apply_mysql_manifests() {
  require_manifest_file "${MYSQL_MANIFEST}"
  render_manifest "${MYSQL_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


apply_monitoring_addon_manifests() {
  require_manifest_file "${MONITORING_ADDON_MANIFEST}"
  render_manifest "${MONITORING_ADDON_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}


cleanup_disabled_optional_resources() {
  if [[ "${MONITORING_ENABLED}" != "true" ]]; then
    kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${METRICS_SERVICE_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${SERVICE_MONITOR_ENABLED}" != "true" ]] && cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${PROMETHEUS_RULE_ENABLED}" != "true" ]] && cluster_supports_prometheus_rule; then
    kubectl delete prometheusrule -n "${NAMESPACE}" --ignore-not-found "${PROMETHEUS_RULE_NAME}" >/dev/null 2>&1 || true
    kubectl delete prometheusrule -n "${NAMESPACE}" --ignore-not-found "${ADDON_PROMETHEUS_RULE_NAME}" >/dev/null 2>&1 || true
  fi

  if [[ "${FLUENTBIT_ENABLED}" != "true" ]]; then
    kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${FLUENTBIT_CONFIGMAP}" >/dev/null 2>&1 || true
  fi

  delete_legacy_backup_resources
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
  payload_extract_entries "${WORKDIR}" "./manifests" "./images/image.json" "./images/image-index.tsv" || die "解压载荷元数据失败"

  [[ -f "${IMAGE_INDEX}" ]] || die "缺少 image-index.tsv"

  printf '%s\n' "${expected_signature}" > "${signature_file}"
  success "载荷元数据解压完成"
}


image_needed_for_current_action() {
  local image_tag="$1"

  case "${ACTION}" in
    install)
      if [[ "${image_tag}" == */mysql:* || "${image_tag}" == */busybox:* ]]; then
        return 0
      fi
      if [[ "${MONITORING_ENABLED}" == "true" && "${image_tag}" == */mysqld-exporter:* ]]; then
        return 0
      fi
      if [[ "${FLUENTBIT_ENABLED}" == "true" && "${image_tag}" == */fluent-bit:* ]]; then
        return 0
      fi
      return 1
      ;;
    addon-install)
      if addon_selected monitoring && [[ "${image_tag}" == */mysql:* || "${image_tag}" == */mysqld-exporter:* ]]; then
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
    -e "s#__PROMETHEUS_RULE_NAME__#${PROMETHEUS_RULE_NAME}#g" \
    -e "s#__GRAFANA_DASHBOARD_NAME__#${GRAFANA_DASHBOARD_NAME}#g" \
    -e "s#__SERVICE_MONITOR_INTERVAL__#${SERVICE_MONITOR_INTERVAL}#g" \
    -e "s#__SERVICE_MONITOR_SCRAPE_TIMEOUT__#${SERVICE_MONITOR_SCRAPE_TIMEOUT}#g" \
    -e "s#__ADDON_EXPORTER_DEPLOYMENT_NAME__#${ADDON_EXPORTER_DEPLOYMENT_NAME}#g" \
    -e "s#__ADDON_EXPORTER_SERVICE_NAME__#${ADDON_EXPORTER_SERVICE_NAME}#g" \
    -e "s#__ADDON_EXPORTER_SECRET__#${ADDON_EXPORTER_SECRET}#g" \
    -e "s#__ADDON_EXPORTER_USERNAME__#${ADDON_EXPORTER_USERNAME}#g" \
    -e "s#__ADDON_EXPORTER_PASSWORD__#${ADDON_EXPORTER_PASSWORD}#g" \
    -e "s#__ADDON_MONITORING_TARGET__#${ADDON_MONITORING_TARGET}#g" \
    -e "s#__ADDON_SERVICE_MONITOR_NAME__#${ADDON_SERVICE_MONITOR_NAME}#g" \
    -e "s#__ADDON_PROMETHEUS_RULE_NAME__#${ADDON_PROMETHEUS_RULE_NAME}#g" \
    -e "s#__ADDON_GRAFANA_DASHBOARD_NAME__#${ADDON_GRAFANA_DASHBOARD_NAME}#g" \
    -e "s#__FLUENTBIT_CONFIGMAP__#${FLUENTBIT_CONFIGMAP}#g" \
    -e "s#__MYSQL_SLOW_QUERY_TIME__#${MYSQL_SLOW_QUERY_TIME}#g" \
    -e "s#__MYSQL_HOST__#${MYSQL_HOST}#g" \
    -e "s#__MYSQL_PORT__#${MYSQL_PORT}#g" \
    -e "s#__MYSQL_USER__#${MYSQL_USER}#g" \
    -e "s#__MYSQL_AUTH_SECRET__#${MYSQL_AUTH_SECRET}#g" \
    -e "s#__MYSQL_PASSWORD_KEY__#${MYSQL_PASSWORD_KEY}#g" \
    -e "s#__MYSQL_REQUEST_CPU__#${MYSQL_REQUEST_CPU}#g" \
    -e "s#__MYSQL_REQUEST_MEM__#${MYSQL_REQUEST_MEM}#g" \
    -e "s#__MYSQL_LIMIT_CPU__#${MYSQL_LIMIT_CPU}#g" \
    -e "s#__MYSQL_LIMIT_MEM__#${MYSQL_LIMIT_MEM}#g" \
    -e "s#__MYSQL_EXPORTER_REQUEST_CPU__#${MYSQL_EXPORTER_REQUEST_CPU}#g" \
    -e "s#__MYSQL_EXPORTER_REQUEST_MEM__#${MYSQL_EXPORTER_REQUEST_MEM}#g" \
    -e "s#__MYSQL_EXPORTER_LIMIT_CPU__#${MYSQL_EXPORTER_LIMIT_CPU}#g" \
    -e "s#__MYSQL_EXPORTER_LIMIT_MEM__#${MYSQL_EXPORTER_LIMIT_MEM}#g" \
    -e "s#__FLUENTBIT_REQUEST_CPU__#${FLUENTBIT_REQUEST_CPU}#g" \
    -e "s#__FLUENTBIT_REQUEST_MEM__#${FLUENTBIT_REQUEST_MEM}#g" \
    -e "s#__FLUENTBIT_LIMIT_CPU__#${FLUENTBIT_LIMIT_CPU}#g" \
    -e "s#__FLUENTBIT_LIMIT_MEM__#${FLUENTBIT_LIMIT_MEM}#g" \
    -e "s#__MYSQL_INIT_REQUEST_CPU__#${MYSQL_INIT_REQUEST_CPU}#g" \
    -e "s#__MYSQL_INIT_REQUEST_MEM__#${MYSQL_INIT_REQUEST_MEM}#g" \
    -e "s#__MYSQL_INIT_LIMIT_CPU__#${MYSQL_INIT_LIMIT_CPU}#g" \
    -e "s#__MYSQL_INIT_LIMIT_MEM__#${MYSQL_INIT_LIMIT_MEM}#g" \
    -e "s#__MYSQL_IMAGE__#${MYSQL_IMAGE}#g" \
    -e "s#__MYSQL_EXPORTER_IMAGE__#${MYSQL_EXPORTER_IMAGE}#g" \
    -e "s#__FLUENTBIT_IMAGE__#${FLUENTBIT_IMAGE}#g" \
    -e "s#__BUSYBOX_IMAGE__#${BUSYBOX_IMAGE}#g" \
    -e "s#__SYSBENCH_IMAGE__#${SYSBENCH_IMAGE}#g" \
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
    -e "s#__BENCHMARK_PROFILE__#${BENCHMARK_PROFILE}#g"
}


require_manifest_file() {
  local file_path="$1"
  [[ -f "${file_path}" ]] || die "当前产物包缺少必需 manifest: ${file_path}"
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

  if addon_selected monitoring && cluster_supports_prometheus_rule; then
    kubectl delete prometheusrule -n "${NAMESPACE}" --ignore-not-found "${ADDON_PROMETHEUS_RULE_NAME}" >/dev/null 2>&1 || true
  fi

  if addon_selected monitoring; then
    section "移除 monitoring addon"
    delete_external_monitoring_resources
    success "monitoring addon 已移除"
  fi
}


show_addon_status() {
  local external_monitoring="未安装"
  local embedded_monitoring="未安装"
  local embedded_logging="未安装"
  local addon_service_monitor="未安装"
  local embedded_service_monitor="未安装"
  local addon_prometheus_rule="未安装"
  local embedded_prometheus_rule="未安装"

  require_namespace_exists

  resource_exists deployment "${ADDON_EXPORTER_DEPLOYMENT_NAME}" && external_monitoring="已安装"

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

  if cluster_supports_prometheus_rule; then
    resource_exists prometheusrule "${ADDON_PROMETHEUS_RULE_NAME}" && addon_prometheus_rule="已安装"
    resource_exists prometheusrule "${PROMETHEUS_RULE_NAME}" && embedded_prometheus_rule="已安装"
  else
    addon_prometheus_rule="集群未安装 CRD"
    embedded_prometheus_rule="集群未安装 CRD"
  fi

  section "Addon 状态"
  echo "外置 monitoring addon   : ${external_monitoring}"
  echo "内嵌 monitoring sidecar : ${embedded_monitoring}"
  echo "外置 ServiceMonitor     : ${addon_service_monitor}"
  echo "内嵌 ServiceMonitor     : ${embedded_service_monitor}"
  echo "外置 PrometheusRule     : ${addon_prometheus_rule}"
  echo "内嵌 PrometheusRule     : ${embedded_prometheus_rule}"
  echo "Fluent Bit sidecar      : ${embedded_logging}"
  echo
  echo "推荐结论:"
  echo "1. 已有 MySQL 若补监控，优先使用 addon-install，新资源以 Deployment 形式补齐。"
  echo "2. 备份恢复已迁移到独立数据保护系统，不再通过 apps_mysql addon 管理。"
  echo "3. 日志推荐接入平台级 DaemonSet 日志体系，只有在必须采集 Pod 内慢日志文件时才开启 sidecar。"
}


show_status() {
  require_namespace_exists

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
  if cluster_supports_service_monitor; then
    kubectl get servicemonitor -n "${NAMESPACE}" || true
    echo
  fi
  if cluster_supports_prometheus_rule; then
    kubectl get prometheusrule -n "${NAMESPACE}" || true
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
  if ! cluster_supports_prometheus_rule; then
    PROMETHEUS_RULE_ENABLED="false"
  fi

  render_manifest "${MYSQL_MANIFEST}" | kubectl delete -n "${NAMESPACE}" --ignore-not-found -f - >/dev/null || true
  delete_external_monitoring_resources
  delete_legacy_backup_resources
  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found "mysql-benchmark" >/dev/null 2>&1 || true
  kubectl delete service -n "${NAMESPACE}" --ignore-not-found "${METRICS_SERVICE_NAME}" >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${FLUENTBIT_CONFIGMAP}" >/dev/null 2>&1 || true
  if cluster_supports_service_monitor; then
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
    kubectl delete servicemonitor -n "${NAMESPACE}" --ignore-not-found "${ADDON_SERVICE_MONITOR_NAME}" >/dev/null 2>&1 || true
  fi
  if cluster_supports_prometheus_rule; then
    kubectl delete prometheusrule -n "${NAMESPACE}" --ignore-not-found "${PROMETHEUS_RULE_NAME}" >/dev/null 2>&1 || true
    kubectl delete prometheusrule -n "${NAMESPACE}" --ignore-not-found "${ADDON_PROMETHEUS_RULE_NAME}" >/dev/null 2>&1 || true
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

  if [[ "${PROMETHEUS_RULE_ENABLED}" == "true" ]] && ! cluster_supports_prometheus_rule; then
    warn "集群中未安装 PrometheusRule CRD，本次跳过 PrometheusRule 资源"
    PROMETHEUS_RULE_ENABLED="false"
  fi

  section "安装 / 对齐 MySQL"
  apply_mysql_manifests
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

    if ! cluster_supports_prometheus_rule; then
      warn "集群中未安装 PrometheusRule CRD，本次 monitoring addon 跳过告警规则"
      PROMETHEUS_RULE_ENABLED="false"
    fi

    if ! resource_exists statefulset "${STS_NAME}" && [[ "${ADDON_MONITORING_TARGET_EXPLICIT}" != "true" && "${MYSQL_HOST_EXPLICIT}" != "true" ]]; then
      die "为已有外部 MySQL 安装 monitoring addon 时，请显式提供 --monitoring-target，或至少提供 --mysql-host/--mysql-port"
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
}

legacy_backup_resource_selector() {
  echo "app.kubernetes.io/component=backup"
}


create_benchmark_job() {
  local benchmark_job_name="mysql-benchmark-$(date +%Y%m%d%H%M%S)-$RANDOM"

  log "创建压测 Job ${benchmark_job_name}" >&2
  BENCHMARK_JOB_NAME="${benchmark_job_name}" render_manifest "${BENCHMARK_MANIFEST}" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${benchmark_job_name}"
}


delete_legacy_backup_resources() {
  local selector
  selector="$(legacy_backup_resource_selector)"

  kubectl delete cronjob -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete job -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" -l "${selector}" --ignore-not-found >/dev/null 2>&1 || true

  kubectl delete cronjob -n "${NAMESPACE}" --ignore-not-found "mysql-backup" >/dev/null 2>&1 || true
  kubectl delete job -n "${NAMESPACE}" --ignore-not-found "mysql-backup" "mysql-restore" >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "mysql-backup-scripts" >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "mysql-backup-storage" >/dev/null 2>&1 || true
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
$( [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && echo "kubectl get servicemonitor -n ${NAMESPACE}" )
kubectl logs -n ${NAMESPACE} ${STS_NAME}-0 -c mysql --tail=200
$( [[ "${FLUENTBIT_ENABLED}" == "true" ]] && echo "kubectl logs -n ${NAMESPACE} ${STS_NAME}-0 -c fluent-bit --tail=200" )

集群内访问地址:
${STS_NAME}-0.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:3306

NodePort 访问地址:
<node-ip>:${NODE_PORT}

数据复用关键条件:
1. uninstall 时不要加 --delete-pvc
2. namespace 与 --sts-name 保持不变
3. 再次执行 install 即可按当前开关重新对齐
4. 备份恢复已迁移到独立数据保护系统，请勿再从 apps_mysql 安装器里寻找相关入口
EOF
    return 0
  fi

  cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}
kubectl get pvc -n ${NAMESPACE}
$( [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && echo "kubectl get servicemonitor -n ${NAMESPACE}" )
kubectl logs -n ${NAMESPACE} ${STS_NAME}-0 -c mysql --tail=200
$( [[ "${FLUENTBIT_ENABLED}" == "true" ]] && echo "kubectl logs -n ${NAMESPACE} ${STS_NAME}-0 -c fluent-bit --tail=200" )

集群内访问地址:
${STS_NAME}-0.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:3306

NodePort 访问:
已关闭

数据复用关键条件:
1. uninstall 时不要加 --delete-pvc
2. namespace 与 --sts-name 保持不变
3. 再次执行 install 即可按当前开关重新对齐
4. 备份恢复已迁移到独立数据保护系统，请勿再从 apps_mysql 安装器里寻找相关入口
EOF
}


show_post_addon_notes() {
  section "Addon 后续建议"
  cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get deploy -n ${NAMESPACE}
$( cluster_supports_service_monitor && echo "kubectl get servicemonitor -n ${NAMESPACE}" )

业务影响说明:
1. addon-install 默认不修改 MySQL StatefulSet
2. monitoring addon 会额外创建 exporter Deployment
3. 如需日志 sidecar，请改用 install，并提前评估滚动更新窗口
4. 备份恢复能力已迁移到独立数据保护系统
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

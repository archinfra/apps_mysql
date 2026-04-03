#!/usr/bin/env bash

set -Eeuo pipefail

APP_NAME="mysql"
APP_VERSION="1.4.0"
WORKDIR="/tmp/${APP_NAME}-installer"
IMAGE_DIR="${WORKDIR}/images"
MANIFEST_DIR="${WORKDIR}/manifests"

IMAGE_JSON="${IMAGE_DIR}/image.json"
MYSQL_MANIFEST="${MANIFEST_DIR}/innodb-mysql.yaml"
BACKUP_MANIFEST="${MANIFEST_DIR}/mysql-backup.yaml"
RESTORE_MANIFEST="${MANIFEST_DIR}/mysql-restore-job.yaml"
BENCHMARK_MANIFEST="${MANIFEST_DIR}/mysql-benchmark-job.yaml"

REGISTRY_ADDR="${REGISTRY_ADDR:-sealos.hub:5000}"
REGISTRY_USER="${REGISTRY_USER:-admin}"
REGISTRY_PASS="${REGISTRY_PASS:-passw0rd}"

ACTION="install"
HELP_TOPIC="overview"
NAMESPACE="aict"
MYSQL_REPLICAS="1"
MYSQL_ROOT_PASSWORD="passw0rd"
STORAGE_CLASS="nfs"
STORAGE_SIZE="10Gi"
SERVICE_NAME="mysql"
STS_NAME="mysql"
AUTH_SECRET="mysql-auth"
PROBE_CONFIGMAP="mysql-probes"
INIT_CONFIGMAP="mysql-init-users"
MYSQL_CONFIGMAP="mysql-config"
BACKUP_SCRIPT_CONFIGMAP="mysql-backup-scripts"
BACKUP_CRONJOB_NAME="mysql-backup"
BACKUP_STORAGE_SECRET="mysql-backup-storage"
BACKUP_BACKEND="nfs"
NODEPORT_SERVICE_NAME="mysql-nodeport"
NODE_PORT="30306"
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
AUTO_YES="false"
DELETE_PVC="false"
SKIP_IMAGE_PREPARE="false"
REPORT_DIR="./reports"
BENCHMARK_CONCURRENCY="32"
BENCHMARK_ITERATIONS="3"
BENCHMARK_QUERIES="2000"

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
  install                 安装或对齐 MySQL 资源
  uninstall               卸载资源，默认保留 PVC
  status                  查看当前状态
  backup                  执行一次手工备份
  restore                 按快照恢复
  verify-backup-restore   执行备份恢复闭环校验
  benchmark               执行内置压测
  help                    查看中文帮助

help 主题:
  overview        总览
  install         安装、重复执行和开关策略
  backup          NFS / S3 备份说明
  restore         恢复与重装复用说明
  benchmark       压测说明
  architecture    架构设计和边界
  examples        常见示例

快速开始:
  ./mysql-installer.run install \
    --namespace mysql-demo \
    --root-password 'StrongPassw0rd' \
    --backup-backend nfs \
    --backup-nfs-server 192.168.10.2 \
    -y
EOF
}

show_help_install() {
  cat <<'EOF'
install 是“声明式对齐”动作，不只是首次安装。

它适合:
  1. 首次安装
  2. 修改配置后再次执行
  3. 后补安装监控或日志采集 sidecar
  4. 在不删除 PVC 的情况下重装并复用数据

常用参数:
  -n, --namespace <ns>              默认: aict
  --root-password <password>        默认: passw0rd
  --mysql-replicas <num>            默认: 1
  --storage-class <name>            默认: nfs
  --storage-size <size>             默认: 10Gi
  --service-name <name>             默认: mysql
  --sts-name <name>                 默认: mysql
  --nodeport-service-name <name>    默认: mysql-nodeport
  --node-port <port>                默认: 30306
  --wait-timeout <duration>         默认: 10m
  --skip-image-prepare              跳过 docker load/push

特性开关:
  --enable-monitoring / --disable-monitoring
  --enable-service-monitor / --disable-service-monitor
  --enable-fluentbit / --disable-fluentbit
  --enable-backup / --disable-backup
  --enable-benchmark / --disable-benchmark

PVC 复用条件:
  1. 卸载时没有加 --delete-pvc
  2. namespace 不变
  3. --sts-name 不变
  4. volumeClaimTemplates 仍然使用 data 作为卷名
EOF
}

show_help_backup() {
  cat <<'EOF'
备份后端支持:
  --backup-backend nfs|s3

NFS 参数:
  --backup-nfs-server <addr>    NFS 服务端地址，必填
  --backup-nfs-path <path>      NFS 导出路径，默认: /data/nfs-share
  --backup-root-dir <dir>       默认: backups
  --backup-schedule <cron>      默认: 0 2 * * *
  --backup-retention <num>      默认: 5

NFS 是否需要指定目录？
  需要。你至少要提供“服务地址 + 导出路径”。
  安装器会在该导出路径下自动创建:
    <backup-nfs-path>/<backup-root-dir>/mysql/<namespace>/<sts-name>/

S3 参数:
  --s3-endpoint <url>           必填，示例: https://minio.example.com
  --s3-bucket <bucket>          必填
  --s3-prefix <prefix>          可选
  --s3-access-key <ak>          必填
  --s3-secret-key <sk>          必填
  --s3-insecure                 自签名场景可选，跳过 TLS 校验

S3 路径规则:
  <bucket>/<s3-prefix>/<backup-root-dir>/mysql/<namespace>/<sts-name>/
EOF
}

show_help_restore() {
  cat <<'EOF'
restore 支持 latest 或指定快照名。

建议顺序:
  1. 如果 PVC 还在，优先重装复用 PVC
  2. 如果 PVC 不在，再执行 restore

常用参数:
  --restore-snapshot latest
  --restore-snapshot 20260403T020000Z
EOF
}

show_help_benchmark() {
  cat <<'EOF'
benchmark 会在集群内创建 Job，对 MySQL 做并发 SQL 压测。

参数:
  --benchmark-concurrency <n>   默认: 32
  --benchmark-iterations <n>    默认: 3
  --benchmark-queries <n>       默认: 2000
  --report-dir <path>           默认: ./reports
EOF
}

show_help_architecture() {
  cat <<'EOF'
架构边界:
  1. mysqld-exporter 采用 sidecar，便于与数据库实例同生命周期管理
  2. ServiceMonitor 只做“声明”，不在本安装器内强制安装 Prometheus Operator
  3. Fluent Bit 默认采用 sidecar，方便直接采集 MySQL error / slow log
  4. 如果集群没有 ServiceMonitor CRD，安装继续，仅跳过该资源
  5. 若后期补装 Prometheus Operator，可再次执行 install 进行补齐
EOF
}

show_help_examples() {
  cat <<'EOF'
NFS 备份安装:
  ./mysql-installer.run install \
    --namespace mysql-demo \
    --root-password 'StrongPassw0rd' \
    --backup-backend nfs \
    --backup-nfs-server 192.168.10.2 \
    -y

S3 备份安装:
  ./mysql-installer.run install \
    --namespace mysql-demo \
    --root-password 'StrongPassw0rd' \
    --backup-backend s3 \
    --s3-endpoint https://minio.example.com \
    --s3-bucket mysql-backup \
    --s3-access-key <AK> \
    --s3-secret-key <SK> \
    -y
EOF
}

show_help() {
  case "${HELP_TOPIC}" in
    overview|"")
      show_help_overview
      ;;
    install)
      show_help_install
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
    architecture)
      show_help_architecture
      ;;
    examples)
      show_help_examples
      ;;
    *)
      die "未知 help 主题: ${HELP_TOPIC}"
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
      install|uninstall|status|backup|restore|verify-backup-restore|benchmark)
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
        shift 2
        ;;
      --service-name)
        SERVICE_NAME="$2"
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
      --restore-snapshot)
        RESTORE_SNAPSHOT="$2"
        shift 2
        ;;
      --wait-timeout)
        WAIT_TIMEOUT="$2"
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
      --benchmark-concurrency)
        BENCHMARK_CONCURRENCY="$2"
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

needs_backup_storage() {
  [[ "${BACKUP_ENABLED}" == "true" && ( "${ACTION}" == "install" || "${ACTION}" == "backup" || "${ACTION}" == "restore" || "${ACTION}" == "verify-backup-restore" ) ]]
}

cluster_supports_service_monitor() {
  kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1
}

resolve_feature_dependencies() {
  if [[ "${MONITORING_ENABLED}" != "true" && "${SERVICE_MONITOR_ENABLED}" == "true" ]]; then
    warn "monitoring 已关闭，因此自动关闭 ServiceMonitor"
    SERVICE_MONITOR_ENABLED="false"
  fi
}

validate_action_feature_gates() {
  case "${ACTION}" in
    backup|restore|verify-backup-restore)
      [[ "${BACKUP_ENABLED}" == "true" ]] || die "动作 ${ACTION} 依赖备份能力，请使用 --enable-backup"
      ;;
    benchmark)
      [[ "${BENCHMARK_ENABLED}" == "true" ]] || die "当前 benchmark 能力已关闭，请使用 --enable-benchmark"
      ;;
  esac
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

  if [[ -z "${BACKUP_NFS_PATH}" ]]; then
    BACKUP_NFS_PATH="/data/nfs-share"
  fi
}

validate_environment() {
  command -v kubectl >/dev/null 2>&1 || die "未找到 kubectl"
  if [[ "${ACTION}" == "install" && "${SKIP_IMAGE_PREPARE}" != "true" ]]; then
    command -v docker >/dev/null 2>&1 || die "未找到 docker"
    command -v jq >/dev/null 2>&1 || die "未找到 jq"
  fi
}

validate_inputs() {
  [[ "${MYSQL_REPLICAS}" =~ ^[0-9]+$ ]] || die "mysql 副本数必须是数字"
  [[ "${BACKUP_RETENTION}" =~ ^[0-9]+$ ]] || die "备份保留数量必须是数字"
  [[ "${BENCHMARK_CONCURRENCY}" =~ ^[0-9]+$ ]] || die "压测并发必须是数字"
  [[ "${BENCHMARK_ITERATIONS}" =~ ^[0-9]+$ ]] || die "压测轮数必须是数字"
  [[ "${BENCHMARK_QUERIES}" =~ ^[0-9]+$ ]] || die "压测请求量必须是数字"
  [[ "${NODE_PORT}" =~ ^[0-9]+$ ]] || die "nodePort 必须是数字"
  [[ "${MYSQL_SLOW_QUERY_TIME}" =~ ^[0-9]+([.][0-9]+)?$ ]] || die "慢查询阈值必须是数字"
  (( NODE_PORT >= 30000 && NODE_PORT <= 32767 )) || die "nodePort 必须在 30000-32767 之间"
  [[ "${BACKUP_BACKEND}" == "nfs" || "${BACKUP_BACKEND}" == "s3" ]] || die "备份后端仅支持 nfs 或 s3"

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

print_plan() {
  section "执行计划"
  echo "动作                    : ${ACTION}"
  echo "命名空间                : ${NAMESPACE}"
  echo "StatefulSet             : ${STS_NAME}"
  echo "服务名                  : ${SERVICE_NAME}"
  echo "NodePort 服务名         : ${NODEPORT_SERVICE_NAME}"
  echo "NodePort                : ${NODE_PORT}"
  echo "副本数                  : ${MYSQL_REPLICAS}"
  echo "StorageClass            : ${STORAGE_CLASS}"
  echo "存储大小                : ${STORAGE_SIZE}"
  echo "等待超时                : ${WAIT_TIMEOUT}"
  echo "备份能力                : ${BACKUP_ENABLED}"
  echo "备份后端                : ${BACKUP_BACKEND}"
  echo "监控 exporter           : ${MONITORING_ENABLED}"
  echo "ServiceMonitor          : ${SERVICE_MONITOR_ENABLED}"
  echo "Fluent Bit              : ${FLUENTBIT_ENABLED}"
  echo "压测能力                : ${BENCHMARK_ENABLED}"
  if [[ "${FLUENTBIT_ENABLED}" == "true" ]]; then
    echo "慢查询阈值(秒)          : ${MYSQL_SLOW_QUERY_TIME}"
  fi
  if needs_backup_storage; then
    echo "备份根目录              : ${BACKUP_ROOT_DIR}"
    echo "备份计划                : ${BACKUP_SCHEDULE}"
    echo "保留数量                : ${BACKUP_RETENTION}"
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
  if [[ "${ACTION}" == "restore" ]]; then
    echo "恢复快照                : ${RESTORE_SNAPSHOT}"
  fi
  if [[ "${ACTION}" == "benchmark" ]]; then
    echo "报告目录                : ${REPORT_DIR}"
    echo "压测并发                : ${BENCHMARK_CONCURRENCY}"
    echo "压测轮数                : ${BENCHMARK_ITERATIONS}"
    echo "压测请求量              : ${BENCHMARK_QUERIES}"
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
  [[ -f "${BACKUP_MANIFEST}" ]] || die "缺少备份 manifest"
  [[ -f "${RESTORE_MANIFEST}" ]] || die "缺少恢复 manifest"
  [[ -f "${BENCHMARK_MANIFEST}" ]] || die "缺少压测 manifest"
  [[ -f "${IMAGE_JSON}" ]] || die "缺少 image.json"
  success "载荷解压完成"
}

docker_login() {
  log "登录镜像仓库 ${REGISTRY_ADDR}"
  if echo "${REGISTRY_PASS}" | docker login "${REGISTRY_ADDR}" -u "${REGISTRY_USER}" --password-stdin >/dev/null 2>&1; then
    success "镜像仓库登录成功"
  else
    warn "镜像仓库登录失败，继续尝试后续流程"
  fi
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

    local tar_name image_tag tar_path
    tar_name="$(jq -r '.tar' <<<"${item}")"
    image_tag="$(jq -r '.tag // .pull' <<<"${item}")"
    tar_path="${IMAGE_DIR}/${tar_name}"

    [[ -f "${tar_path}" ]] || continue

    log "导入镜像归档 ${tar_name}"
    docker load -i "${tar_path}" >/dev/null
    log "推送镜像 ${image_tag}"
    docker push "${image_tag}" >/dev/null
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

  if backup_backend_is_nfs; then
    backup_nfs_enabled="true"
  else
    backup_s3_enabled="true"
  fi

  cat "${file_path}" \
    | render_optional_block "FEATURE_MONITORING" "${MONITORING_ENABLED}" \
    | render_optional_block "FEATURE_SERVICE_MONITOR" "${SERVICE_MONITOR_ENABLED}" \
    | render_optional_block "FEATURE_FLUENTBIT" "${FLUENTBIT_ENABLED}" \
    | render_optional_block "BACKUP_NFS" "${backup_nfs_enabled}" \
    | render_optional_block "BACKUP_S3" "${backup_s3_enabled}"
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
    -e "s#__FLUENTBIT_CONFIGMAP__#${FLUENTBIT_CONFIGMAP}#g" \
    -e "s#__MYSQL_SLOW_QUERY_TIME__#${MYSQL_SLOW_QUERY_TIME}#g" \
    -e "s#__BACKUP_SCRIPT_CONFIGMAP__#${BACKUP_SCRIPT_CONFIGMAP}#g" \
    -e "s#__BACKUP_CRONJOB_NAME__#${BACKUP_CRONJOB_NAME}#g" \
    -e "s#__BACKUP_STORAGE_SECRET__#${BACKUP_STORAGE_SECRET}#g" \
    -e "s#__BACKUP_BACKEND__#${BACKUP_BACKEND}#g" \
    -e "s#__BACKUP_NFS_SERVER__#${BACKUP_NFS_SERVER}#g" \
    -e "s#__BACKUP_NFS_PATH__#${BACKUP_NFS_PATH}#g" \
    -e "s#__BACKUP_ROOT_DIR__#${BACKUP_ROOT_DIR}#g" \
    -e "s#__BACKUP_SCHEDULE__#${BACKUP_SCHEDULE}#g" \
    -e "s#__BACKUP_RETENTION__#${BACKUP_RETENTION}#g" \
    -e "s#__RESTORE_SNAPSHOT__#${RESTORE_SNAPSHOT}#g" \
    -e "s#__S3_ENDPOINT__#${S3_ENDPOINT}#g" \
    -e "s#__S3_BUCKET__#${S3_BUCKET}#g" \
    -e "s#__S3_PREFIX__#${S3_PREFIX}#g" \
    -e "s#__S3_ACCESS_KEY__#${S3_ACCESS_KEY}#g" \
    -e "s#__S3_SECRET_KEY__#${S3_SECRET_KEY}#g" \
    -e "s#__S3_INSECURE__#${S3_INSECURE}#g" \
    -e "s#__MYSQL_IMAGE__#${REGISTRY_ADDR}/kube4/mysql:8.0.45#g" \
    -e "s#__MYSQL_EXPORTER_IMAGE__#${REGISTRY_ADDR}/kube4/mysqld-exporter:v0.15.1#g" \
    -e "s#__FLUENTBIT_IMAGE__#${REGISTRY_ADDR}/kube4/fluent-bit:3.0.7#g" \
    -e "s#__S3_CLIENT_IMAGE__#${REGISTRY_ADDR}/kube4/minio-mc:latest#g" \
    -e "s#__BUSYBOX_IMAGE__#${REGISTRY_ADDR}/kube4/busybox:v1#g" \
    -e "s#__BENCHMARK_JOB_NAME__#${BENCHMARK_JOB_NAME:-mysql-benchmark}#g" \
    -e "s#__BENCHMARK_CONCURRENCY__#${BENCHMARK_CONCURRENCY}#g" \
    -e "s#__BENCHMARK_ITERATIONS__#${BENCHMARK_ITERATIONS}#g" \
    -e "s#__BENCHMARK_QUERIES__#${BENCHMARK_QUERIES}#g"
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

mysql_exec() {
  local sql="$1"
  kubectl exec -n "${NAMESPACE}" "$(mysql_pod_name)" -- env MYSQL_PWD="local@paasw0rd" mysql -h localhost -P 3306 -ulocalroot -Nse "${sql}"
}

wait_for_job() {
  local job_name="$1"

  log "等待 Job/${job_name} 完成"
  if kubectl wait --for=condition=complete "job/${job_name}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}" >/dev/null 2>&1; then
    success "Job/${job_name} 已完成"
    return 0
  fi

  warn "Job/${job_name} 未正常完成，输出日志如下"
  kubectl logs -n "${NAMESPACE}" "job/${job_name}" --tail=-1 || true
  return 1
}

create_manual_backup_job() {
  local job_name="${BACKUP_CRONJOB_NAME}-manual-$(date +%Y%m%d%H%M%S)-$RANDOM"

  kubectl get cronjob "${BACKUP_CRONJOB_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1 || die "未找到备份 CronJob/${BACKUP_CRONJOB_NAME}"
  log "创建手工备份 Job ${job_name}" >&2
  kubectl create job "${job_name}" --from="cronjob/${BACKUP_CRONJOB_NAME}" -n "${NAMESPACE}" >/dev/null
  echo "${job_name}"
}

create_restore_job() {
  local restore_job_name="mysql-restore-$(date +%Y%m%d%H%M%S)-$RANDOM"
  export BENCHMARK_JOB_NAME=""

  log "创建恢复 Job ${restore_job_name}" >&2
  RESTORE_JOB_NAME="${restore_job_name}" render_manifest "${RESTORE_MANIFEST}" \
    | sed -e "s#__RESTORE_JOB_NAME__#${restore_job_name}#g" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${restore_job_name}"
}

create_benchmark_job() {
  BENCHMARK_JOB_NAME="mysql-benchmark-$(date +%Y%m%d%H%M%S)-$RANDOM"
  export BENCHMARK_JOB_NAME

  log "创建压测 Job ${BENCHMARK_JOB_NAME}" >&2
  apply_benchmark_job >/dev/null
  echo "${BENCHMARK_JOB_NAME}"
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

delete_backup_resources() {
  kubectl delete cronjob -n "${NAMESPACE}" --ignore-not-found "${BACKUP_CRONJOB_NAME}" >/dev/null 2>&1 || true
  kubectl delete configmap -n "${NAMESPACE}" --ignore-not-found "${BACKUP_SCRIPT_CONFIGMAP}" >/dev/null 2>&1 || true
  kubectl delete secret -n "${NAMESPACE}" --ignore-not-found "${BACKUP_STORAGE_SECRET}" >/dev/null 2>&1 || true
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

install_app() {
  extract_payload
  prepare_images
  ensure_namespace

  if [[ "${SERVICE_MONITOR_ENABLED}" == "true" ]] && ! cluster_supports_service_monitor; then
    warn "集群中未安装 ServiceMonitor CRD，本次仅跳过该资源"
    SERVICE_MONITOR_ENABLED="false"
  fi

  section "安装 / 对齐 MySQL"
  apply_mysql_manifests
  if [[ "${BACKUP_ENABLED}" == "true" ]]; then
    apply_backup_manifests
  else
    warn "当前关闭了备份能力，将主动清理备份资源"
  fi
  cleanup_disabled_optional_resources
  wait_for_statefulset_ready
  wait_for_mysql_ready
  success "MySQL 安装/对齐完成"
}

show_status() {
  section "运行状态"
  kubectl get statefulset -n "${NAMESPACE}" || true
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

run_backup() {
  extract_payload
  ensure_namespace
  apply_backup_manifests
  wait_for_mysql_ready

  section "执行手工备份"
  local job_name
  job_name="$(create_manual_backup_job)"
  wait_for_job "${job_name}" || die "备份任务失败"
}

run_restore() {
  extract_payload
  ensure_namespace
  apply_backup_manifests
  wait_for_mysql_ready

  section "执行数据恢复"
  local restore_job_name
  restore_job_name="$(create_restore_job)"
  wait_for_job "${restore_job_name}" || die "恢复任务失败"
}

verify_backup_restore() {
  extract_payload
  ensure_namespace
  apply_backup_manifests
  wait_for_mysql_ready

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
statefulset=${STS_NAME}
backup_job=${backup_job}
restore_job=${restore_job}
backup_backend=${BACKUP_BACKEND}
snapshot_value=${snapshot_value}
restored_value=${restored_value}
status=success
EOF
)")"

  success "备份/恢复闭环校验成功"
  echo "报告文件: ${report_path}"
}

run_benchmark() {
  extract_payload
  wait_for_mysql_ready

  section "执行压测"
  local benchmark_job report_body report_path
  benchmark_job="$(create_benchmark_job)"
  wait_for_job "${benchmark_job}" || die "压测任务失败"

  report_body="$(kubectl logs -n "${NAMESPACE}" "job/${benchmark_job}" --tail=-1)"
  report_path="$(write_report "${benchmark_job}.txt" "${report_body}")"

  success "压测完成"
  echo "报告文件: ${report_path}"
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

show_post_install_notes() {
  section "后续建议"
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

重装复用数据的关键条件:
1. uninstall 时不要加 --delete-pvc
2. namespace 与 --sts-name 保持不变
3. 再次执行 install 即可按当前开关对齐配置

手工压测:
$( [[ "${BENCHMARK_ENABLED}" == "true" ]] && echo "./mysql-installer.run benchmark --namespace ${NAMESPACE} --report-dir ./reports -y" )
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

  if [[ "${ACTION}" != "status" ]]; then
    confirm_plan
  fi

  case "${ACTION}" in
    install)
      install_app
      show_post_install_notes
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

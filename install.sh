#!/usr/bin/env bash

set -Eeuo pipefail

APP_NAME="mysql"
APP_VERSION="1.2.0"
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
NODEPORT_SERVICE_NAME="mysql-nodeport"
NODE_PORT="30306"
BACKUP_NFS_SERVER=""
BACKUP_NFS_PATH="/data/nfs-share"
BACKUP_ROOT_DIR="backups"
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_RETENTION="5"
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
  echo -e "${GREEN}${BOLD}MySQL Offline Installer${NC}"
  echo -e "${CYAN}version: ${APP_VERSION}${NC}"
}

usage() {
  cat <<'EOF'
Usage:
  ./mysql-installer.run install|uninstall|status|backup|restore|verify-backup-restore|benchmark [options]

Actions:
  install                       Deploy MySQL and backup resources
  uninstall                     Remove deployed resources
  status                        Show current runtime status
  backup                        Trigger a manual backup job
  restore                       Restore from a snapshot
  verify-backup-restore         Run an end-to-end backup/restore validation
  benchmark                     Run an offline benchmark and export a report

Core Options:
  -n, --namespace <ns>          Namespace, default: aict
  --mysql-replicas <num>        MySQL replicas, default: 1
  --storage-class <name>        StorageClass, default: nfs
  --storage-size <size>         PVC size, default: 10Gi
  --root-password <password>    MySQL root password, default: passw0rd
  --service-name <name>         Headless service name, default: mysql
  --sts-name <name>             StatefulSet name, default: mysql
  --nodeport-service-name <n>   NodePort service name, default: mysql-nodeport
  --node-port <port>            NodePort, default: 30306
  --wait-timeout <duration>     Wait timeout, default: 10m
  --skip-image-prepare          Skip docker load and registry push
  --delete-pvc                  Delete PVCs on uninstall

Backup / Restore Options:
  --backup-nfs-server <addr>    NFS server for backup storage
  --backup-nfs-path <path>      NFS path, default: /data/nfs-share
  --backup-root-dir <dir>       Root backup directory, default: backups
  --backup-schedule <cron>      Cron schedule, default: 0 2 * * *
  --backup-retention <num>      Snapshot retention, default: 5
  --restore-snapshot <name>     Snapshot name or latest, default: latest

Benchmark Options:
  --report-dir <path>           Local report directory, default: ./reports
  --benchmark-concurrency <n>   Parallel workers, default: 32
  --benchmark-iterations <n>    Loops per worker, default: 3
  --benchmark-queries <n>       Requested operations, default: 2000

General:
  -y, --yes                     Skip confirmation
  -h, --help                    Show help

Examples:
  ./mysql-installer.run install --namespace mysql-demo --backup-nfs-server 192.168.10.2 -y
  ./mysql-installer.run backup --namespace mysql-demo --backup-nfs-server 192.168.10.2 -y
  ./mysql-installer.run restore --namespace mysql-demo --backup-nfs-server 192.168.10.2 --restore-snapshot latest -y
  ./mysql-installer.run verify-backup-restore --namespace mysql-demo --backup-nfs-server 192.168.10.2 -y
  ./mysql-installer.run benchmark --namespace mysql-demo --report-dir ./reports -y
EOF
}

parse_args() {
  [[ $# -eq 0 ]] && {
    usage
    exit 0
  }

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
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

needs_backup_storage() {
  [[ "${ACTION}" == "install" || "${ACTION}" == "backup" || "${ACTION}" == "restore" || "${ACTION}" == "verify-backup-restore" ]]
}

prompt_missing_values() {
  if needs_backup_storage && [[ -z "${BACKUP_NFS_SERVER}" ]]; then
    echo -ne "${YELLOW}Please enter the backup NFS server IP or hostname:${NC} "
    read -r BACKUP_NFS_SERVER
  fi

  if [[ -z "${BACKUP_NFS_PATH}" ]]; then
    BACKUP_NFS_PATH="/data/nfs-share"
  fi
}

validate_environment() {
  command -v kubectl >/dev/null 2>&1 || die "kubectl command not found"
  [[ "${ACTION}" == "status" ]] || command -v docker >/dev/null 2>&1 || die "docker command not found"
  [[ "${ACTION}" == "status" ]] || command -v jq >/dev/null 2>&1 || die "jq command not found"
}

validate_inputs() {
  [[ "${MYSQL_REPLICAS}" =~ ^[0-9]+$ ]] || die "mysql replicas must be a number"
  [[ "${BACKUP_RETENTION}" =~ ^[0-9]+$ ]] || die "backup retention must be a number"
  [[ "${BENCHMARK_CONCURRENCY}" =~ ^[0-9]+$ ]] || die "benchmark concurrency must be a number"
  [[ "${BENCHMARK_ITERATIONS}" =~ ^[0-9]+$ ]] || die "benchmark iterations must be a number"
  [[ "${BENCHMARK_QUERIES}" =~ ^[0-9]+$ ]] || die "benchmark queries must be a number"
  [[ "${NODE_PORT}" =~ ^[0-9]+$ ]] || die "node port must be a number"
  (( NODE_PORT >= 30000 && NODE_PORT <= 32767 )) || die "node port must be between 30000 and 32767"
  needs_backup_storage && [[ -n "${BACKUP_NFS_SERVER}" ]] || true
  if needs_backup_storage && [[ -z "${BACKUP_NFS_SERVER}" ]]; then
    die "backup nfs server cannot be empty"
  fi
}

print_plan() {
  section "Execution Plan"
  echo "Action                : ${ACTION}"
  echo "Namespace             : ${NAMESPACE}"
  echo "StatefulSet           : ${STS_NAME}"
  echo "Service               : ${SERVICE_NAME}"
  echo "NodePort Service      : ${NODEPORT_SERVICE_NAME}"
  echo "NodePort              : ${NODE_PORT}"
  echo "Replicas              : ${MYSQL_REPLICAS}"
  echo "StorageClass          : ${STORAGE_CLASS}"
  echo "Storage Size          : ${STORAGE_SIZE}"
  echo "Wait Timeout          : ${WAIT_TIMEOUT}"
  if needs_backup_storage; then
    echo "Backup NFS Server     : ${BACKUP_NFS_SERVER}"
    echo "Backup NFS Path       : ${BACKUP_NFS_PATH}"
    echo "Backup Root Dir       : ${BACKUP_ROOT_DIR}"
    echo "Backup Schedule       : ${BACKUP_SCHEDULE}"
    echo "Backup Retention      : ${BACKUP_RETENTION}"
  fi
  if [[ "${ACTION}" == "restore" ]]; then
    echo "Restore Snapshot      : ${RESTORE_SNAPSHOT}"
  fi
  if [[ "${ACTION}" == "benchmark" ]]; then
    echo "Report Dir            : ${REPORT_DIR}"
    echo "Concurrency           : ${BENCHMARK_CONCURRENCY}"
    echo "Iterations            : ${BENCHMARK_ITERATIONS}"
    echo "Query Count           : ${BENCHMARK_QUERIES}"
  fi
}

confirm_plan() {
  [[ "${AUTO_YES}" == "true" ]] && return 0
  print_plan
  echo
  echo -ne "${YELLOW}Continue? [y/N]:${NC} "
  read -r answer
  [[ "${answer}" =~ ^[Yy]$ ]] || die "Canceled"
}

extract_payload() {
  section "Extract Payload"
  rm -rf "${WORKDIR}"
  mkdir -p "${WORKDIR}" "${IMAGE_DIR}" "${MANIFEST_DIR}"

  local payload_line
  payload_line="$(awk '/^__PAYLOAD_BELOW__$/ { print NR + 1; exit }' "$0")"
  [[ -n "${payload_line}" ]] || die "Payload marker not found"

  log "Extracting payload into ${WORKDIR}"
  tail -n +"${payload_line}" "$0" | tar -xz -C "${WORKDIR}" >/dev/null 2>&1 || die "Failed to extract payload"

  [[ -f "${MYSQL_MANIFEST}" ]] || die "MySQL manifest is missing"
  [[ -f "${BACKUP_MANIFEST}" ]] || die "Backup manifest is missing"
  [[ -f "${RESTORE_MANIFEST}" ]] || die "Restore manifest is missing"
  [[ -f "${BENCHMARK_MANIFEST}" ]] || die "Benchmark manifest is missing"
  [[ -f "${IMAGE_JSON}" ]] || die "image.json is missing"
  success "Payload extracted"
}

docker_login() {
  log "Logging into registry ${REGISTRY_ADDR}"
  if echo "${REGISTRY_PASS}" | docker login "${REGISTRY_ADDR}" -u "${REGISTRY_USER}" --password-stdin >/dev/null 2>&1; then
    success "Registry login succeeded"
  else
    warn "Registry login failed, continuing anyway"
  fi
}

prepare_images() {
  [[ "${SKIP_IMAGE_PREPARE}" == "true" ]] && {
    warn "Skipping image prepare by request"
    return 0
  }

  section "Prepare Images"
  docker_login

  local count=0
  while IFS= read -r item; do
    [[ -n "${item}" ]] || continue

    local tar_name image_tag tar_path
    tar_name="$(jq -r '.tar' <<<"${item}")"
    image_tag="$(jq -r '.tag // .pull' <<<"${item}")"
    tar_path="${IMAGE_DIR}/${tar_name}"

    [[ -f "${tar_path}" ]] || continue

    log "Loading ${tar_name}"
    docker load -i "${tar_path}" >/dev/null
    log "Pushing ${image_tag}"
    docker push "${image_tag}" >/dev/null
    count=$((count + 1))
  done < <(jq -c '.[]' "${IMAGE_JSON}")

  (( count > 0 )) || die "No image archives found in payload"
  success "Prepared ${count} image archive(s)"
}

ensure_namespace() {
  if kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1; then
    return 0
  fi
  log "Creating namespace ${NAMESPACE}"
  kubectl create namespace "${NAMESPACE}" >/dev/null
}

template_replace() {
  local file_path="$1"
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
    -e "s#__BACKUP_SCRIPT_CONFIGMAP__#${BACKUP_SCRIPT_CONFIGMAP}#g" \
    -e "s#__BACKUP_CRONJOB_NAME__#${BACKUP_CRONJOB_NAME}#g" \
    -e "s#__BACKUP_NFS_SERVER__#${BACKUP_NFS_SERVER}#g" \
    -e "s#__BACKUP_NFS_PATH__#${BACKUP_NFS_PATH}#g" \
    -e "s#__BACKUP_ROOT_DIR__#${BACKUP_ROOT_DIR}#g" \
    -e "s#__BACKUP_SCHEDULE__#${BACKUP_SCHEDULE}#g" \
    -e "s#__BACKUP_RETENTION__#${BACKUP_RETENTION}#g" \
    -e "s#__RESTORE_SNAPSHOT__#${RESTORE_SNAPSHOT}#g" \
    -e "s#__MYSQL_IMAGE__#${REGISTRY_ADDR}/kube4/mysql:8.0.45#g" \
    -e "s#__BUSYBOX_IMAGE__#${REGISTRY_ADDR}/kube4/busybox:v1#g" \
    -e "s#__BENCHMARK_JOB_NAME__#${BENCHMARK_JOB_NAME:-mysql-benchmark}#g" \
    -e "s#__BENCHMARK_CONCURRENCY__#${BENCHMARK_CONCURRENCY}#g" \
    -e "s#__BENCHMARK_ITERATIONS__#${BENCHMARK_ITERATIONS}#g" \
    -e "s#__BENCHMARK_QUERIES__#${BENCHMARK_QUERIES}#g" \
    "$file_path"
}

apply_mysql_manifests() {
  template_replace "${MYSQL_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}

apply_backup_manifests() {
  template_replace "${BACKUP_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}

apply_restore_job() {
  template_replace "${RESTORE_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}

apply_benchmark_job() {
  template_replace "${BENCHMARK_MANIFEST}" | kubectl apply -n "${NAMESPACE}" -f -
}

wait_for_statefulset_ready() {
  log "Waiting for StatefulSet/${STS_NAME}"
  kubectl rollout status "statefulset/${STS_NAME}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}"
}

mysql_pod_name() {
  echo "${STS_NAME}-0"
}

wait_for_mysql_ready() {
  local pod_name
  pod_name="$(mysql_pod_name)"

  log "Waiting for Pod/${pod_name}"
  kubectl wait --for=condition=ready "pod/${pod_name}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}" >/dev/null

  log "Waiting for MySQL to accept connections"
  local retries=60
  local attempt
  for (( attempt=1; attempt<=retries; attempt++ )); do
    if kubectl exec -n "${NAMESPACE}" "${pod_name}" -- env MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysqladmin -uroot ping >/dev/null 2>&1; then
      success "MySQL is ready"
      return 0
    fi
    sleep 5
  done

  die "MySQL did not become ready in time"
}

mysql_exec() {
  local sql="$1"
  kubectl exec -n "${NAMESPACE}" "$(mysql_pod_name)" -- env MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql -uroot -Nse "${sql}"
}

wait_for_job() {
  local job_name="$1"

  log "Waiting for Job/${job_name}"
  if kubectl wait --for=condition=complete "job/${job_name}" -n "${NAMESPACE}" --timeout="${WAIT_TIMEOUT}" >/dev/null 2>&1; then
    success "Job/${job_name} completed"
    return 0
  fi

  warn "Job/${job_name} did not complete successfully"
  kubectl logs -n "${NAMESPACE}" "job/${job_name}" --tail=-1 || true
  return 1
}

create_manual_backup_job() {
  local job_name="${BACKUP_CRONJOB_NAME}-manual-$(date +%Y%m%d%H%M%S)"

  kubectl get cronjob "${BACKUP_CRONJOB_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1 || die "Backup CronJob/${BACKUP_CRONJOB_NAME} not found"
  log "Creating manual backup job ${job_name}" >&2
  kubectl create job "${job_name}" --from="cronjob/${BACKUP_CRONJOB_NAME}" -n "${NAMESPACE}" >/dev/null
  echo "${job_name}"
}

create_restore_job() {
  local restore_job_name="mysql-restore-$(date +%Y%m%d%H%M%S)"
  export BENCHMARK_JOB_NAME=""

  log "Creating restore job ${restore_job_name}" >&2
  RESTORE_JOB_NAME="${restore_job_name}" template_replace "${RESTORE_MANIFEST}" \
    | sed -e "s#__RESTORE_JOB_NAME__#${restore_job_name}#g" \
    | kubectl apply -n "${NAMESPACE}" -f - >/dev/null

  echo "${restore_job_name}"
}

create_benchmark_job() {
  BENCHMARK_JOB_NAME="mysql-benchmark-$(date +%Y%m%d%H%M%S)"
  export BENCHMARK_JOB_NAME

  log "Creating benchmark job ${BENCHMARK_JOB_NAME}" >&2
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

install_app() {
  extract_payload
  prepare_images
  ensure_namespace

  section "Install MySQL"
  apply_mysql_manifests
  apply_backup_manifests
  wait_for_statefulset_ready
  wait_for_mysql_ready
  success "MySQL deployment completed"
}

show_status() {
  section "Runtime Status"
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
  kubectl get jobs -n "${NAMESPACE}" || true
}

run_backup() {
  extract_payload
  ensure_namespace
  apply_backup_manifests
  wait_for_mysql_ready

  section "Manual Backup"
  local job_name
  job_name="$(create_manual_backup_job)"
  wait_for_job "${job_name}" || die "Backup job failed"
}

run_restore() {
  extract_payload
  ensure_namespace
  apply_backup_manifests
  wait_for_mysql_ready

  section "Restore Snapshot"
  local restore_job_name
  restore_job_name="$(create_restore_job)"
  wait_for_job "${restore_job_name}" || die "Restore job failed"
}

verify_backup_restore() {
  extract_payload
  ensure_namespace
  apply_backup_manifests
  wait_for_mysql_ready

  section "Verify Backup And Restore"

  local snapshot_value changed_value restored_value backup_job restore_job report_path
  snapshot_value="snapshot-$(date +%s)"
  changed_value="changed-$(date +%s)"

  log "Creating validation dataset"
  mysql_exec "CREATE DATABASE IF NOT EXISTS offline_validation;"
  mysql_exec "CREATE TABLE IF NOT EXISTS offline_validation.backup_restore_check (id INT PRIMARY KEY, marker VARCHAR(128) NOT NULL);"
  mysql_exec "REPLACE INTO offline_validation.backup_restore_check (id, marker) VALUES (1, '${snapshot_value}');"

  backup_job="$(create_manual_backup_job)"
  wait_for_job "${backup_job}" || die "Backup validation job failed"

  log "Mutating validation dataset after snapshot"
  mysql_exec "UPDATE offline_validation.backup_restore_check SET marker='${changed_value}' WHERE id=1;"

  restore_job="$(create_restore_job)"
  wait_for_job "${restore_job}" || die "Restore validation job failed"

  restored_value="$(mysql_exec "SELECT marker FROM offline_validation.backup_restore_check WHERE id=1;")"
  [[ "${restored_value}" == "${snapshot_value}" ]] || die "Backup/restore verification failed: expected ${snapshot_value}, got ${restored_value}"

  report_path="$(write_report "backup-restore-${NAMESPACE}-$(date +%Y%m%d%H%M%S).txt" "$(cat <<EOF
mysql backup/restore verification report
generated_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
namespace=${NAMESPACE}
statefulset=${STS_NAME}
backup_job=${backup_job}
restore_job=${restore_job}
snapshot_value=${snapshot_value}
restored_value=${restored_value}
status=success
EOF
)")"

  success "Backup/restore verification succeeded"
  echo "Report: ${report_path}"
}

run_benchmark() {
  extract_payload
  wait_for_mysql_ready

  section "Run Benchmark"
  local benchmark_job report_body report_path
  benchmark_job="$(create_benchmark_job)"
  wait_for_job "${benchmark_job}" || die "Benchmark job failed"

  report_body="$(kubectl logs -n "${NAMESPACE}" "job/${benchmark_job}" --tail=-1)"
  report_path="$(write_report "${benchmark_job}.txt" "${report_body}")"

  success "Benchmark completed"
  echo "Report: ${report_path}"
}

delete_pvcs_if_requested() {
  [[ "${DELETE_PVC}" == "true" ]] || return 0

  log "Deleting PVCs created by StatefulSet/${STS_NAME}"
  mapfile -t pvcs < <(kubectl get pvc -n "${NAMESPACE}" -o name | grep "^persistentvolumeclaim/data-${STS_NAME}-" || true)
  if [[ ${#pvcs[@]} -eq 0 ]]; then
    return 0
  fi
  kubectl delete -n "${NAMESPACE}" "${pvcs[@]}" >/dev/null || true
}

uninstall_app() {
  extract_payload
  section "Uninstall MySQL"

  template_replace "${MYSQL_MANIFEST}" | kubectl delete -n "${NAMESPACE}" --ignore-not-found -f - >/dev/null || true
  template_replace "${BACKUP_MANIFEST}" | kubectl delete -n "${NAMESPACE}" --ignore-not-found -f - >/dev/null || true
  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found "mysql-restore" >/dev/null 2>&1 || true
  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found "mysql-benchmark" >/dev/null 2>&1 || true
  kubectl delete jobs -n "${NAMESPACE}" --ignore-not-found -l job-name >/dev/null 2>&1 || true
  delete_pvcs_if_requested

  success "MySQL uninstall finished"
}

show_post_install_notes() {
  section "Next Steps"
  cat <<EOF
kubectl get pods -n ${NAMESPACE}
kubectl get svc -n ${NAMESPACE}
kubectl get pvc -n ${NAMESPACE}
kubectl get cronjob -n ${NAMESPACE}

Internal endpoint:
${STS_NAME}-0.${SERVICE_NAME}.${NAMESPACE}.svc.cluster.local:3306

NodePort endpoint:
<node-ip>:${NODE_PORT}

Manual benchmark:
./mysql-installer.run benchmark --namespace ${NAMESPACE} --report-dir ./reports -y
EOF
}

cleanup() {
  rm -rf "${WORKDIR}" >/dev/null 2>&1 || true
}

main() {
  trap cleanup EXIT

  banner
  parse_args "$@"
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
      die "Unsupported action: ${ACTION}"
      ;;
  esac
}

main "$@"

exit 0

__PAYLOAD_BELOW__

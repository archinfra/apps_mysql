#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_FILE="${ROOT_DIR}/payload.tar.gz"
TEMP_DIR="${ROOT_DIR}/.build-payload"
IMAGES_DIR="${ROOT_DIR}/images"
MANIFESTS_DIR="${ROOT_DIR}/manifests"
DIST_DIR="${ROOT_DIR}/dist"
IMAGE_JSON="${IMAGES_DIR}/image.json"
ASSEMBLER="${ROOT_DIR}/scripts/assemble-install.sh"
INSTALL_MODULE_ROOT="${ROOT_DIR}/scripts/install/modules"
SELECTED_IMAGE_ITEMS_FILE="${TEMP_DIR}/selected-images.jsonl"

ARCH="amd64"
PLATFORM="linux/amd64"
BUILD_ALL_ARCH="false"
PROFILE="integrated"
BUILD_ALL_PROFILES="false"
INSTALLER_NAME=""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

usage() {
  cat <<'EOF'
Usage:
  ./build.sh [--arch amd64|arm64|all] [--profile integrated|backup-restore|benchmark|monitoring|all]

Examples:
  ./build.sh --arch amd64 --profile integrated
  ./build.sh --arch arm64 --profile benchmark
  ./build.sh --arch all --profile all
EOF
}

normalize_arch() {
  case "$1" in
    amd64|amd|x86_64)
      ARCH="amd64"
      PLATFORM="linux/amd64"
      BUILD_ALL_ARCH="false"
      ;;
    arm64|arm|aarch64)
      ARCH="arm64"
      PLATFORM="linux/arm64"
      BUILD_ALL_ARCH="false"
      ;;
    all)
      BUILD_ALL_ARCH="true"
      ;;
    *)
      die "Unsupported arch: $1"
      ;;
  esac
}

normalize_profile() {
  case "$1" in
    integrated|backup-restore|benchmark|monitoring)
      PROFILE="$1"
      BUILD_ALL_PROFILES="false"
      ;;
    all)
      BUILD_ALL_PROFILES="true"
      ;;
    *)
      die "Unsupported profile: $1"
      ;;
  esac
}

profile_installer_basename() {
  case "${PROFILE}" in
    integrated)
      echo "mysql-installer"
      ;;
    backup-restore)
      echo "mysql-backup-restore"
      ;;
    benchmark)
      echo "mysql-benchmark"
      ;;
    monitoring)
      echo "mysql-monitoring"
      ;;
  esac
}

refresh_installer_name() {
  INSTALLER_NAME="$(profile_installer_basename)-${ARCH}.run"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --arch|-a)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        normalize_arch "$2"
        shift 2
        ;;
      --profile|-p)
        [[ $# -ge 2 ]] || die "Missing value for $1"
        normalize_profile "$2"
        shift 2
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

check_requirements() {
  command -v jq >/dev/null 2>&1 || die "jq is required"
  command -v docker >/dev/null 2>&1 || die "docker is required"
  [[ -f "${ASSEMBLER}" ]] || die "scripts/assemble-install.sh is missing"
  [[ -d "${INSTALL_MODULE_ROOT}" ]] || die "scripts/install/modules is missing"
  find "${INSTALL_MODULE_ROOT}" -maxdepth 1 -type f -name '*.sh' | grep -q . || die "scripts/install/modules is empty"
  [[ -f "${ROOT_DIR}/install.sh" ]] || die "install.sh is missing"
  [[ -d "${MANIFESTS_DIR}" ]] || die "manifests directory is missing"
  [[ -d "${IMAGES_DIR}" ]] || die "images directory is missing"
  [[ -f "${IMAGE_JSON}" ]] || die "images/image.json is missing"
  grep -q '^__PAYLOAD_BELOW__$' "${ROOT_DIR}/install.sh" || die "install.sh is missing __PAYLOAD_BELOW__ marker"
}

assemble_installer() {
  log "Assembling install.sh from scripts/install/modules"
  bash "${ASSEMBLER}" "${ROOT_DIR}/install.sh"
}

prepare_directories() {
  rm -rf "${TEMP_DIR}" "${PAYLOAD_FILE}"
  mkdir -p "${TEMP_DIR}/images" "${TEMP_DIR}/manifests" "${DIST_DIR}"
  : > "${SELECTED_IMAGE_ITEMS_FILE}"
}

profile_needs_image_tag() {
  local image_tag="$1"

  case "${PROFILE}" in
    integrated)
      return 0
      ;;
    backup-restore)
      [[ "${image_tag}" == */mysql:* || "${image_tag}" == */minio-mc:* ]]
      return
      ;;
    benchmark)
      [[ "${image_tag}" == */mysql:* || "${image_tag}" == */sysbench:* ]]
      return
      ;;
    monitoring)
      [[ "${image_tag}" == */mysql:* || "${image_tag}" == */mysqld-exporter:* ]]
      return
      ;;
  esac

  return 1
}

profile_needs_manifest() {
  local manifest_name="$1"

  case "${PROFILE}" in
    integrated)
      return 0
      ;;
    backup-restore)
      case "${manifest_name}" in
        mysql-backup-support.yaml|mysql-backup.yaml|mysql-backup-job.yaml|mysql-restore-job.yaml)
          return 0
          ;;
      esac
      ;;
    benchmark)
      [[ "${manifest_name}" == "mysql-benchmark-job.yaml" ]]
      return
      ;;
    monitoring)
      [[ "${manifest_name}" == "mysql-addon-monitoring.yaml" ]]
      return
      ;;
  esac

  return 1
}

prepare_images() {
  local count=0
  while IFS= read -r item; do
    [[ -n "${item}" ]] || continue

    local pull tag tar_name platform dockerfile
    pull="$(jq -r '.pull // empty' <<<"${item}")"
    tag="$(jq -r '.tag // .pull' <<<"${item}")"
    tar_name="$(jq -r '.tar' <<<"${item}")"
    platform="$(jq -r '.platform // empty' <<<"${item}")"
    dockerfile="$(jq -r '.dockerfile // empty' <<<"${item}")"
    [[ -n "${platform}" ]] || platform="${PLATFORM}"

    profile_needs_image_tag "${tag}" || continue

    if [[ -n "${dockerfile}" ]]; then
      if docker buildx version >/dev/null 2>&1; then
        log "Build ${dockerfile} -> ${tag} (${platform}) via buildx"
        docker buildx build --load --platform "${platform}" -t "${tag}" -f "${ROOT_DIR}/${dockerfile}" "${ROOT_DIR}"
      else
        if [[ "${platform}" != "${PLATFORM}" ]]; then
          die "Image ${tag} requires ${platform}, but docker buildx is unavailable on this host"
        fi
        log "Build ${dockerfile} -> ${tag} (${platform})"
        docker build -t "${tag}" -f "${ROOT_DIR}/${dockerfile}" "${ROOT_DIR}"
      fi
    else
      log "Pull ${pull} (${platform})"
      docker pull --platform "${platform}" "${pull}"

      if [[ "${pull}" != "${tag}" ]]; then
        log "Tag ${pull} -> ${tag}"
        docker tag "${pull}" "${tag}"
      fi
    fi

    log "Save ${tag} -> ${TEMP_DIR}/images/${tar_name}"
    docker save -o "${TEMP_DIR}/images/${tar_name}" "${tag}"
    printf '%s\n' "${item}" >> "${SELECTED_IMAGE_ITEMS_FILE}"
    count=$((count + 1))
  done < <(jq -c --arg arch "${ARCH}" '.[] | select(.arch == $arch)' "${IMAGE_JSON}")

  (( count > 0 )) || die "No image definition found for arch=${ARCH}, profile=${PROFILE}"
  success "Prepared ${count} image(s) for arch=${ARCH}, profile=${PROFILE}"
}

package_payload() {
  local manifest_path manifest_name

  log "Packaging manifests and images for profile=${PROFILE}"
  for manifest_path in "${MANIFESTS_DIR}"/*; do
    [[ -f "${manifest_path}" ]] || continue
    manifest_name="$(basename "${manifest_path}")"
    profile_needs_manifest "${manifest_name}" || continue
    cp "${manifest_path}" "${TEMP_DIR}/manifests/"
  done

  jq -s '.' "${SELECTED_IMAGE_ITEMS_FILE}" > "${TEMP_DIR}/images/image.json"

  (
    cd "${TEMP_DIR}"
    tar -czf "${PAYLOAD_FILE}" .
  )

  tar -tzf "${PAYLOAD_FILE}" >/dev/null 2>&1 || die "Payload verification failed"
}

prepare_profile_script() {
  local profile_script="${TEMP_DIR}/install-${PROFILE}.sh"
  sed "0,/^PACKAGE_PROFILE=.*$/s//PACKAGE_PROFILE=\"${PROFILE}\"/" "${ROOT_DIR}/install.sh" > "${profile_script}"
  echo "${profile_script}"
}

build_installer() {
  local script_source installer_path
  script_source="$(prepare_profile_script)"
  installer_path="${DIST_DIR}/${INSTALLER_NAME}"
  cat "${script_source}" "${PAYLOAD_FILE}" > "${installer_path}"
  chmod +x "${installer_path}"
  sha256sum "${installer_path}" > "${installer_path}.sha256"
  success "Built ${installer_path}"
  echo "  sha256: ${installer_path}.sha256"
}

cleanup() {
  rm -rf "${TEMP_DIR}" "${PAYLOAD_FILE}" >/dev/null 2>&1 || true
}

build_one() {
  normalize_arch "$1"
  normalize_profile "$2"
  refresh_installer_name

  echo -e "${BOLD}MySQL Offline Installer Builder${NC}"
  echo "  arch: ${ARCH}"
  echo "  platform: ${PLATFORM}"
  echo "  profile: ${PROFILE}"

  prepare_directories
  prepare_images
  package_payload
  build_installer
}

build_matrix() {
  local arch profile
  local -a arches=("${ARCH}")
  local -a profiles=("${PROFILE}")

  if [[ "${BUILD_ALL_ARCH}" == "true" ]]; then
    arches=(amd64 arm64)
  fi

  if [[ "${BUILD_ALL_PROFILES}" == "true" ]]; then
    profiles=(integrated backup-restore benchmark monitoring)
  fi

  for arch in "${arches[@]}"; do
    for profile in "${profiles[@]}"; do
      build_one "${arch}" "${profile}"
    done
  done
}

main() {
  trap cleanup EXIT
  normalize_arch "${ARCH}"
  normalize_profile "${PROFILE}"
  parse_args "$@"
  assemble_installer
  check_requirements
  build_matrix
}

main "$@"

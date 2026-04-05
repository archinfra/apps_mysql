#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_ROOT="${ROOT_DIR}/scripts/install/modules"
OUTPUT_FILE="${1:-${ROOT_DIR}/install.sh}"
TMP_FILE="$(mktemp)"

cleanup() {
  rm -f "${TMP_FILE}" >/dev/null 2>&1 || true
}

trap cleanup EXIT

[[ -d "${MODULE_ROOT}" ]] || {
  echo "module directory not found: ${MODULE_ROOT}" >&2
  exit 1
}

: > "${TMP_FILE}"
while IFS= read -r module_path; do
  [[ -f "${module_path}" ]] || {
    echo "module not found: ${module_path}" >&2
    exit 1
  }
  cat "${module_path}" >> "${TMP_FILE}"
  if [[ "$(tail -c 1 "${module_path}" 2>/dev/null || true)" != $'\n' ]]; then
    printf '\n' >> "${TMP_FILE}"
  fi
  printf '\n' >> "${TMP_FILE}"
done < <(find "${MODULE_ROOT}" -maxdepth 1 -type f -name '*.sh' | LC_ALL=C sort)

mv "${TMP_FILE}" "${OUTPUT_FILE}"
chmod +x "${OUTPUT_FILE}"
trap - EXIT

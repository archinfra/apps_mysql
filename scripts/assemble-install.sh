#!/usr/bin/env bash

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_ROOT="${ROOT_DIR}/scripts/install"
ORDER_FILE="${MODULE_ROOT}/module-order.txt"
OUTPUT_FILE="${1:-${ROOT_DIR}/install.sh}"
TMP_FILE="$(mktemp)"

cleanup() {
  rm -f "${TMP_FILE}" >/dev/null 2>&1 || true
}

trap cleanup EXIT

[[ -f "${ORDER_FILE}" ]] || {
  echo "module order file not found: ${ORDER_FILE}" >&2
  exit 1
}

: > "${TMP_FILE}"
while IFS= read -r relative_path || [[ -n "${relative_path}" ]]; do
  relative_path="${relative_path%$'\r'}"
  [[ -n "${relative_path}" ]] || continue
  module_path="${MODULE_ROOT}/${relative_path}"
  [[ -f "${module_path}" ]] || {
    echo "module not found: ${module_path}" >&2
    exit 1
  }
  cat "${module_path}" >> "${TMP_FILE}"
  if [[ "$(tail -c 1 "${module_path}" 2>/dev/null || true)" != $'\n' ]]; then
    printf '\n' >> "${TMP_FILE}"
  fi
done < "${ORDER_FILE}"

mv "${TMP_FILE}" "${OUTPUT_FILE}"
chmod +x "${OUTPUT_FILE}"
trap - EXIT

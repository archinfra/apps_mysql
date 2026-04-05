write_report() {
  local report_name="$1"
  local body="$2"
  ensure_report_dir
  local report_path="${REPORT_DIR}/${report_name}"
  printf '%s\n' "${body}" > "${report_path}"
  echo "${report_path}"
}


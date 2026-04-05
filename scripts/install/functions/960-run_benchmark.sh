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
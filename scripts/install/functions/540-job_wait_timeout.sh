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
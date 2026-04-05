stop_background_task() {
  local task_pid="${1:-}"
  if [[ -n "${task_pid}" ]] && kill -0 "${task_pid}" >/dev/null 2>&1; then
    kill "${task_pid}" >/dev/null 2>&1 || true
    wait "${task_pid}" >/dev/null 2>&1 || true
  fi
}


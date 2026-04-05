normalize_addons() {
  local raw="${ADDONS:-}"
  local normalized=()
  local item trimmed

  [[ -n "${raw}" ]] || die "动作 ${ACTION} 需要提供 --addons，示例: --addons monitoring,backup"

  if [[ "${raw}" == "all" ]]; then
    raw="monitoring,service-monitor,backup"
  fi

  IFS=',' read -r -a items <<<"${raw}"
  for item in "${items[@]}"; do
    trimmed="$(echo "${item}" | awk '{$1=$1; print}')"
    [[ -n "${trimmed}" ]] || continue

    case "${trimmed}" in
      monitoring|service-monitor|backup)
        local exists="false"
        local current
        for current in "${normalized[@]}"; do
          if [[ "${current}" == "${trimmed}" ]]; then
            exists="true"
            break
          fi
        done
        [[ "${exists}" == "true" ]] || normalized+=("${trimmed}")
        ;;
      *)
        die "不支持的 addon: ${trimmed}，当前仅支持 monitoring, service-monitor, backup"
        ;;
    esac
  done

  (( ${#normalized[@]} > 0 )) || die "--addons 未提供有效内容"
  ADDONS="$(IFS=,; echo "${normalized[*]}")"
}


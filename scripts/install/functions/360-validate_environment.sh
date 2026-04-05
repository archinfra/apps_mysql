validate_environment() {
  command -v kubectl >/dev/null 2>&1 || die "未找到 kubectl"

  if action_needs_image_prepare && [[ "${SKIP_IMAGE_PREPARE}" != "true" ]]; then
    command -v docker >/dev/null 2>&1 || die "未找到 docker"
    command -v jq >/dev/null 2>&1 || die "未找到 jq"
  fi
}


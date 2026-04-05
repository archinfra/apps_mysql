render_manifest() {
  local file_path="$1"
  render_feature_blocks "${file_path}" | template_replace
}


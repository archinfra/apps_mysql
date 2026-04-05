render_optional_block() {
  local feature_name="$1"
  local enabled="$2"

  awk \
    -v start_marker="#__${feature_name}_START__" \
    -v end_marker="#__${feature_name}_END__" \
    -v enabled="${enabled}" '
      {
        marker=$0
        sub(/^[[:space:]]+/, "", marker)
      }
      marker == start_marker { skip=(enabled != "true"); next }
      marker == end_marker { skip=0; next }
      !skip { print }
    '
}


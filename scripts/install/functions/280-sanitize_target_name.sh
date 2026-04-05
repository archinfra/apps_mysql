sanitize_target_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.-]/-/g; s/\.\+/-/g; s/--\+/-/g; s/^-//; s/-$//'
}


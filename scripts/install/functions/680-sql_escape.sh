sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}


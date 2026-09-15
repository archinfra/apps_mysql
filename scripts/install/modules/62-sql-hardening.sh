# SQL literal escaping override loaded after 60-runtime.sh.

sql_escape() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e "s/'/''/g"
}

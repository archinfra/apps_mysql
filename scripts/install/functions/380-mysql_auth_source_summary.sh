mysql_auth_source_summary() {
  if [[ -n "${MYSQL_PASSWORD}" ]]; then
    echo "显式密码参数"
  else
    echo "Secret/${MYSQL_AUTH_SECRET}:${MYSQL_PASSWORD_KEY}"
  fi
}


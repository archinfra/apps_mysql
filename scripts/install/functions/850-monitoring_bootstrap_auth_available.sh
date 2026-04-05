monitoring_bootstrap_auth_available() {
  if [[ -n "${MYSQL_PASSWORD}" ]]; then
    return 0
  fi

  secret_has_key "${MYSQL_AUTH_SECRET}" "${MYSQL_PASSWORD_KEY}"
}


current_mysql_password() {
  if [[ -n "${MYSQL_PASSWORD}" ]]; then
    printf '%s' "${MYSQL_PASSWORD}"
    return 0
  fi

  kubectl get secret -n "${NAMESPACE}" "${MYSQL_AUTH_SECRET}" -o "jsonpath={.data.${MYSQL_PASSWORD_KEY}}" | base64 -d
}


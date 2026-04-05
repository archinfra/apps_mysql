needs_backup_storage() {
  if [[ "${ACTION}" == "addon-install" ]]; then
    addon_selected backup && return 0
    return 1
  fi

  case "${ACTION}" in
    install)
      [[ "${BACKUP_ENABLED}" == "true" ]]
      ;;
    backup|restore|verify-backup-restore)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}


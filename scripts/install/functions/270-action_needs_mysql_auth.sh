action_needs_mysql_auth() {
  case "${ACTION}" in
    backup|restore|verify-backup-restore|benchmark)
      return 0
      ;;
    addon-install)
      addon_selected backup && return 0
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}


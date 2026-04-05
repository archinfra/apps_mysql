backup_schedule_required() {
  [[ "${ACTION}" == "install" && "${BACKUP_ENABLED}" == "true" ]] && return 0
  [[ "${ACTION}" == "addon-install" ]] && addon_selected backup && return 0
  return 1
}


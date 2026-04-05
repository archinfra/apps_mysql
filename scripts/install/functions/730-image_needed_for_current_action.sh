image_needed_for_current_action() {
  local image_tag="$1"

  case "${ACTION}" in
    install)
      return 0
      ;;
    addon-install)
      if addon_selected monitoring && [[ "${image_tag}" == */mysqld-exporter:* ]]; then
        return 0
      fi
      if addon_selected backup && [[ "${image_tag}" == */mysql:* ]]; then
        return 0
      fi
      if addon_selected backup && backup_backend_is_s3 && [[ "${image_tag}" == */minio-mc:* ]]; then
        return 0
      fi
      return 1
      ;;
    backup|restore|verify-backup-restore)
      if [[ "${image_tag}" == */mysql:* ]]; then
        return 0
      fi
      if backup_backend_is_s3 && [[ "${image_tag}" == */minio-mc:* ]]; then
        return 0
      fi
      return 1
      ;;
    benchmark)
      if [[ "${image_tag}" == */mysql:* || "${image_tag}" == */sysbench:* ]]; then
        return 0
      fi
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}


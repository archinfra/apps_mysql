action_needs_image_prepare() {
  case "${ACTION}" in
    install|addon-install|backup|restore|verify-backup-restore|benchmark)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}


main() {
  trap cleanup EXIT

  parse_args "$@"

  banner
  if [[ "${ACTION}" == "help" ]]; then
    show_help
    exit 0
  fi

  resolve_feature_dependencies
  prompt_missing_values
  validate_environment
  validate_inputs
  prepare_runtime_auth_secret

  if [[ "${ACTION}" != "status" && "${ACTION}" != "addon-status" ]]; then
    confirm_plan
  fi

  case "${ACTION}" in
    install)
      install_app
      show_post_install_notes
      ;;
    addon-install)
      install_addons
      show_post_addon_notes
      ;;
    addon-uninstall)
      uninstall_addons
      ;;
    addon-status)
      show_addon_status
      ;;
    uninstall)
      uninstall_app
      ;;
    status)
      show_status
      ;;
    backup)
      run_backup
      ;;
    restore)
      run_restore
      ;;
    verify-backup-restore)
      verify_backup_restore
      ;;
    benchmark)
      run_benchmark
      ;;
    *)
      die "不支持的动作: ${ACTION}"
      ;;
  esac
}

package_profile_label() {
  case "${PACKAGE_PROFILE}" in
    integrated)
      echo "integrated"
      ;;
    benchmark)
      echo "benchmark"
      ;;
    monitoring)
      echo "monitoring"
      ;;
    *)
      echo "${PACKAGE_PROFILE}"
      ;;
  esac
}


package_profile_supports_action() {
  local action_name="$1"

  case "${PACKAGE_PROFILE}" in
    integrated)
      case "${action_name}" in
        install|uninstall|status|addon-install|addon-uninstall|addon-status|benchmark|help)
          return 0
          ;;
      esac
      ;;
    benchmark)
      case "${action_name}" in
        help|benchmark)
          return 0
          ;;
      esac
      ;;
    monitoring)
      case "${action_name}" in
        help|status|addon-install|addon-uninstall|addon-status)
          return 0
          ;;
      esac
      ;;
    *)
      die "未知 package profile: ${PACKAGE_PROFILE}"
      ;;
  esac

  return 1
}


package_profile_supports_addon() {
  local addon_name="$1"

  case "${PACKAGE_PROFILE}" in
    integrated|monitoring)
      case "${addon_name}" in
        monitoring|service-monitor)
          return 0
          ;;
      esac
      ;;
  esac

  return 1
}


package_profile_supported_actions_text() {
  case "${PACKAGE_PROFILE}" in
    integrated)
      echo "install uninstall status addon-install addon-uninstall addon-status benchmark help"
      ;;
    benchmark)
      echo "benchmark help"
      ;;
    monitoring)
      echo "status addon-install addon-uninstall addon-status help"
      ;;
  esac
}

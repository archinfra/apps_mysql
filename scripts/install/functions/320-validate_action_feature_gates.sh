validate_action_feature_gates() {
  case "${ACTION}" in
    addon-install|addon-uninstall)
      [[ -n "${ADDONS}" ]] || die "动作 ${ACTION} 需要提供 --addons"
      ;;
  esac
}


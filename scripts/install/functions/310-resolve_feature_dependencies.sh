resolve_feature_dependencies() {
  resolve_mysql_target_defaults

  if [[ "${MONITORING_ENABLED}" != "true" && "${SERVICE_MONITOR_ENABLED}" == "true" ]]; then
    warn "monitoring 已关闭，因此自动关闭 ServiceMonitor"
    SERVICE_MONITOR_ENABLED="false"
  fi

  if [[ "${ACTION}" == "addon-install" || "${ACTION}" == "addon-uninstall" ]]; then
    normalize_addons
    SERVICE_MONITOR_ENABLED="false"

    if addon_selected service-monitor && ! addon_selected monitoring && [[ "${ACTION}" == "addon-install" ]]; then
      warn "service-monitor 依赖 monitoring，已自动补齐 monitoring"
      ADDONS="monitoring,${ADDONS}"
      normalize_addons
    fi

    if addon_selected monitoring && ! addon_selected service-monitor && [[ "${ACTION}" == "addon-uninstall" ]]; then
      ADDONS="${ADDONS},service-monitor"
      normalize_addons
    fi

    if addon_selected service-monitor; then
      SERVICE_MONITOR_ENABLED="true"
    fi
  fi
}


# Canonical MySQL delivery resource profiles. Loaded after 40-inputs-and-plan.sh.

set_profile_mysql_resource_default() {
  local value_var="$1"
  local explicit_var="$2"
  local default_value="$3"

  if [[ "${!explicit_var}" != "true" ]]; then
    printf -v "${value_var}" '%s' "${default_value}"
  fi
}


apply_resource_profile() {
  # STORAGE_SIZE starts empty unless --storage-size was supplied. This keeps the
  # profile as the default source while still allowing an explicit PVC override.
  if [[ -n "${STORAGE_SIZE}" ]]; then
    STORAGE_SIZE_EXPLICIT="true"
  fi

  case "${RESOURCE_PROFILE,,}" in
    lite|small|compact|low)
      RESOURCE_PROFILE="lite"
      set_profile_mysql_resource_default MYSQL_REQUEST_CPU MYSQL_REQUEST_CPU_EXPLICIT "500m"
      set_profile_mysql_resource_default MYSQL_REQUEST_MEM MYSQL_REQUEST_MEM_EXPLICIT "1Gi"
      set_profile_mysql_resource_default MYSQL_LIMIT_CPU MYSQL_LIMIT_CPU_EXPLICIT "1"
      set_profile_mysql_resource_default MYSQL_LIMIT_MEM MYSQL_LIMIT_MEM_EXPLICIT "2Gi"
      MYSQL_EXPORTER_REQUEST_CPU="50m"
      MYSQL_EXPORTER_REQUEST_MEM="64Mi"
      MYSQL_EXPORTER_LIMIT_CPU="100m"
      MYSQL_EXPORTER_LIMIT_MEM="128Mi"
      FLUENTBIT_REQUEST_CPU="50m"
      FLUENTBIT_REQUEST_MEM="64Mi"
      FLUENTBIT_LIMIT_CPU="100m"
      FLUENTBIT_LIMIT_MEM="128Mi"
      MYSQL_INIT_REQUEST_CPU="20m"
      MYSQL_INIT_REQUEST_MEM="32Mi"
      MYSQL_INIT_LIMIT_CPU="100m"
      MYSQL_INIT_LIMIT_MEM="64Mi"
      if [[ "${MYSQL_INNODB_BUFFER_POOL_SIZE_EXPLICIT}" != "true" ]]; then
        MYSQL_INNODB_BUFFER_POOL_SIZE="1G"
      fi
      if [[ "${STORAGE_SIZE_EXPLICIT}" != "true" ]]; then
        STORAGE_SIZE="20Gi"
      fi
      ;;
    standard|mid|midd|middle|medium)
      RESOURCE_PROFILE="standard"
      set_profile_mysql_resource_default MYSQL_REQUEST_CPU MYSQL_REQUEST_CPU_EXPLICIT "1"
      set_profile_mysql_resource_default MYSQL_REQUEST_MEM MYSQL_REQUEST_MEM_EXPLICIT "4Gi"
      set_profile_mysql_resource_default MYSQL_LIMIT_CPU MYSQL_LIMIT_CPU_EXPLICIT "2"
      set_profile_mysql_resource_default MYSQL_LIMIT_MEM MYSQL_LIMIT_MEM_EXPLICIT "8Gi"
      MYSQL_EXPORTER_REQUEST_CPU="100m"
      MYSQL_EXPORTER_REQUEST_MEM="128Mi"
      MYSQL_EXPORTER_LIMIT_CPU="200m"
      MYSQL_EXPORTER_LIMIT_MEM="256Mi"
      FLUENTBIT_REQUEST_CPU="100m"
      FLUENTBIT_REQUEST_MEM="128Mi"
      FLUENTBIT_LIMIT_CPU="200m"
      FLUENTBIT_LIMIT_MEM="256Mi"
      MYSQL_INIT_REQUEST_CPU="50m"
      MYSQL_INIT_REQUEST_MEM="64Mi"
      MYSQL_INIT_LIMIT_CPU="200m"
      MYSQL_INIT_LIMIT_MEM="128Mi"
      if [[ "${MYSQL_INNODB_BUFFER_POOL_SIZE_EXPLICIT}" != "true" ]]; then
        MYSQL_INNODB_BUFFER_POOL_SIZE="5G"
      fi
      if [[ "${STORAGE_SIZE_EXPLICIT}" != "true" ]]; then
        STORAGE_SIZE="100Gi"
      fi
      ;;
    large|high)
      RESOURCE_PROFILE="large"
      set_profile_mysql_resource_default MYSQL_REQUEST_CPU MYSQL_REQUEST_CPU_EXPLICIT "2"
      set_profile_mysql_resource_default MYSQL_REQUEST_MEM MYSQL_REQUEST_MEM_EXPLICIT "8Gi"
      set_profile_mysql_resource_default MYSQL_LIMIT_CPU MYSQL_LIMIT_CPU_EXPLICIT "4"
      set_profile_mysql_resource_default MYSQL_LIMIT_MEM MYSQL_LIMIT_MEM_EXPLICIT "16Gi"
      MYSQL_EXPORTER_REQUEST_CPU="200m"
      MYSQL_EXPORTER_REQUEST_MEM="256Mi"
      MYSQL_EXPORTER_LIMIT_CPU="500m"
      MYSQL_EXPORTER_LIMIT_MEM="512Mi"
      FLUENTBIT_REQUEST_CPU="200m"
      FLUENTBIT_REQUEST_MEM="256Mi"
      FLUENTBIT_LIMIT_CPU="500m"
      FLUENTBIT_LIMIT_MEM="512Mi"
      MYSQL_INIT_REQUEST_CPU="100m"
      MYSQL_INIT_REQUEST_MEM="128Mi"
      MYSQL_INIT_LIMIT_CPU="300m"
      MYSQL_INIT_LIMIT_MEM="256Mi"
      if [[ "${MYSQL_INNODB_BUFFER_POOL_SIZE_EXPLICIT}" != "true" ]]; then
        MYSQL_INNODB_BUFFER_POOL_SIZE="10G"
      fi
      if [[ "${STORAGE_SIZE_EXPLICIT}" != "true" ]]; then
        STORAGE_SIZE="500Gi"
      fi
      ;;
    *)
      die "resource-profile 仅支持 lite|standard|large；兼容别名: low->lite, mid/midd/medium->standard, high->large"
      ;;
  esac

  # Existing persistent data must not be silently resized just because the
  # installer default/profile changed. Explicit --storage-size is required.
  if [[ "${ACTION}" == "install" && "${STORAGE_SIZE_EXPLICIT}" != "true" ]]; then
    local pvc_name existing_pvc_size
    pvc_name="data-${STS_NAME}-0"
    existing_pvc_size="$(kubectl get pvc -n "${NAMESPACE}" "${pvc_name}" -o 'jsonpath={.spec.resources.requests.storage}' 2>/dev/null || true)"
    if [[ -n "${existing_pvc_size}" && "${existing_pvc_size}" != "${STORAGE_SIZE}" ]]; then
      warn "检测到现有 PVC/${pvc_name}=${existing_pvc_size}；不会因 resource-profile 自动改盘，继续保留现有容量。需要扩容请显式传 --storage-size。"
      STORAGE_SIZE="${existing_pvc_size}"
    fi
  fi
}

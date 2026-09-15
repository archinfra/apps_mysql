# Resource-plan confirmation details loaded after profile resolution.

confirm_plan() {
  [[ "${AUTO_YES}" == "true" ]] && return 0

  print_plan

  if [[ "${ACTION}" == "install" ]]; then
    echo
    echo "资源规格摘要:"
    echo "  MySQL request          : ${MYSQL_REQUEST_CPU} CPU / ${MYSQL_REQUEST_MEM} memory"
    echo "  MySQL limit            : ${MYSQL_LIMIT_CPU} CPU / ${MYSQL_LIMIT_MEM} memory"
    echo "  InnoDB Buffer Pool     : ${MYSQL_INNODB_BUFFER_POOL_SIZE}"
    echo "  PVC request            : ${STORAGE_SIZE}"
    echo "  StorageClass           : ${STORAGE_CLASS}"
    if [[ "${STORAGE_SIZE_EXPLICIT}" == "true" ]]; then
      echo "  PVC size source        : --storage-size 显式覆盖"
    else
      echo "  PVC size source        : resource-profile / 已有 PVC 保留值"
    fi
  fi

  echo
  echo -ne "${YELLOW}确认继续执行？[y/N]:${NC} "
  read -r answer
  [[ "${answer}" =~ ^[Yy]$ ]] || die "用户取消执行"
}

prompt_missing_values() {
  if needs_backup_storage && backup_backend_is_nfs && [[ -z "${BACKUP_NFS_SERVER}" ]]; then
    echo -ne "${YELLOW}请输入 NFS 服务器地址:${NC} "
    read -r BACKUP_NFS_SERVER
  fi

  if needs_backup_storage && backup_backend_is_s3; then
    if [[ -z "${S3_ENDPOINT}" ]]; then
      echo -ne "${YELLOW}请输入 S3 Endpoint（如 https://minio.example.com）:${NC} "
      read -r S3_ENDPOINT
    fi
    if [[ -z "${S3_BUCKET}" ]]; then
      echo -ne "${YELLOW}请输入 S3 Bucket:${NC} "
      read -r S3_BUCKET
    fi
    if [[ -z "${S3_ACCESS_KEY}" ]]; then
      echo -ne "${YELLOW}请输入 S3 Access Key:${NC} "
      read -r S3_ACCESS_KEY
    fi
    if [[ -z "${S3_SECRET_KEY}" ]]; then
      echo -ne "${YELLOW}请输入 S3 Secret Key:${NC} "
      read -rs S3_SECRET_KEY
      echo
    fi
  fi

  [[ -n "${BACKUP_NFS_PATH}" ]] || BACKUP_NFS_PATH="/data/nfs-share"
}


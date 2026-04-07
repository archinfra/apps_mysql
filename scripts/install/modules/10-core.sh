log() {
  echo -e "${CYAN}[INFO]${NC} $*"
}


success() {
  echo -e "${GREEN}[OK]${NC} $*"
}


warn() {
  echo -e "${YELLOW}[WARN]${NC} $*" >&2
}


die() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
  exit 1
}


section() {
  echo
  echo -e "${BLUE}${BOLD}============================================================${NC}"
  echo -e "${BLUE}${BOLD}$*${NC}"
  echo -e "${BLUE}${BOLD}============================================================${NC}"
}


banner() {
  echo
  echo -e "${GREEN}${BOLD}MySQL 离线安装器${NC}"
  echo -e "${CYAN}版本: ${APP_VERSION}${NC}"
  echo -e "${CYAN}产物包: $(package_profile_label)${NC}"
}


backup_backend_is_nfs() {
  [[ "${BACKUP_BACKEND}" == "nfs" ]]
}


backup_backend_is_s3() {
  [[ "${BACKUP_BACKEND}" == "s3" ]]
}


program_name() {
  basename "$0"
}


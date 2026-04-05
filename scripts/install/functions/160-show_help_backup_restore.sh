show_help_backup_restore() {
  cat <<'EOF'
备份原理:
  1. 连接目标 MySQL 并探测可用性
  2. 枚举用户库，排除系统库
  3. 执行 mysqldump，生成 gzip、sha256 和 meta
  4. 更新 latest.txt，并按 retention 清理旧快照

恢复原理:
  1. 定位快照
  2. 校验 sha256
  3. 按 restore-mode 决定是否先清空用户库
  4. gunzip 后通过 mysql 客户端导入

业务影响:
  1. backup 不要求停业务。
  2. restore 不会主动停库，但会修改目标数据，建议维护窗口执行。
EOF
}


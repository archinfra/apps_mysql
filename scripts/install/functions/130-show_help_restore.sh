show_help_restore() {
  cat <<'EOF'
restore 用于从备份快照恢复 MySQL。

常用参数:
  --mysql-host <host>
  --mysql-port <port>               默认: 3306
  --mysql-user <user>               默认: root
  --mysql-password <password>       推荐显式传入
  --mysql-auth-secret <name>        使用已有 Secret
  --mysql-password-key <key>        Secret 中密码键名
  --mysql-target-name <name>        备份目录中的逻辑实例名
  --restore-snapshot <name|latest>  默认: latest
  --mysql-restore-mode merge|replace 默认: merge

说明:
  1. latest 会优先读取 latest.txt
  2. 如果 latest.txt 指向的快照已不存在，会自动回退到最新的 .sql.gz
  3. restore 会直接向目标实例导入 SQL，请在维护窗口执行
EOF
}

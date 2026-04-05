show_help_overview() {
  cat <<'EOF'
用法:
  ./mysql-installer.run <动作> [参数]
  ./mysql-installer.run help [主题]

动作:
  install                 安装或整套对齐 MySQL 及内嵌能力
  uninstall               卸载资源，默认保留 PVC
  status                  查看当前资源状态
  addon-install           给已有 MySQL 单独补齐外置能力
  addon-uninstall         单独移除外置能力
  addon-status            查看 addon 状态与影响边界
  backup                  立即执行一次备份 Job
  restore                 立即执行一次恢复 Job
  verify-backup-restore   执行备份/恢复闭环校验
  benchmark               执行工程化压测
  help                    查看中文帮助

help 主题:
  overview
  install
  addons
  backup
  restore
  benchmark
  params
  backup-restore
  logging
  architecture
  examples

关键设计:
  1. install 是“整套声明式对齐”，不是一次性初始化脚本。
  2. addon-install 面向“已有 MySQL 补能力”，尽量只新增资源，不改 MySQL StatefulSet。
  3. backup 是“立刻备份一次”，addon-install --addons backup 才是“安装定时备份组件”。
  4. 日志默认推荐平台层 DaemonSet Fluent Bit + ES/OpenSearch/Loki。
EOF
}


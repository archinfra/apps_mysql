show_help_overview() {
  local cmd="./$(program_name)"
  local supported_actions
  supported_actions="$(package_profile_supported_actions_text)"

  cat <<EOF
用法:
  ${cmd} <动作> [参数]
  ${cmd} help [主题]

当前产物包:
  $(package_profile_label)

当前包可用动作:
  ${supported_actions}

动作说明:
  install                 整体安装或对齐 MySQL 本体与内置能力
  uninstall               卸载集成包创建的资源，默认保留 PVC 与 root Secret
  status                  查看当前资源状态
  addon-install           给已有 MySQL 补充外围监控能力
  addon-uninstall         单独移除外围监控能力
  addon-status            查看 addon 状态与影响边界
  benchmark               执行压测 Job 并输出报告
  help                    查看中文帮助

help 主题:
  overview
  install
  addons
  benchmark
  params
  packages
  logging
  architecture
  examples

关键说明:
  1. 当前 MySQL 基线为 8.4.11 LTS，单实例、单副本。
  2. resource-profile 统一只使用 lite / standard / large，默认 standard。
  3. NodePort 默认关闭；远程 root、监控、日志等详细交付参数请看 help install。
  4. 默认日志进入容器 stdout/stderr，便于 kubectl logs 与平台日志采集共存。
  5. 备份恢复由独立数据保护系统执行，apps_mysql 仅保留接入协议。
EOF
}


show_help_addons() {
  local cmd="./mysql-monitoring-<arch>.run"

  cat <<EOF
addon-install / addon-uninstall / addon-status 面向“已有 MySQL 补监控能力”。

支持的 addon:
  monitoring
    外置 mysqld-exporter Deployment + Service
    默认新增独立 Pod，不修改 MySQL StatefulSet

  service-monitor
    创建 ServiceMonitor 声明
    自动依赖 monitoring

addon 参数:
  --addons <list>                   必填，逗号分隔: monitoring,service-monitor
  --monitoring-target <host:port>   监控目标地址；已有外部 MySQL 时建议显式指定
  --mysql-host <host>               可作为 monitoring-target 的简化来源
  --mysql-port <port>               默认: 3306
  --exporter-user <user>            默认: mysqld_exporter
  --exporter-password <password>    不传则自动生成随机密码

说明:
  1. addon-install 默认不修改 MySQL StatefulSet。
  2. logging 不作为 addon 提供；如需 sidecar，请走 integrated install。
  3. exporter 使用独立低权限账号，不使用 root。

示例:
  ${cmd} addon-install \
    --namespace mysql-demo \
    --addons monitoring,service-monitor \
    --monitoring-target 10.0.0.20:3306 \
    -y
EOF
}


show_help_benchmark() {
  local cmd="./mysql-benchmark-<arch>.run"

  cat <<EOF
benchmark 会创建一次性 Job，对目标 MySQL 执行 sysbench 压测。

常用参数:
  --mysql-host <host>
  --mysql-port <port>                    默认: 3306
  --mysql-user <user>                    默认: root
  --mysql-password <password>            推荐显式传入
  --mysql-auth-secret <name>             使用已有 Secret
  --mysql-password-key <key>             Secret 中密码键名
  --benchmark-profile <name>             默认: standard
  --benchmark-threads <num>              默认: 32
  --benchmark-time <sec>                 默认: 180
  --benchmark-warmup-time <sec>          默认: 30
  --benchmark-warmup-rows <rows>         默认: 10000
  --benchmark-tables <num>               默认: 8
  --benchmark-table-size <rows>          默认: 100000
  --benchmark-db <name>                  默认: sbtest
  --benchmark-rand-type <name>           默认: uniform
  --benchmark-keep-data true|false       默认: false
  --report-dir <dir>                     默认: ./reports

输出:
  1. 完整 job 日志 .log
  2. 文本报告 .txt
  3. 结构化报告 .json

说明:
  1. benchmark 只创建 Job，不会改动 StatefulSet。
  2. 当前会自动兼容不支持 --warmup-time 的 sysbench 版本。

示例:
  ${cmd} benchmark \
    --namespace mysql-demo \
    --mysql-host 10.0.0.20 \
    --mysql-user root \
    --mysql-password '<MYSQL_PASSWORD>' \
    --benchmark-profile oltp-read-write \
    --benchmark-threads 64 \
    --benchmark-time 300 \
    --report-dir ./reports \
    -y
EOF
}


show_help_packages() {
  cat <<'EOF'
当前会构建三类产物:

  mysql-installer-<arch>.run
    集成包
    支持 install / uninstall / status / addon / benchmark

  mysql-benchmark-<arch>.run
    压测能力包
    只保留 benchmark 所需镜像、manifest 与动作

  mysql-monitoring-<arch>.run
    监控能力包
    支持 monitoring / service-monitor 的 addon 安装与卸载

设计目标:
  1. 保留 integrated 包，继续服务离线整体交付
  2. 抽出 benchmark / monitoring，降低非目标场景的使用成本
  3. 备份恢复由独立数据保护系统负责，apps_mysql 不重复承载
EOF
}


show_help_logging() {
  cat <<'EOF'
日志能力分两层：

默认行为:
  1. MySQL error log / slow log 写入 /var/log/mysql
  2. error log 会进入 mysql 容器 stderr
  3. 未启用 Fluent Bit 时 slow log 会进入 mysql 容器 stdout
  4. /var/log/mysql 使用带 sizeLimit 的 emptyDir，默认 2Gi

启用 --enable-fluentbit 后:
  1. error log 仍进入 mysql 容器 stderr
  2. slow log 由 fluent-bit sidecar tail 并输出
  3. 适合必须消费文件型慢日志的场景

当前推荐:
  1. 已有平台 Fluent Bit/Fluentd/Vector 时，优先直接采容器 stdout/stderr
  2. 只有明确需要 Pod 内 slow log 文件时，再启用 --enable-fluentbit
  3. Pod 文件系统不是长期日志归档介质
EOF
}


show_help_architecture() {
  cat <<'EOF'
能力分层:
  integrated
    MySQL 8.4.11 本体、StatefulSet、Service、PVC、内嵌监控与日志
  benchmark
    标准化 sysbench 压测与报告输出
  monitoring
    外置 exporter / ServiceMonitor / Dashboard / Alert

源码结构:
  scripts/install/modules/*.sh
    安装器模块源码入口

  scripts/assemble-install.sh
    组装 install.sh

  build.sh
    根据 --profile 与 --arch 产出不同离线包

交付资源规格:
  lite / standard / large
  三种名称是唯一正式口径，不维护第二套别名。
EOF
}


show_help() {
  case "${HELP_TOPIC}" in
    overview)
      show_help_overview
      ;;
    install)
      show_help_install
      ;;
    addons)
      show_help_addons
      ;;
    benchmark)
      show_help_benchmark
      ;;
    params)
      show_help_params
      ;;
    packages)
      show_help_packages
      ;;
    logging)
      show_help_logging
      ;;
    architecture)
      show_help_architecture
      ;;
    examples)
      show_help_examples
      ;;
    *)
      die "未知 help 主题: ${HELP_TOPIC}。可用主题: overview, install, addons, benchmark, params, packages, logging, architecture, examples"
      ;;
  esac
}

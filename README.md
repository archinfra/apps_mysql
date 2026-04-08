# apps_mysql

面向 Kubernetes 的 MySQL 离线交付与运维工具包。
当前版本：`v1.5.6`

从这一版开始，`apps_mysql` 明确只保留三类能力：
- MySQL 安装与对齐
- 监控补装
- 压测

备份恢复已经迁移到独立数据保护系统，不再由 `apps_mysql` 的安装器承载。

## 1. 产物形态

当前构建会产出三类 `.run` 包：

- `mysql-installer-<arch>.run`
- `mysql-benchmark-<arch>.run`
- `mysql-monitoring-<arch>.run`

它们共用同一套模块和 manifest，但会按职责裁剪镜像、动作和帮助信息。

## 2. 能力边界

### 2.1 `mysql-installer-<arch>.run`

适合：
- 首次离线安装 MySQL
- 对齐 StatefulSet / Service / PVC
- 决定是否内嵌 exporter、ServiceMonitor、Fluent Bit sidecar

支持动作：
- `install`
- `uninstall`
- `status`
- `addon-install`
- `addon-uninstall`
- `addon-status`
- `benchmark`
- `help`

### 2.2 `mysql-monitoring-<arch>.run`

适合：
- 已有 MySQL，只补监控
- 不希望因为补监控而改动 MySQL StatefulSet

支持动作：
- `status`
- `addon-install`
- `addon-uninstall`
- `addon-status`
- `help`

### 2.3 `mysql-benchmark-<arch>.run`

适合：
- 只想对某个 MySQL 做标准化压测
- 不想携带安装和监控逻辑

支持动作：
- `benchmark`
- `help`

## 3. 备份恢复边界

`apps_mysql` 不再提供：
- `backup`
- `restore`
- `verify-backup-restore`
- `backup addon`
- `backup plan file`

这部分已经迁移到独立数据保护系统，你后续应通过独立仓库和独立产物来管理备份恢复，而不是继续从 MySQL 安装器里打开相关能力。

## 4. 日志设计

这次日志行为做了收口，目标是同时满足：
- 可以直接 `kubectl logs`
- 可以被平台日志系统采集
- 必要时仍能接 fluent-bit sidecar

默认行为：
- MySQL 错误日志写到容器 `stderr`
- slow log 写到容器 `stdout`
- 因此默认就能用 `kubectl logs -c mysql`

启用 `--enable-fluentbit` 后：
- MySQL 错误日志仍保留在 `mysql` 容器 `stderr`
- slow log 改写到文件
- `fluent-bit` sidecar 负责把 slow log 转发到自己的 `stdout`

这意味着：
- 看错误和常规日志：`kubectl logs -n <ns> <pod> -c mysql`
- 看 sidecar 转发的慢日志：`kubectl logs -n <ns> <pod> -c fluent-bit`

推荐做法：
- 平台已经有 DaemonSet Fluent Bit/Fluentd/Vector 时，优先直接采容器 `stdout/stderr`
- 只有明确需要 Pod 内慢日志文件时，再启用 `--enable-fluentbit`

## 5. 常用命令

### 5.1 首次安装

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  -y
```

### 5.2 首次安装并启用 slow log sidecar

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --enable-fluentbit \
  --mysql-slow-query-time 1 \
  -y
```

### 5.3 给已有 MySQL 补监控

```bash
./dist/mysql-monitoring-amd64.run addon-install \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  --monitoring-target 10.0.0.20:3306 \
  -y
```

### 5.4 独立压测

```bash
./dist/mysql-benchmark-amd64.run benchmark \
  --namespace mysql-demo \
  --mysql-host 10.0.0.20 \
  --mysql-user root \
  --mysql-password '<MYSQL_PASSWORD>' \
  --benchmark-profile oltp-read-write \
  --benchmark-threads 64 \
  --benchmark-time 300 \
  --report-dir ./reports \
  -y
```

## 6. 构建方式

### 6.1 本地构建

```bash
chmod +x build.sh install.sh scripts/assemble-install.sh
./build.sh --arch amd64 --profile integrated
./build.sh --arch amd64 --profile benchmark
./build.sh --arch amd64 --profile monitoring
./build.sh --arch all --profile all
```

### 6.2 GitHub Actions

当前 workflow 会按矩阵构建：
- `amd64`
- `arm64`
- `integrated`
- `benchmark`
- `monitoring`

推送 `main` 会自动构建产物。
打 `v*` tag 会额外发布 release 资产。

## 7. 验证重点

这一版建议重点验证：
- integrated 包不再暴露任何备份恢复入口
- monitoring 包只提供监控 addon
- benchmark 包可独立跑通压测
- 默认日志可直接通过 `kubectl logs` 查看
- 开启 `--enable-fluentbit` 后，`mysql` 容器和 `fluent-bit` 容器日志边界清晰
- 老版本遗留的 backup 资源会在新版本 install/uninstall 时被清理

## 8. 相关文档

- [Addon 说明](docs/ADDONS.zh-CN.md)
- [架构说明](docs/ARCHITECTURE.zh-CN.md)
- [测试方案](docs/TESTING.zh-CN.md)
- [使用场景](docs/USE-CASES.zh-CN.md)

# MySQL 安装器测试说明

## 1. 测试环境

远端验证服务器：

- 地址：`36.133.245.109`
- 系统：Ubuntu 24.04
- Kubernetes：`v1.31.11`
- 默认 StorageClass：`nfs`
- `ServiceMonitor` CRD：不存在

## 2. 2026-04-03 已完成验证

这部分是 addon 改造前已经跑过的能力：

1. `install` 安装主链路。
2. `backup` 手工备份。
3. `verify-backup-restore` 备份恢复闭环校验。
4. `benchmark` 压测。
5. `uninstall` 后保留 PVC，再执行 `install`，验证数据复用。

结论：

1. 备份恢复主链路通过。
2. PVC 复用通过。
3. 压测链路通过。

## 3. 2026-04-04 addon 远端验证

### 3.1 远端构建策略

由于测试机访问 Docker Hub 超时，无法直接拉取 `prom/mysqld-exporter` 等镜像。

因此在远端测试时采用了“临时裁剪构建镜像清单”的方法：

1. 保留 `mysql`、`busybox`、`mysqld-exporter` 三个 amd64 镜像。
2. `mysqld-exporter` 的拉取源临时改为 `docker.m.daocloud.io/prom/mysqld-exporter:v0.15.1`。
3. 该变更只用于测试机构建，不代表仓库正式提交的镜像来源。

### 3.2 验证场景

测试 namespace：`mysql-addon-e2e`

#### 场景 A：先装一个极简 MySQL

命令要点：

1. `install`
2. `--disable-monitoring`
3. `--disable-fluentbit`
4. `--disable-backup`

结论：

1. MySQL 正常启动。
2. 可作为“已有实例后补能力”的基线环境。

#### 场景 B：`addon-status`

验证内容：

1. 外置 monitoring addon 未安装。
2. 内嵌 monitoring sidecar 未安装。
3. backup addon 未安装。
4. `ServiceMonitor` 因 CRD 缺失显示为“集群未安装 CRD”。

结论：

状态输出符合预期。

#### 场景 C：`addon-install backup`

验证内容：

1. 成功创建 `ConfigMap/mysql-backup-scripts`
2. 成功创建 `CronJob/mysql-backup`
3. 比较 `mysql-0` 的 Pod UID，确认未变化

结论：

`backup addon` 安装成功，且没有重建 MySQL Pod。

#### 场景 D：`backup`

验证内容：

1. 执行手工备份。
2. 等待 `mysql-backup-manual-*` Job 完成。

结论：

备份 Job 成功执行。

#### 场景 E：`addon-install monitoring,service-monitor`

验证内容：

1. 自动补齐 MySQL 监控账号。
2. 创建 `Secret/mysql-exporter-auth`
3. 创建 `Deployment/mysql-exporter`
4. 创建 `Service/mysql-exporter`
5. 集群无 `ServiceMonitor` CRD 时，仅 warning 并跳过
6. 比较 `mysql-0` 的 Pod UID，确认未变化

中途发现并修复的问题：

1. 初版实现里，虽然提示“跳过 ServiceMonitor”，但状态位没有一起关闭，仍会尝试 apply `ServiceMonitor`。
2. 修复后重新构建并重测，问题消失。

结论：

`monitoring addon` 安装成功，且不会重建 MySQL Pod。

#### 场景 F：`addon-uninstall monitoring`

验证内容：

1. 删除外置 exporter Deployment / Service / Secret。
2. 比较 `mysql-0` 的 Pod UID，确认未变化。

结论：

移除 `monitoring addon` 成功，且没有影响 MySQL Pod。

#### 场景 G：`addon-uninstall backup`

验证内容：

1. 删除 `CronJob/mysql-backup`
2. 比较 `mysql-0` 的 Pod UID，确认未变化。

结论：

移除 `backup addon` 成功，且没有影响 MySQL Pod。

## 4. 当前测试结论

已验证通过：

1. `install` 基线安装。
2. `addon-status`
3. `addon-install backup`
4. `backup`
5. `addon-install monitoring`
6. 无 `ServiceMonitor` CRD 跳过逻辑。
7. `addon-uninstall monitoring`
8. `addon-uninstall backup`
9. addon 路径下 MySQL Pod UID 不变。

尚未在远端做完整实跑的内容：

1. `addon-install backup` 的 S3 端到端闭环。
2. 日志 sidecar 路径，因为本次目标是“平台级日志优先”的 addon 方案。

## 5. 2026-04-04 压测可观测性与超时修复

问题现象：

1. 默认 `--wait-timeout 10m` 对 benchmark 不够，长时压测会被误判成失败。
2. benchmark Job 实际仍在运行，但安装器没有持续输出过程日志，用户感知接近“黑盒”。

根因：

1. `benchmark standard` 会串行跑多个 profile，加上 prepare / cleanup，整体时长明显大于普通 backup Job。
2. 安装器之前复用了通用 `wait_for_job`，没有针对 benchmark 做单独等待策略和日志透出。

修复策略：

1. benchmark 若未显式传 `--wait-timeout`，自动按 `profile + time + warmup + tables + table-size` 估算等待上限，并设置保底 30 分钟。
2. benchmark 创建后直接输出 Job 名称、目标地址、并发、时长和实时查看命令。
3. benchmark 等待期间自动输出 Pod 状态变化，并尝试实时跟随 `mysql-benchmark` 容器日志。
4. benchmark manifest 增加 prepare / cleanup 阶段日志，避免长时间无输出。

## 6. 建议理解

从测试结果看，这次改造后的能力边界已经比较清晰：

1. MySQL 本体和 sidecar 型能力走 `install`。
2. 已有实例补监控/备份走 `addon-install`。
3. 日志平台应放到 DaemonSet 层治理。

# MySQL 工具包测试方案

## 1. 本轮测试目标

这一轮重点不是功能新增，而是能力边界收敛和日志体验修正。

需要验证：
1. 备份恢复入口已经从 `apps_mysql` 中彻底移除
2. 三类产物的动作边界正确
3. 默认日志能被 `kubectl logs` 直接查看
4. 启用 `--enable-fluentbit` 后日志仍可排障
5. 老版本遗留的 backup 资源能被清理

## 2. 静态校验

本地至少执行：

```bash
bash -n build.sh
bash -n install.sh
bash -n scripts/install/modules/*.sh
bash install.sh help overview
bash install.sh help logging
```

检查点：
1. `help` 中不再出现 `backup` / `restore` / `verify-backup-restore`
2. `packages` 中只剩三类 `.run` 包
3. `addon` 中只剩 `monitoring` / `service-monitor`

## 3. 构建验证

执行：

```bash
./build.sh --arch amd64 --profile all
```

检查点：
1. 只产出 `mysql-installer`、`mysql-benchmark`、`mysql-monitoring`
2. 不再产出 `mysql-backup-restore`
3. 每个产物都带 `.sha256`

## 4. 集成安装验证

### 4.1 默认安装

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  -y
```

检查：
1. `kubectl get sts,svc,pvc,pod -n mysql-demo`
2. `kubectl get cronjob -n mysql-demo` 不应看到由 `apps_mysql` 创建的 backup 计划
3. `kubectl logs -n mysql-demo mysql-0 -c mysql --tail=200` 可直接输出日志

### 4.2 启用 Fluent Bit sidecar

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --enable-fluentbit \
  --mysql-slow-query-time 1 \
  -y
```

检查：
1. `kubectl get pod -n mysql-demo mysql-0 -o yaml | grep fluent-bit`
2. `kubectl logs -n mysql-demo mysql-0 -c mysql --tail=200` 仍能看到错误/常规日志
3. `kubectl logs -n mysql-demo mysql-0 -c fluent-bit --tail=200` 能看到 sidecar 输出

## 5. monitoring addon 验证

### 5.1 安装

```bash
./dist/mysql-monitoring-amd64.run addon-install \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  --monitoring-target 10.0.0.20:3306 \
  -y
```

检查：
1. `kubectl get deploy,svc,secret -n mysql-demo | grep mysql-exporter`
2. 集群若已安装 `ServiceMonitor` CRD，则应看到对应资源
3. MySQL StatefulSet 不应因为 addon 安装而滚动

### 5.2 卸载

```bash
./dist/mysql-monitoring-amd64.run addon-uninstall \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  -y
```

检查：
1. exporter Deployment/Service/Secret 被移除
2. StatefulSet 仍保持原样

## 6. benchmark 验证

```bash
./dist/mysql-benchmark-amd64.run benchmark \
  --namespace mysql-demo \
  --mysql-host 10.0.0.20 \
  --mysql-user root \
  --mysql-password '<MYSQL_PASSWORD>' \
  --benchmark-profile oltp-read-write \
  --report-dir ./reports \
  -y
```

检查：
1. Job 能完成
2. `reports/` 下有 `.log`、`.txt`、`.json`
3. 不支持 `--warmup-time` 的 sysbench 版本也能正常跑完

## 7. 老资源清理验证

如果测试环境曾用旧版 `apps_mysql` 安装过 backup 资源，再执行一次新的 `install` 或 `uninstall`：

检查：
1. 旧 `CronJob/mysql-backup*` 被清理
2. 旧 `ConfigMap/mysql-backup-scripts` 被清理
3. 旧 `Secret/mysql-backup-storage` 被清理

## 8. 结果判定

通过标准：
1. 用户入口里不再出现备份恢复能力
2. 安装、监控、压测三条链路都可独立运行
3. 默认日志可直接 `kubectl logs`
4. sidecar 开启后，日志边界仍然清晰
5. 老 backup 资源不会继续残留

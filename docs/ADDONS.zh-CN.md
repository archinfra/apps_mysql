# MySQL Addon 能力说明

## 1. 为什么要单独做 addon

“已有 MySQL 补齐能力”最大的问题不是功能本身，而是业务影响。

如果只是为了补一套监控或备份，却把数据库 Pod 重建了，那对运维来说体验是很差的。

因此当前版本把 addon 明确设计成：

1. 尽量新增外置资源。
2. 默认不改 StatefulSet。
3. 默认不触发 MySQL Pod 滚动更新。

## 2. 当前支持的 addon

### 2.1 monitoring

命令：

```bash
./mysql-installer.run addon-install \
  --namespace mysql-demo \
  --addons monitoring \
  -y
```

会创建：

1. `Deployment/mysql-exporter`
2. `Service/mysql-exporter`
3. `Secret/mysql-exporter-auth`

特点：

1. 会额外新增一个 exporter Pod。
2. 不会重建 `mysql-0`。
3. 会自动补齐 MySQL 监控账号。

### 2.2 service-monitor

命令：

```bash
./mysql-installer.run addon-install \
  --namespace mysql-demo \
  --addons service-monitor \
  -y
```

特点：

1. 会自动依赖 `monitoring`。
2. 如果集群没有 `ServiceMonitor` CRD，会提示并跳过。
3. 不会因为缺少 CRD 而让整个 addon 失败。

### 2.3 backup

命令：

```bash
./mysql-installer.run addon-install \
  --namespace mysql-demo \
  --addons backup \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  -y
```

会创建：

1. `ConfigMap/mysql-backup-scripts`
2. `CronJob/mysql-backup`
3. S3 模式下的存储 `Secret`

特点：

1. 不会重建 MySQL Pod。
2. 备份链路和 `backup` / `restore` / `verify-backup-restore` 命令兼容。

## 3. 当前不建议做成 addon 的能力

### 3.1 Fluent Bit sidecar

原因：

1. 需要改 StatefulSet Pod 模板。
2. 会触发滚动更新。
3. 这不符合 addon 路径“无业务中断补齐”的目标。

因此当前建议是：

1. 日志统一交给平台级 DaemonSet 日志体系。
2. Fluent Bit sidecar 只作为兼容路径保留在 `install` 里。
3. 只有必须读取容器内 slow log / error log 文件时，才建议接受 sidecar 带来的滚动更新成本。

研发快速查日志：

1. `kubectl logs -n <ns> <pod> -c mysql --tail=200`
2. `kubectl logs -n <ns> <pod> -c fluent-bit --tail=200`
3. `kubectl exec -n <ns> <pod> -c mysql -- tail -n 200 /var/log/mysql/slow.log`

## 4. 常用命令

查看 addon 状态：

```bash
./mysql-installer.run addon-status \
  --namespace mysql-demo
```

移除监控 addon：

```bash
./mysql-installer.run addon-uninstall \
  --namespace mysql-demo \
  --addons monitoring \
  -y
```

移除备份 addon：

```bash
./mysql-installer.run addon-uninstall \
  --namespace mysql-demo \
  --addons backup \
  -y
```

## 5. 适合你的决策建议

如果你打算单独建设 DaemonSet 级 Fluent Bit + ES：

1. 监控用 `addon-install monitoring`。
2. 备份用 `addon-install backup`。
3. 日志由平台层统一处理。
4. 不要默认再把 MySQL sidecar 打开。

只有在“必须抓取容器内 slow log 文件”时，才建议接受 sidecar 路径带来的滚动更新成本。

# MySQL Addon 能力说明

## 1. 为什么要单独做 addon

“已有 MySQL 补齐能力”最大的问题不是功能本身，而是业务影响。

如果只是为了补一套监控或备份，却把数据库 Pod 重建了，对运维来说体验会很差。

因此当前 addon 的设计原则是：

1. 尽量新增外置资源
2. 默认不改 StatefulSet
3. 默认不触发 MySQL Pod 滚动更新

这也是为什么当前更适合按职责模块维护 installer，而不是把 addon 逻辑拆散到大量单函数文件里。

---

## 2. 当前支持的 addon

### 2.1 monitoring

命令：

```bash
./dist/mysql-installer-amd64.run addon-install \
  --namespace mysql-demo \
  --addons monitoring \
  -y
```

会创建：

1. `Deployment/mysql-exporter`
2. `Service/mysql-exporter`
3. `Secret/mysql-exporter-auth`

特点：

1. 会新增一个 exporter Pod
2. 不会重建 `mysql-0`
3. 会自动补齐 MySQL 监控账号

### 2.2 service-monitor

命令：

```bash
./dist/mysql-installer-amd64.run addon-install \
  --namespace mysql-demo \
  --addons service-monitor \
  -y
```

特点：

1. 会自动依赖 `monitoring`
2. 如果集群没有 `ServiceMonitor` CRD，会 warning 并跳过
3. 不会因为缺少 CRD 导致整个 addon 失败

### 2.3 backup

命令：

```bash
./dist/mysql-installer-amd64.run addon-install \
  --namespace mysql-demo \
  --addons backup \
  --mysql-host mysql-0.mysql.mysql-demo.svc.cluster.local \
  --mysql-user root \
  --mysql-password 'StrongPassw0rd' \
  --mysql-target-name mysql-demo \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --backup-nfs-path /data/nfs-share \
  -y
```

会创建：

1. `ConfigMap/mysql-backup-scripts`
2. `CronJob/mysql-backup`
3. S3 模式下的存储 Secret

特点：

1. 不会重建 MySQL Pod
2. 备份链路和 `backup / restore / verify-backup-restore` 兼容
3. 需要显式提供可用的 MySQL 认证信息

---

## 3. 当前不建议做成 addon 的能力

### 3.1 Fluent Bit sidecar

原因：

1. 需要改 StatefulSet Pod 模板
2. 会触发滚动更新
3. 不符合 addon 路径“尽量不影响业务实例”的目标

因此当前建议是：

1. 日志统一交给平台级 DaemonSet 日志体系
2. Fluent Bit sidecar 只作为兼容路径保留在 `install`
3. 只有必须读取容器内 slow log / error log 文件时，才建议接受 sidecar 带来的滚动更新成本

---

## 4. 常用命令

查看 addon 状态：

```bash
./dist/mysql-installer-amd64.run addon-status \
  --namespace mysql-demo
```

移除监控 addon：

```bash
./dist/mysql-installer-amd64.run addon-uninstall \
  --namespace mysql-demo \
  --addons monitoring \
  -y
```

移除备份 addon：

```bash
./dist/mysql-installer-amd64.run addon-uninstall \
  --namespace mysql-demo \
  --addons backup \
  -y
```

---

## 5. 决策建议

如果你打算建设平台级 Fluent Bit + ES / OpenSearch / Loki：

1. 监控用 `addon-install monitoring`
2. 备份用 `addon-install backup`
3. 日志由平台层统一处理
4. 不要默认再把 MySQL sidecar 打开

只有在“必须抓取容器内 slow log 文件”时，才建议接受 sidecar 路径带来的滚动更新成本。

---

## 6. 和新源码结构的关系

当前 addon 相关逻辑主要分布在这些模块：

1. `scripts/install/modules/30-args.sh`
2. `scripts/install/modules/40-inputs-and-plan.sh`
3. `scripts/install/modules/50-render-and-apply.sh`
4. `scripts/install/modules/60-runtime.sh`
5. `scripts/install/modules/70-lifecycle-actions.sh`
6. `scripts/install/modules/80-data-actions.sh`

这样做的好处是：

1. addon 行为不再散落在大量单函数文件里
2. review 更容易聚焦在能力边界和业务影响
3. 后续新增 addon 时更容易放进现有职责模块

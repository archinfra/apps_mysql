# MySQL Addon 能力说明

## 1. addon 的定位

addon 面向“已有 MySQL 补外围能力”。

设计原则：

1. 尽量新增外围资源
2. 默认不修改 MySQL StatefulSet
3. 默认不触发 MySQL Pod 滚动更新

因此 addon 更适合：

1. 线上已经在跑的数据库
2. 后补监控或备份能力
3. 业务窗口有限，不希望因为补能力而影响实例

---

## 2. 当前支持的 addon

### 2.1 monitoring

会创建：

1. `Deployment/mysql-exporter`
2. `Service/mysql-exporter`
3. `Secret/mysql-exporter-auth`

特点：

1. 新增独立 exporter Pod
2. 不改 MySQL StatefulSet
3. 适合已有实例快速补监控

### 2.2 service-monitor

特点：

1. 自动依赖 `monitoring`
2. 如果集群缺少 `ServiceMonitor` CRD，会 warning 并跳过
3. 不会因为缺少 CRD 让整个动作失败

### 2.3 backup

现在 backup addon 已支持多计划：

1. 一个默认主计划
2. 多个额外 `--backup-plan`
3. `--backup-plan-file` YAML/JSON 配置文件
4. 多个 NFS
5. 多个 S3 / MinIO
6. 按库或按表导出

其中：

1. 一个带 `schedule` 的 plan 会生成一个独立 CronJob
2. 一个手工 `backup` 动作会按计划创建多个一次性 Job
3. 推荐把长期计划写进配置文件，命令行只保留连接参数

会创建：

1. `ConfigMap/mysql-backup-scripts`
2. 一个或多个 `CronJob/mysql-backup*`
3. S3 模式下对应的存储 Secret

特点：

1. 不会重建 MySQL Pod
2. 与 `backup / restore / verify-backup-restore` 共用同一套链路
3. 需要显式提供可用的 MySQL 认证信息

---

## 3. 推荐组合

### 3.1 只补监控

```bash
./dist/mysql-monitoring-amd64.run addon-install \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  --monitoring-target 10.0.0.20:3306 \
  -y
```

### 3.2 只补多中心备份

```bash
./dist/mysql-backup-restore-amd64.run addon-install \
  --namespace mysql-demo \
  --addons backup \
  --mysql-host 10.0.0.20 \
  --mysql-user root \
  --mysql-password '<MYSQL_PASSWORD>' \
  --backup-plan-file ./examples/backup-plans.example.yaml \
  -y
```

---

## 4. 当前不建议做成 addon 的能力

### 4.1 Fluent Bit sidecar

原因：

1. 需要修改 StatefulSet Pod 模板
2. 往往会触发滚动更新
3. 不符合 addon“尽量不动业务实例”的目标

因此当前建议：

1. 日志优先交给平台级 DaemonSet 日志体系
2. sidecar 日志采集只保留在 integrated 的 `install` 路径

---

## 5. 卸载与状态查看

查看 addon 状态：

```bash
./dist/mysql-backup-restore-amd64.run addon-status \
  --namespace mysql-demo
```

移除备份 addon：

```bash
./dist/mysql-backup-restore-amd64.run addon-uninstall \
  --namespace mysql-demo \
  --addons backup \
  -y
```

移除监控 addon：

```bash
./dist/mysql-monitoring-amd64.run addon-uninstall \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  -y
```

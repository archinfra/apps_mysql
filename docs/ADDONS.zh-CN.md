# MySQL Addon 能力说明

## 1. addon 的定位

addon 面向“已有 MySQL 补外围能力”。

设计原则：
1. 尽量新增外围资源
2. 默认不修改 MySQL StatefulSet
3. 默认不触发 MySQL Pod 滚动更新

因此 addon 更适合：
1. 线上已经在跑的数据库
2. 后补监控能力
3. 业务窗口有限，不希望因为补能力而影响实例

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
2. 集群缺少 `ServiceMonitor` CRD 时会 warning 并跳过
3. 不会因为缺少 CRD 让整个动作失败

## 3. 当前不作为 addon 提供的能力

### 3.1 Fluent Bit sidecar

原因：
1. 需要修改 StatefulSet Pod 模板
2. 往往会触发滚动更新
3. 不符合 addon “尽量不动业务实例” 的目标

因此当前建议：
1. 日志优先交给平台级 DaemonSet 日志体系
2. sidecar 日志采集只保留在 integrated 的 `install` 路径

### 3.2 备份恢复

备份恢复已经迁移到独立数据保护系统，不再作为 `apps_mysql` 的 addon 提供。

## 4. 常用命令

### 4.1 只补监控

```bash
./dist/mysql-monitoring-amd64.run addon-install \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  --monitoring-target 10.0.0.20:3306 \
  -y
```

### 4.2 查看 addon 状态

```bash
./dist/mysql-monitoring-amd64.run addon-status \
  --namespace mysql-demo
```

### 4.3 卸载监控 addon

```bash
./dist/mysql-monitoring-amd64.run addon-uninstall \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  -y
```

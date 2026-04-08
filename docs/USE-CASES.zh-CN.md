# MySQL 工具包常见使用场景

## 1. 首次离线交付 MySQL

适合使用：`mysql-installer-<arch>.run`

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  -y
```

适合：
1. 首次安装
2. 需要统一交付 StatefulSet / Service / PVC
3. 希望由 install 统一对齐内嵌监控和日志开关

## 2. 已有 MySQL，只想补监控

适合使用：`mysql-monitoring-<arch>.run`

```bash
./dist/mysql-monitoring-amd64.run addon-install \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  --monitoring-target 10.0.0.20:3306 \
  -y
```

适合：
1. 目标 MySQL 已存在
2. 只想补 exporter 和 ServiceMonitor
3. 不希望修改 MySQL StatefulSet

## 3. 只想做压测

适合使用：`mysql-benchmark-<arch>.run`

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

适合：
1. 其他项目的 MySQL 只想做压测
2. 不需要安装器和监控逻辑
3. 希望直接拿 `.log / .txt / .json` 报告

## 4. 现场排障要直接看日志

默认安装后：

```bash
kubectl logs -n mysql-demo mysql-0 -c mysql --tail=200
```

适合：
1. 快速看错误日志
2. 直接看 slow log
3. 不依赖外部日志平台也能排查
4. 避免因 `/proc/self/fd/*` 日志路径触发 MySQL entrypoint 的目录修复报错

## 5. 必须采 Pod 内慢日志文件

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --enable-fluentbit \
  --mysql-slow-query-time 1 \
  -y
```

查看：

```bash
kubectl logs -n mysql-demo mysql-0 -c mysql --tail=200
kubectl logs -n mysql-demo mysql-0 -c fluent-bit --tail=200
```

适合：
1. 平台要求 sidecar 转发慢日志
2. 仍希望保留 mysql 容器自身日志用于排障

## 6. 关于备份恢复

备份恢复已经迁移到独立数据保护系统，不再建议通过 `apps_mysql` 安装器继续承载。
如果场景是多中心备份、恢复、定时计划或跨中间件数据保护，应使用独立系统而不是继续从这里拼装。

# MySQL 工具包常见使用场景

## 1. 首次离线交付 MySQL

适合使用：`mysql-installer-<arch>.run`

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --backup-nfs-path /data/nfs-share \
  -y
```

适合：

1. 首次安装
2. 希望一次性具备基础备份能力
3. 接受由 install 统一对齐整体资源

---

## 2. 已有 MySQL，只想加多中心定时备份

适合使用：`mysql-backup-restore-<arch>.run`

```bash
./dist/mysql-backup-restore-amd64.run addon-install \
  --namespace mysql-demo \
  --addons backup \
  --mysql-host 10.0.0.20 \
  --mysql-user root \
  --mysql-password '<MYSQL_PASSWORD>' \
  --disable-default-backup-plan \
  --backup-plan 'name=dc1-nfs;backend=nfs;nfsServer=192.168.10.2;nfsPath=/data/nfs-a;schedule=0 2 * * *;retention=7;databases=orders,inventory' \
  --backup-plan 'name=dc2-minio;backend=s3;s3Endpoint=https://minio.dc2.example.com;s3Bucket=mysql-backup;s3Prefix=prod;s3AccessKey=minio;s3SecretKey=secret;schedule=30 2 * * *;retention=30;databases=orders,inventory' \
  -y
```

适合：

1. 业务库已经在跑
2. 想加一个或多个异地备份计划
3. 不希望动 MySQL StatefulSet
4. 希望把计划长期维护在 YAML/JSON 文件里

---

## 3. 同时写到多个 NFS 和多个 MinIO

一个带 `schedule` 的 backup plan 会生成一个独立 CronJob，所以多中心天然就是多 CronJob。

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

适合：

1. 需要多地留存
2. 希望每个中心有独立计划名和调度
3. 希望统一通过一套命令管理
4. 希望后续加中心时只改配置文件

---

## 4. 只导出某些库

```bash
./dist/mysql-backup-restore-amd64.run backup \
  --namespace mysql-demo \
  --mysql-host 10.0.0.20 \
  --mysql-user root \
  --mysql-password '<MYSQL_PASSWORD>' \
  --disable-default-backup-plan \
  --backup-plan 'name=biz-db;backend=nfs;nfsServer=192.168.10.2;nfsPath=/data/nfs-a;databases=orders,inventory;retention=7' \
  -y
```

适合：

1. 只关心业务库
2. 不希望把其他库一起打包
3. 想把备份职责抽离为“指定业务域导出”

---

## 5. 只导出某些表

```bash
./dist/mysql-backup-restore-amd64.run backup \
  --namespace mysql-demo \
  --mysql-host 10.0.0.20 \
  --mysql-user root \
  --mysql-password '<MYSQL_PASSWORD>' \
  --disable-default-backup-plan \
  --backup-plan 'name=audit-only;backend=s3;s3Endpoint=https://minio.dc2.example.com;s3Bucket=mysql-backup;s3Prefix=prod;s3AccessKey=minio;s3SecretKey=secret;tables=orders.audit_log,orders.audit_event;retention=30' \
  -y
```

适合：

1. 只想保留审计、流水、归档类表
2. 想降低备份体积
3. 想把重点表同步到异地对象存储

---

## 6. 从指定中心恢复

```bash
./dist/mysql-backup-restore-amd64.run restore \
  --namespace mysql-demo \
  --mysql-host 10.0.0.20 \
  --mysql-user root \
  --mysql-password '<MYSQL_PASSWORD>' \
  --restore-source minio-a \
  --restore-snapshot latest \
  --restore-mode merge \
  --disable-default-backup-plan \
  --backup-plan 'name=minio-a;backend=s3;s3Endpoint=https://minio-a.example.com;s3Bucket=mysql-backup;s3Prefix=prod;s3AccessKey=minio;s3SecretKey=secret' \
  -y
```

适合：

1. 主中心不可用
2. 需要明确指定从某个异地中心恢复
3. 希望恢复来源可审计、可控

注意：

1. 部分库/表备份建议使用 `merge`
2. `wipe-all-user-databases` 只适合全量备份来源

---

## 7. 只想做压测

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
2. 不需要安装器和备份逻辑
3. 希望直接拿 `.log / .txt / .json` 报告

---

## 8. 只想补监控

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
3. 不希望同时引入备份和压测逻辑

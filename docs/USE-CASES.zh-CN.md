# MySQL 安装器常见使用场景

## 场景 1：离线环境，使用 NFS 作为标准备份

适合：

1. 内网环境。
2. 没有对象存储。
3. 运维团队已经有 NFS 服务。

命令示例：

```bash
./mysql-installer.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --backup-nfs-path /data/nfs-share \
  -y
```

## 场景 2：已有对象存储，希望异地保存备份

适合：

1. 已有 MinIO / Ceph / AWS S3。
2. 希望与计算集群解耦存储。

命令示例：

```bash
./mysql-installer.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --backup-backend s3 \
  --s3-endpoint https://minio.example.com \
  --s3-bucket mysql-backup \
  --s3-prefix prod \
  --s3-access-key <AK> \
  --s3-secret-key <SK> \
  -y
```

## 场景 3：先装 MySQL，后补监控能力

第一阶段：

```bash
./mysql-installer.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --disable-service-monitor \
  -y
```

第二阶段，当集群补了 Prometheus Operator 之后：

```bash
./mysql-installer.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --enable-monitoring \
  --enable-service-monitor \
  -y
```

## 场景 4：环境暂时不需要 Fluent Bit

```bash
./mysql-installer.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --disable-fluentbit \
  -y
```

## 场景 5：重装但保留数据

步骤：

1. 执行 `uninstall`，不要带 `--delete-pvc`。
2. 使用同样的 `namespace` 和 `--sts-name` 再执行 `install`。

说明：

只要 PVC 还在，通常无需 restore，StatefulSet 会直接挂回原数据卷。

## 场景 6：PVC 已删除，只能从备份恢复

步骤：

1. 重新执行 `install` 创建新的 MySQL 实例。
2. 执行 `restore`。

示例：

```bash
./mysql-installer.run restore \
  --namespace mysql-demo \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --restore-snapshot latest \
  -y
```

## 场景 7：需要做一次功能级压测

```bash
./mysql-installer.run benchmark \
  --namespace mysql-demo \
  --benchmark-concurrency 32 \
  --benchmark-iterations 3 \
  --benchmark-queries 2000 \
  --report-dir ./reports \
  -y
```

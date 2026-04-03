# apps_mysql

面向 Kubernetes 的 MySQL 离线安装包，支持离线构建、状态对齐安装、NFS/S3 双备份后端、恢复校验、监控、日志采集和内置压测。

## 你最先需要知道的事

1. `install` 不是一次性脚本，而是“声明式对齐”动作。
2. 默认开启监控、ServiceMonitor、Fluent Bit、备份和压测能力。
3. 如果集群没有 `ServiceMonitor` CRD，安装会继续，只跳过该资源。
4. 默认不会删除 PVC，所以同 `namespace + sts-name` 的重装通常可以复用原数据。
5. 备份后端支持 `nfs` 和 `s3`。

## 目录结构

```text
.
|-- build.sh
|-- install.sh
|-- images/
|-- manifests/
`-- docs/
```

## 详细文档

- [中文架构解析](docs/ARCHITECTURE.zh-CN.md)
- [中文使用场景](docs/USE-CASES.zh-CN.md)
- [中文测试说明](docs/TESTING.zh-CN.md)
- [设计决策与方案文档](docs/plans/2026-04-03-mysql-installer-architecture-design.md)

## 构建

```bash
chmod +x build.sh install.sh
./build.sh --arch amd64
./build.sh --arch arm64
./build.sh --arch all
```

构建产物:

```text
dist/mysql-installer-amd64.run
dist/mysql-installer-amd64.run.sha256
dist/mysql-installer-arm64.run
dist/mysql-installer-arm64.run.sha256
```

## 安装示例

NFS 备份:

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  -y
```

S3 备份:

```bash
./dist/mysql-installer-amd64.run install \
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

按需关闭部分能力:

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --disable-service-monitor \
  --disable-fluentbit \
  -y
```

## 核心参数

常用基础参数:

- `-n, --namespace`
- `--root-password`
- `--mysql-replicas`
- `--storage-class`
- `--storage-size`
- `--sts-name`
- `--service-name`
- `--node-port`

能力开关:

- `--enable-monitoring` / `--disable-monitoring`
- `--enable-service-monitor` / `--disable-service-monitor`
- `--enable-fluentbit` / `--disable-fluentbit`
- `--enable-backup` / `--disable-backup`
- `--enable-benchmark` / `--disable-benchmark`

备份参数:

- `--backup-backend nfs|s3`
- `--backup-nfs-server`
- `--backup-nfs-path`
- `--backup-root-dir`
- `--backup-schedule`
- `--backup-retention`
- `--s3-endpoint`
- `--s3-bucket`
- `--s3-prefix`
- `--s3-access-key`
- `--s3-secret-key`
- `--s3-insecure`

## 运行默认值

- namespace: `aict`
- replicas: `1`
- storageClass: `nfs`
- storage size: `10Gi`
- service name: `mysql`
- nodePort service name: `mysql-nodeport`
- nodePort: `30306`
- backup backend: `nfs`
- backup nfs path: `/data/nfs-share`
- backup root dir: `backups`
- backup retention: `5`
- monitoring exporter: `enabled`
- service monitor: `enabled`
- fluent-bit: `enabled`
- benchmark action: `enabled`

## 关键运行规则

1. `install` 可以重复执行，用于补开或关闭能力。
2. `--disable-monitoring` 会自动关闭 `ServiceMonitor`。
3. `ServiceMonitor` 只在集群已安装 CRD 时创建。
4. 卸载默认保留 PVC，只有 `uninstall --delete-pvc` 才会删除。
5. 若想重装复用数据，保持 `namespace` 和 `--sts-name` 不变。

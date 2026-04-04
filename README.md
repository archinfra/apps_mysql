# apps_mysql

面向 Kubernetes 的 MySQL 离线安装包，支持离线构建、整套对齐安装、已有实例 addon 补齐、NFS/S3 备份、恢复校验、监控集成和内置压测。

## 先看这 7 条

1. `install` 不是一次性脚本，而是“整套声明式对齐”动作。
2. 已有 MySQL 如果只想补监控或备份，优先使用 `addon-install`，默认不改 MySQL StatefulSet。
3. `addon-install monitoring` 会新增外置 `mysqld-exporter Deployment`，不会重建 MySQL Pod。
4. `addon-install backup` 会新增 `CronJob / ConfigMap / Secret`，不会重建 MySQL Pod。
5. 日志平台推荐做成 DaemonSet 级 Fluent Bit + ES / OpenSearch / Loki 等公共组件，不建议默认给 MySQL 再塞日志 sidecar。
6. `install --enable-fluentbit` 仍然保留，用于必须采集容器内 slow log 文件的兼容场景，但要接受滚动更新。
7. 默认不会删除 PVC，所以同 `namespace + sts-name` 的重装通常可以复用原数据。

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

- [架构解析](docs/ARCHITECTURE.zh-CN.md)
- [Addon 设计与边界](docs/ADDONS.zh-CN.md)
- [常见场景](docs/USE-CASES.zh-CN.md)
- [测试说明](docs/TESTING.zh-CN.md)
- [设计决策文档](docs/plans/2026-04-04-mysql-addon-capability-design.md)

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

首次安装，使用 NFS 备份:

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  -y
```

首次安装，但暂时不启用监控 sidecar、日志 sidecar、备份:

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --disable-monitoring \
  --disable-fluentbit \
  --disable-backup \
  -y
```

已有 MySQL 单独补齐监控能力:

```bash
./dist/mysql-installer-amd64.run addon-install \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  -y
```

已有 MySQL 单独补齐备份能力:

```bash
./dist/mysql-installer-amd64.run addon-install \
  --namespace mysql-demo \
  --addons backup \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  -y
```

## 命令分工

- `install`: 整套对齐 MySQL、本体配置、sidecar 型能力、备份能力、压测能力。
- `addon-install`: 给已有 MySQL 补齐外置能力，当前支持 `monitoring`、`service-monitor`、`backup`。
- `addon-uninstall`: 单独移除外置 addon。
- `addon-status`: 查看外置 addon、内嵌 sidecar、ServiceMonitor、日志模式的当前状态。
- `backup`: 执行一次手工备份。
- `restore`: 按快照恢复。
- `verify-backup-restore`: 跑备份恢复闭环校验。
- `benchmark`: 执行内置压测。

## 日志建议

推荐路径:

1. 由平台层单独建设 DaemonSet 级日志体系。
2. 统一采集容器 stdout/stderr。
3. MySQL 安装器只负责给出边界，不代装整套日志平台。

兼容路径:

1. 若必须读取 MySQL 容器内 slow log / error log 文件，可使用 `install --enable-fluentbit`。
2. 这会修改 StatefulSet 模板，因此需要评估滚动更新窗口。

## 关键参数

常用基础参数:

- `-n, --namespace`
- `--root-password`
- `--mysql-replicas`
- `--storage-class`
- `--storage-size`
- `--sts-name`
- `--service-name`
- `--node-port`

addon 参数:

- `--addons monitoring,service-monitor,backup`
- `--monitoring-target`
- `--exporter-user`
- `--exporter-password`

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

## 当前默认值

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
- monitoring sidecar: `enabled`
- service monitor: `enabled`
- fluent-bit sidecar: `enabled`
- benchmark action: `enabled`

## 运行规则

1. `install` 可以重复执行，用于整套开关对齐。
2. `addon-install` 默认只做“额外新增资源”，不重启 MySQL Pod。
3. `ServiceMonitor` 只在集群已安装 CRD 时创建。
4. 卸载默认保留 PVC，只有 `uninstall --delete-pvc` 才会删除。
5. 若想重装复用数据，保持 `namespace` 和 `--sts-name` 不变。

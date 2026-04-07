# apps_mysql

面向 Kubernetes 的 MySQL 离线交付与运维工具包。

当前版本：`v1.5.3`

这套项目不再只提供一个“大一统安装器”，而是同时支持：

- 集成包：整体安装、对齐、补能力、备份恢复、压测
- 备份恢复包：只做 backup / restore / verify-backup-restore
- 压测包：只做 benchmark
- 监控包：只做 monitoring / service-monitor addon

这样既保留了离线集成交付的优势，也能把压测、备份恢复、监控这些能力抽出来给其他 MySQL 场景复用。

---

## 1. 最终方案概览

### 1.1 产品形态

当前构建会产出四类 `.run` 包：

- `mysql-installer-<arch>.run`
- `mysql-backup-restore-<arch>.run`
- `mysql-benchmark-<arch>.run`
- `mysql-monitoring-<arch>.run`

它们共用同一套源码模块、manifest 与运行逻辑，但按职责裁剪镜像、动作和帮助信息。

### 1.2 备份恢复模型

备份能力已经从“单一后端配置”升级为“backup plan 模型”：

- 一个 `backup plan` 对应一个目的地、一条调度、一个保留策略和一个导出范围
- 可以有多个 NFS、多个 MinIO/S3，也可以混合使用
- 可以保留默认主计划，也可以用 `--disable-default-backup-plan` 后全部显式定义
- 可以导出全量、指定库，或指定表

这意味着现在既支持：

- 日常定时主备份
- 额外再加一条异地定时备份
- 同时写入多个存储中心
- 单独导出某些业务库或某些表

并且：

- 一个带 `schedule` 的 backup plan 就会生成一个独立 CronJob
- 手工 `backup` 会按计划逐个创建一次性 Job
- `--backup-plan-file` 支持把长期计划收进 YAML/JSON，便于 Git 化维护

---

## 2. 仓库结构

```text
.
|-- .github/workflows/
|-- build.sh
|-- install.sh
|-- images/
|   `-- image.json
|-- manifests/
|-- scripts/
|   |-- assemble-install.sh
|   `-- install/
|       `-- modules/
|           |-- 00-header.sh
|           |-- 10-core.sh
|           |-- 20-help.sh
|           |-- 25-package-profile.sh
|           |-- 30-args.sh
|           |-- 35-backup-plans.sh
|           |-- 40-inputs-and-plan.sh
|           |-- 50-render-and-apply.sh
|           |-- 60-runtime.sh
|           |-- 70-lifecycle-actions.sh
|           |-- 80-data-actions.sh
|           `-- 90-benchmark-and-main.sh
`-- docs/
```

维护约定：

- 日常修改优先改 `scripts/install/modules/*.sh`
- 再执行 `scripts/assemble-install.sh install.sh` 重新生成根目录 `install.sh`
- 根目录 `install.sh` 是最终产物和调试入口，不是长期手工维护的主源码文件

---

## 3. 能力边界

### 3.1 integrated 包

适合：

- 首次离线交付 MySQL
- 整套对齐 StatefulSet / Service / PVC / sidecar
- 一次性开启监控、备份、压测等能力

支持动作：

- `install`
- `uninstall`
- `status`
- `addon-install`
- `addon-uninstall`
- `addon-status`
- `backup`
- `restore`
- `verify-backup-restore`
- `benchmark`

### 3.2 backup-restore 包

适合：

- 已有 MySQL，只需要备份恢复能力
- 想做多中心定时备份
- 想执行恢复或闭环校验

支持动作：

- `status`
- `addon-install --addons backup`
- `addon-uninstall --addons backup`
- `addon-status`
- `backup`
- `restore`
- `verify-backup-restore`

### 3.3 benchmark 包

适合：

- 只想做标准化 MySQL 压测
- 不想携带备份、监控、安装逻辑

支持动作：

- `benchmark`

### 3.4 monitoring 包

适合：

- 已有 MySQL，只想补 exporter / ServiceMonitor

支持动作：

- `status`
- `addon-install --addons monitoring,service-monitor`
- `addon-uninstall --addons monitoring,service-monitor`
- `addon-status`

---

## 4. 备份计划模型

### 4.1 旧参数继续兼容

以下顶层参数仍然可用，并会生成默认主计划：

- `--backup-backend`
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
- `--backup-store-name`
- `--backup-databases`
- `--backup-tables`

### 4.2 额外增加计划

通过重复传入 `--backup-plan '<spec>'`，或使用 `--backup-plan-file <path>` 增加多个中心：

```bash
./dist/mysql-backup-restore-amd64.run addon-install \
  --namespace mysql-demo \
  --addons backup \
  --mysql-host 10.0.0.20 \
  --mysql-user root \
  --mysql-password '<MYSQL_PASSWORD>' \
  --disable-default-backup-plan \
  --backup-plan 'name=nfs-a;backend=nfs;nfsServer=192.168.10.2;nfsPath=/data/nfs-a;schedule=0 2 * * *;retention=7;databases=orders,inventory' \
  --backup-plan 'name=nfs-b;backend=nfs;nfsServer=192.168.20.2;nfsPath=/data/nfs-b;schedule=10 2 * * *;retention=7;databases=orders,inventory' \
  --backup-plan 'name=minio-c;backend=s3;s3Endpoint=https://minio.dc3.example.com;s3Bucket=mysql-backup;s3Prefix=prod;s3AccessKey=minio;s3SecretKey=secret;schedule=20 2 * * *;retention=30;tables=orders.audit_log,orders.audit_event' \
  -y
```

支持字段：

- `name`
- `storeName`
- `backend`
- `rootDir`
- `schedule`
- `retention`
- `nfsServer`
- `nfsPath`
- `s3Endpoint`
- `s3Bucket`
- `s3Prefix`
- `s3AccessKey`
- `s3SecretKey`
- `s3Insecure`
- `databases`
- `tables`

推荐长期维护方式：

1. 临时验证时用命令行 `--backup-plan`
2. 稳定后收敛到 YAML/JSON 文件
3. 把文件和环境差异一起纳入 Git 管理
4. 通过 `defaults` 统一公共参数，减少重复

注意：

1. 这里的 YAML/JSON 目前只是安装器读取的“本地配置文件 schema”
2. 不是 Kubernetes CRD，也不是拿去 `kubectl apply` 的集群资源
3. 我们故意把示例元数据写成 `schemaVersion/configKind`，避免和真正 CRD 混淆

### 4.3 导出范围

支持三种范围：

- 全量：不传 `databases` / `tables`
- 指定库：`databases=db1,db2`
- 指定表：`tables=db1.t1,db2.t2`

说明：

- 指定表时会自动按库分组导出
- restore 导入的就是该 dump 中包含的对象
- 对部分库/表备份，推荐使用 `--restore-mode merge`
- `wipe-all-user-databases` 只允许全量备份来源，避免误删其他业务库

### 4.4 路径规则

NFS：

```text
<backup-nfs-path>/<backup-root-dir>/mysql/<namespace>/<mysql-target-name>/stores/<store-name>/
```

S3 / MinIO：

```text
<bucket>/<s3-prefix>/<backup-root-dir>/mysql/<namespace>/<mysql-target-name>/stores/<store-name>/
```

如果 `store-name` 是默认主存储 `primary`，则继续兼容原有路径，不强制插入 `stores/primary`。

---

## 5. 常用命令

### 5.1 首次安装并带默认 NFS 备份

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --backup-nfs-path /data/nfs-share \
  -y
```

### 5.2 给已有 MySQL 增加多中心定时备份

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

### 5.3 立刻执行一次多中心备份

```bash
./dist/mysql-backup-restore-amd64.run backup \
  --namespace mysql-demo \
  --mysql-host 10.0.0.20 \
  --mysql-user root \
  --mysql-password '<MYSQL_PASSWORD>' \
  --backup-plan-file ./examples/backup-plans.example.yaml \
  -y
```

### 5.4 从指定中心恢复

```bash
./dist/mysql-backup-restore-amd64.run restore \
  --namespace mysql-demo \
  --mysql-host 10.0.0.20 \
  --mysql-user root \
  --mysql-password '<MYSQL_PASSWORD>' \
  --restore-source dc2-minio \
  --restore-snapshot latest \
  --restore-mode merge \
  --backup-plan-file ./examples/backup-plans.example.yaml \
  -y
```

### 5.6 使用配置文件管理长期计划

仓库已附带示例模板：

- [backup-plans.example.yaml](C:/Users/yuanyp8/Desktop/archinfra/apps_mysql/examples/backup-plans.example.yaml)
- [backup-plans.example.json](C:/Users/yuanyp8/Desktop/archinfra/apps_mysql/examples/backup-plans.example.json)

建议：

1. 每个环境维护一份 `backup-plans.<env>.yaml`
2. 公共参数放进 `defaults`
3. 每个中心只保留差异字段
4. 通过 `restoreSource` 明确默认恢复优先级

### 5.5 独立压测

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

---

## 6. 构建方式

### 6.1 本地构建

```bash
chmod +x build.sh install.sh scripts/assemble-install.sh
./build.sh --arch amd64 --profile integrated
./build.sh --arch amd64 --profile backup-restore
./build.sh --arch amd64 --profile benchmark
./build.sh --arch amd64 --profile monitoring
./build.sh --arch all --profile all
```

### 6.2 GitHub Actions

当前 workflow 会按矩阵构建：

- `amd64`
- `arm64`
- `integrated`
- `backup-restore`
- `benchmark`
- `monitoring`

因此一次 workflow 会产出 8 份 `.run` 与对应的 `.sha256`。

---

## 7. 当前验证重点

本轮重点验证以下能力：

- 多个 `--backup-plan` 生成多条 CronJob / 多个目的地
- `--backup-databases` / `--backup-tables` 的导出范围
- restore 的 `--restore-source` 选择逻辑
- 部分备份与 `wipe-all-user-databases` 的安全边界
- 多产物构建链路与 GitHub Actions 矩阵产物
- benchmark 在旧版 sysbench 下的兼容逻辑

---

## 8. 相关文档

- [架构说明](docs/ARCHITECTURE.zh-CN.md)
- [使用场景](docs/USE-CASES.zh-CN.md)
- [Addon 说明](docs/ADDONS.zh-CN.md)
- [测试说明](docs/TESTING.zh-CN.md)
- [2026-04-07 多中心备份与多产物方案](docs/plans/2026-04-07-mysql-capability-packaging-and-multi-center-backup.md)

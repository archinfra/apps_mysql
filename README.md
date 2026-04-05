# apps_mysql

面向 Kubernetes 的 MySQL 离线安装器项目，支持：

- 离线构建安装包
- `install` 全量对齐安装
- `addon-install` / `addon-uninstall` 外置能力补装
- NFS / S3 备份
- 恢复与备份恢复闭环校验
- `sysbench` 压测
- GitHub Actions 自动构建与发版

当前版本：`v1.5.2`

---

## 1. 先看结论

这套安装器现在遵循下面几条原则：

1. `install` 是“声明式对齐”，不是一次性初始化脚本。
2. 对已有 MySQL 追加能力时，优先用 `addon-install`，尽量不改 StatefulSet。
3. 备份、恢复、备份恢复闭环校验这几个动作，必须显式提供可用的 MySQL 认证信息。
4. `install.sh` 继续保留为最终单文件产物，但源码不再按函数拆，而是按职责拆成少量模块。
5. benchmark 使用官方 `sysbench` 镜像，不再在本仓库里自建镜像。

---

## 2. 为什么这次重新调整 installer 源码组织

之前的做法是把 `install.sh` 按函数拆到很多小文件里，再在构建时拼回去。

这个方案的问题很明显：

- 一个功能点通常会跨多个函数，改动会散到很多文件里。
- review 很难看出“这是一个备份体验改动”还是“这是一个 benchmark 逻辑改动”。
- 新人维护时不容易知道应该去哪个文件改。
- 函数数量越多，拆分粒度越碎，目录会越来越像“shell AST”，而不是工程目录。

现在改成了“按职责拆分”的方式：

- 保留最终产物：`install.sh`
- 保留组装能力：`scripts/assemble-install.sh`
- 源码入口改成：`scripts/install/modules/*.sh`
- 每个模块负责一个明确的领域，而不是单个函数

这更接近工程实践中的“按 bounded context / concern 拆分”，后续维护成本会更低。

---

## 3. 仓库结构

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
|           |-- 30-args.sh
|           |-- 40-inputs-and-plan.sh
|           |-- 50-render-and-apply.sh
|           |-- 60-runtime.sh
|           |-- 70-lifecycle-actions.sh
|           |-- 80-data-actions.sh
|           `-- 90-benchmark-and-main.sh
`-- docs/
```

### 模块职责

- `00-header.sh`
  变量、默认值、颜色、版本、镜像名
- `10-core.sh`
  基础日志函数、通用小工具
- `20-help.sh`
  所有 help 文案
- `30-args.sh`
  参数解析、addon 解析、默认值推导、动作门禁
- `40-inputs-and-plan.sh`
  输入校验、认证处理、执行计划打印、确认逻辑
- `50-render-and-apply.sh`
  镜像准备、模板渲染、资源 apply
- `60-runtime.sh`
  wait/job/log/report/mysql 执行等运行时公共逻辑
- `70-lifecycle-actions.sh`
  install / uninstall / status / addon 相关动作
- `80-data-actions.sh`
  backup / restore / verify-backup-restore
- `90-benchmark-and-main.sh`
  benchmark、收尾输出、cleanup、main

---

## 4. 构建方式

### 本地构建

```bash
chmod +x build.sh install.sh scripts/assemble-install.sh
./build.sh --arch amd64
./build.sh --arch arm64
./build.sh --arch all
```

构建时会自动做两件事：

1. 从 `scripts/install/modules/*.sh` 组装出根目录 `install.sh`
2. 根据 `images/image.json` 拉取并打包离线镜像

构建产物：

```text
dist/mysql-installer-amd64.run
dist/mysql-installer-amd64.run.sha256
dist/mysql-installer-arm64.run
dist/mysql-installer-arm64.run.sha256
```

### GitHub Actions

- push 到 `main`：触发构建
- push `v*` tag：触发构建并发布 release

---

## 5. 镜像策略

### 当前镜像来源

- MySQL：仓库既有来源
- mysqld-exporter：上游镜像
- Fluent Bit：上游镜像
- MinIO Client：上游镜像
- BusyBox：既有来源
- Sysbench：官方镜像 `openeuler/sysbench:1.0.20-oe2403sp1`

### 为什么不再自建 sysbench

之前仓库通过 `images/sysbench.Dockerfile` 临时装包生成 benchmark 镜像。

这个链路的问题是：

- 构建时间更长
- 多一层 Dockerfile 维护成本
- 依赖外部 yum/microdnf 源时，复现性更差
- benchmark 只是运行时工具，没必要为它维护自定义镜像

现在直接拉官方镜像，再离线打包进安装包，链路更简单。

---

## 6. 命令模型

### install

用于全量安装或重新对齐 MySQL 资源。

适合场景：

- 首次安装
- 调整副本数、存储、NodePort、功能开关
- 把 sidecar / backup / benchmark 配置重新对齐到目标状态

### addon-install

用于给“已经存在的 MySQL”补装外置能力。

当前支持：

- `monitoring`
- `service-monitor`
- `backup`

原则上：

- 尽量新增外围资源
- 不直接重写 MySQL StatefulSet

### addon-uninstall

用于移除外置 addon 资源。

### backup

立即执行一次备份 Job。

注意：

- 这不是“安装定时备份”
- 不会创建 CronJob
- 只会创建一次性 Job

### restore

基于快照执行恢复。

### verify-backup-restore

执行一次备份恢复闭环校验。

### benchmark

执行一次工程化 benchmark Job，并输出文本报告与 JSON 报告。

---

## 7. 关键参数

### 基础参数

- `-n, --namespace`
- `--root-password`
- `--auth-secret`
- `--mysql-replicas`
- `--storage-class`
- `--storage-size`
- `--service-name`
- `--sts-name`
- `--wait-timeout`
- `-y, --yes`

### NodePort 参数

- `--nodeport-enabled true|false`
- `--enable-nodeport`
- `--disable-nodeport`
- `--node-port`
- `--nodeport-service-name`

### 镜像参数

- `--registry <repo-prefix>`
- `--skip-image-prepare`

### MySQL 目标连接参数

- `--mysql-host`
- `--mysql-port`
- `--mysql-user`
- `--mysql-password`
- `--mysql-auth-secret`
- `--mysql-password-key`
- `--mysql-target-name`

### 备份参数

- `--backup-backend nfs|s3`
- `--backup-root-dir`
- `--backup-nfs-server`
- `--backup-nfs-path`
- `--backup-schedule`
- `--backup-retention`
- `--s3-endpoint`
- `--s3-bucket`
- `--s3-prefix`
- `--s3-access-key`
- `--s3-secret-key`
- `--s3-insecure`

### benchmark 参数

- `--benchmark-profile`
- `--benchmark-threads`
- `--benchmark-time`
- `--benchmark-warmup-time`
- `--benchmark-warmup-rows`
- `--benchmark-tables`
- `--benchmark-table-size`
- `--benchmark-db`
- `--benchmark-rand-type`
- `--benchmark-keep-data`
- `--report-dir`

---

## 8. 当前默认值

- namespace: `aict`
- replicas: `1`
- storageClass: `nfs`
- storage size: `10Gi`
- service name: `mysql`
- sts name: `mysql`
- nodePort service name: `mysql-nodeport`
- nodePort: `30306`
- nodePort enabled: `true`
- backup backend: `nfs`
- backup nfs path: `/data/nfs-share`
- backup root dir: `backups`
- backup retention: `5`
- report dir: `./reports`
- benchmark profile: `standard`
- benchmark threads: `32`
- benchmark time: `180`
- benchmark warmup time: `30`
- benchmark warmup rows: `10000`
- benchmark tables: `8`
- benchmark table size: `100000`

默认开启的能力：

- monitoring
- service-monitor
- fluentbit
- backup
- benchmark

---

## 9. 这次重点修复和调整了什么

### 9.1 installer 源码组织

- 从“每个函数一个文件”改成“每个职责一个模块”
- assembler 不再依赖 `module-order.txt`
- 直接按 `scripts/install/modules/*.sh` 的有序文件名组装

### 9.2 backup / restore 认证逻辑

对下面几个动作：

- `backup`
- `restore`
- `verify-backup-restore`
- `addon-install --addons backup`

不再默认回退到 `--root-password`。

现在要求：

- 显式传 `--mysql-password`
- 或提供已经存在的 `--mysql-auth-secret`

这样能避免“目标 secret 不存在时误用默认 root 密码创建错误 secret”的问题。

### 9.3 latest 快照回退

当 `latest.txt` 指向的快照已经被清理后：

- 不会直接报错终止
- 会自动回退到当前目录里最新的 `.sql.gz`

### 9.4 NodePort 开关

新增：

- `--nodeport-enabled`
- `--enable-nodeport`
- `--disable-nodeport`

NodePort Service 不再强制创建。

### 9.5 镜像仓库前缀可配置

新增：

- `--registry <repo-prefix>`

用于把离线镜像重打标签到指定仓库前缀。

### 9.6 benchmark 工程化输出

benchmark 现在会输出：

- 完整 Job 日志：`*.log`
- 文本报告：`*.txt`
- JSON 报告：`*.json`

并且：

- `warmup rows` 与正式 `table size` 已解耦
- 对 MySQL 8 自动附加更宽松兼容参数
- 日志跟随改成轮询 tail，避免重复启动多个 `kubectl logs -f`

### 9.7 备份目录可写性探测

备份脚本会在目标目录下先做写入探测：

- `mkdir -p`
- 写一个临时探针文件
- 失败则明确报错目录不可写

---

## 10. 常用示例

### 10.1 首次安装，启用 NFS 备份

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --backup-nfs-path /data/nfs-share \
  -y
```

### 10.2 首次安装，但先关闭 NodePort 和备份

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --disable-nodeport \
  --disable-backup \
  -y
```

### 10.3 指定镜像前缀安装

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --registry harbor.example.com/kube4 \
  -y
```

### 10.4 给已有 MySQL 补监控

```bash
./dist/mysql-installer-amd64.run addon-install \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  -y
```

### 10.5 给已有 MySQL 补定时备份

```bash
./dist/mysql-installer-amd64.run addon-install \
  --namespace mysql-demo \
  --addons backup \
  --mysql-host mysql-0.mysql.mysql-demo.svc.cluster.local \
  --mysql-user root \
  --mysql-password 'StrongPassw0rd' \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  -y
```

### 10.6 立即执行一次备份

```bash
./dist/mysql-installer-amd64.run backup \
  --namespace mysql-demo \
  --mysql-host mysql-0.mysql.mysql-demo.svc.cluster.local \
  --mysql-user root \
  --mysql-password 'StrongPassw0rd' \
  --mysql-target-name mysql-demo \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --backup-nfs-path /data/nfs-share \
  -y
```

### 10.7 从 latest 恢复

```bash
./dist/mysql-installer-amd64.run restore \
  --namespace mysql-demo \
  --mysql-host mysql-0.mysql.mysql-demo.svc.cluster.local \
  --mysql-user root \
  --mysql-password 'StrongPassw0rd' \
  --mysql-target-name mysql-demo \
  --restore-snapshot latest \
  --mysql-restore-mode merge \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --backup-nfs-path /data/nfs-share \
  -y
```

### 10.8 运行 benchmark

```bash
./dist/mysql-installer-amd64.run benchmark \
  --namespace mysql-demo \
  --mysql-host mysql-0.mysql.mysql-demo.svc.cluster.local \
  --mysql-user root \
  --mysql-password 'StrongPassw0rd' \
  --benchmark-profile oltp-read-write \
  --benchmark-threads 64 \
  --benchmark-time 300 \
  --benchmark-warmup-time 30 \
  --benchmark-warmup-rows 10000 \
  --benchmark-table-size 300000 \
  --report-dir ./reports \
  -y
```

---

## 11. 你可以按这个 README 做验证

### 11.1 构建验证

检查 GitHub Actions 或 release 产物是否存在：

- `mysql-installer-amd64.run`
- `mysql-installer-amd64.run.sha256`
- `mysql-installer-arm64.run`
- `mysql-installer-arm64.run.sha256`

### 11.2 安装验证

执行 install 后检查：

```bash
kubectl get pods -n <ns>
kubectl get sts -n <ns>
kubectl get svc -n <ns>
kubectl get pvc -n <ns>
```

如果 NodePort 开启，再检查：

```bash
kubectl get svc -n <ns> <nodeport-service-name> -o yaml
```

### 11.3 addon 验证

监控 addon：

```bash
kubectl get deploy -n <ns> mysql-exporter
kubectl get svc -n <ns> mysql-exporter
kubectl get servicemonitor -n <ns>
```

备份 addon：

```bash
kubectl get cronjob -n <ns>
kubectl get configmap -n <ns> mysql-backup-scripts
kubectl get secret -n <ns>
```

### 11.4 backup / restore 验证

执行 `backup` 后检查：

```bash
kubectl get jobs -n <ns>
kubectl logs -n <ns> job/<backup-job-name>
```

执行 `restore` 后检查：

```bash
kubectl get jobs -n <ns>
kubectl logs -n <ns> job/<restore-job-name>
```

如果 `latest.txt` 指向旧文件，可以人工删掉对应快照后再次执行 `restore --restore-snapshot latest`，确认它会自动回退到当前最新 `.sql.gz`。

### 11.5 benchmark 验证

执行 `benchmark` 后检查：

```bash
kubectl get jobs -n <ns>
kubectl logs -n <ns> job/<benchmark-job-name>
ls -l ./reports
```

你应该能看到：

- `*.log`
- `*.txt`
- `*.json`

JSON 报告里应该包含：

- profile 信息
- TPS / QPS
- 延迟统计
- latency histogram

---

## 12. 维护约定

### 修改 installer 时请遵守

1. 日常维护只改 `scripts/install/modules/*.sh`
2. 不要手工直接改根目录 `install.sh`
3. 修改后执行 `scripts/assemble-install.sh install.sh`
4. 新逻辑优先按职责归并到已有模块，不要再回退到“函数一个文件”

### 新增模块的建议

只有当某个职责已经明显过大时，再新增模块，比如：

- 新增一整块新的 action
- 新增一整类模板渲染能力
- 新增完整的外置能力体系

不要为了“形式上的拆分”而增加文件数量。

---

## 13. 补充文档

- [架构说明](docs/ARCHITECTURE.zh-CN.md)
- [Addon 说明](docs/ADDONS.zh-CN.md)
- [使用场景](docs/USE-CASES.zh-CN.md)
- [测试说明](docs/TESTING.zh-CN.md)
- [2026-04-06 installer 源码组织 ADR](docs/plans/2026-04-06-installer-source-layout-adr.md)

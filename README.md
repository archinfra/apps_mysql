# apps_mysql

面向 Kubernetes 的 MySQL 离线安装器项目。

当前支持：

- 离线构建安装包
- `install` 全量对齐安装
- `addon-install` / `addon-uninstall` 外置能力补装
- NFS / S3 备份
- 恢复与备份恢复闭环校验
- `benchmark` 压测
- GitHub Actions 自动构建与发版

当前文档对应版本：`v1.5.3`

---

## 1. 先回答最关键的问题

### 1.1 根目录 `install.sh` 现在还有没有用

有用，而且必须保留。

它现在的角色是：

1. 最终分发的 installer 脚本产物
2. `build.sh` 打包 `.run` 文件前使用的入口脚本
3. 用户排障时最直接可查看的完整执行脚本
4. CI 和本地做整体 shell 语法检查的目标文件

但它已经不是“日常维护源码入口”。

现在正确的维护方式是：

1. 日常改动优先修改 `scripts/install/modules/*.sh`
2. 再执行 `scripts/assemble-install.sh install.sh` 重新生成根目录 `install.sh`
3. 不要把根目录 `install.sh` 当成长期手工维护的主文件

### 1.2 为什么不再按函数拆分

之前把 `install.sh` 拆成大量“一个函数一个文件”的做法，实际维护体验并不好：

1. 一个需求经常跨很多函数，改动会散落到很多文件
2. review 很难看出改的是“一个功能”还是“几段零散 shell”
3. 新维护者不容易快速定位应该修改哪里
4. 目录结构更像 shell AST，而不是工程目录

现在改为“按职责拆分”：

1. 最终产物仍然是单文件 `install.sh`
2. 源码入口改成 `scripts/install/modules/*.sh`
3. 每个模块负责一块明确职责，而不是单个函数

这比函数级拆分更符合工程化维护。

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
|           |-- 30-args.sh
|           |-- 40-inputs-and-plan.sh
|           |-- 50-render-and-apply.sh
|           |-- 60-runtime.sh
|           |-- 70-lifecycle-actions.sh
|           |-- 80-data-actions.sh
|           `-- 90-benchmark-and-main.sh
`-- docs/
```

### 2.1 模块职责

- `00-header.sh`
  变量、默认值、颜色、版本、镜像名
- `10-core.sh`
  基础日志函数、通用小工具
- `20-help.sh`
  所有帮助文案
- `30-args.sh`
  参数解析、addon 解析、默认值推导、动作门禁
- `40-inputs-and-plan.sh`
  输入校验、认证处理、执行计划、确认逻辑
- `50-render-and-apply.sh`
  镜像准备、模板渲染、资源 apply
- `60-runtime.sh`
  wait/job/log/report/mysql 等运行时公共逻辑
- `70-lifecycle-actions.sh`
  install / uninstall / status / addon 相关动作
- `80-data-actions.sh`
  backup / restore / verify-backup-restore
- `90-benchmark-and-main.sh`
  benchmark、收尾输出、cleanup、main

### 2.2 哪些文件应该改

应该改：

- `scripts/install/modules/*.sh`
- `manifests/*.yaml`
- `images/image.json`
- `build.sh`
- 各类文档

不应该作为长期源码入口直接改：

- 根目录 `install.sh`

---

## 3. 构建方式

### 3.1 本地构建

```bash
chmod +x build.sh install.sh scripts/assemble-install.sh
./build.sh --arch amd64
./build.sh --arch arm64
./build.sh --arch all
```

构建时会自动执行：

1. 从 `scripts/install/modules/*.sh` 组装出根目录 `install.sh`
2. 根据 `images/image.json` 拉取并打包离线镜像
3. 把 `install.sh` 与 payload 拼成 `.run` 文件

产物：

```text
dist/mysql-installer-amd64.run
dist/mysql-installer-amd64.run.sha256
dist/mysql-installer-arm64.run
dist/mysql-installer-arm64.run.sha256
```

### 3.2 GitHub Actions

- push 到 `main`：触发构建
- push `v*` tag：触发构建并发布 release

### 3.3 推荐维护动作

如果你修改了 installer 源码，推荐顺序是：

```bash
bash scripts/assemble-install.sh install.sh
bash -n install.sh
bash -n build.sh
bash -n scripts/assemble-install.sh
```

---

## 4. 命令模型

### 4.1 install

用于全量安装或重新对齐 MySQL 资源。

适合场景：

1. 首次安装
2. 调整副本数、存储、NodePort、功能开关
3. 重新对齐 StatefulSet 与相关资源
4. 可以接受必要时的滚动更新

### 4.2 addon-install

用于给“已经存在的 MySQL”补装外置能力。

当前支持：

- `monitoring`
- `service-monitor`
- `backup`

原则：

1. 尽量新增外围资源
2. 尽量不重写 MySQL StatefulSet
3. 尽量不影响正在运行的 MySQL Pod

### 4.3 addon-uninstall

用于移除外置 addon 资源。

### 4.4 backup

立即执行一次备份 Job。

注意：

1. 这不是安装定时备份
2. 不会创建 CronJob
3. 只会创建一次性 Job

### 4.5 restore

基于快照执行恢复。

注意：

1. `--restore-snapshot latest` 会优先读取 `latest.txt`
2. 如果 `latest.txt` 指向的快照已不存在，会自动回退到最新 `.sql.gz`

### 4.6 verify-backup-restore

执行一次备份恢复闭环校验。

### 4.7 benchmark

执行一次工程化 benchmark Job，并输出：

1. 完整日志 `.log`
2. 文本报告 `.txt`
3. JSON 报告 `.json`

---

## 5. 关键参数

### 5.1 基础参数

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

### 5.2 NodePort 参数

- `--nodeport-enabled true|false`
- `--enable-nodeport`
- `--disable-nodeport`
- `--node-port`
- `--nodeport-service-name`

### 5.3 镜像参数

- `--registry <repo-prefix>`
- `--skip-image-prepare`

### 5.4 MySQL 目标连接参数

- `--mysql-host`
- `--mysql-port`
- `--mysql-user`
- `--mysql-password`
- `--mysql-auth-secret`
- `--mysql-password-key`
- `--mysql-target-name`

### 5.5 备份参数

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

### 5.6 benchmark 参数

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

## 6. 关键行为与边界

### 6.1 backup / restore / verify-backup-restore 认证要求

对以下动作：

- `backup`
- `restore`
- `verify-backup-restore`
- `addon-install --addons backup`

现在要求显式提供可用的 MySQL 认证信息：

1. 直接传 `--mysql-password`
2. 或提供已存在的 `--mysql-auth-secret`

不再默认回退到 `--root-password`。

这是为了避免：

1. 目标 Secret 不存在时误创建错误 Secret
2. 把安装本体密码和运行期连接密码混为一谈

### 6.2 NodePort 开关

新增：

- `--nodeport-enabled`
- `--enable-nodeport`
- `--disable-nodeport`

NodePort Service 不再强制创建。

### 6.3 镜像前缀可配置

新增：

- `--registry <repo-prefix>`

用于把离线镜像重打标签到指定仓库前缀。

### 6.4 benchmark 镜像策略

benchmark 不再通过仓库内 Dockerfile 自建 sysbench 镜像。

现在直接使用官方镜像：

- `openeuler/sysbench:1.0.20-oe2403sp1`

这样构建链路更短，复现性更高。

---

## 7. 当前默认值

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

默认开启：

- monitoring
- service-monitor
- fluentbit
- backup
- benchmark

---

## 8. 常用示例

### 8.1 首次安装，启用 NFS 备份

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --backup-nfs-path /data/nfs-share \
  -y
```

### 8.2 首次安装，但关闭 NodePort 和备份

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --disable-nodeport \
  --disable-backup \
  -y
```

### 8.3 指定镜像前缀安装

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --registry harbor.example.com/kube4 \
  -y
```

### 8.4 给已有 MySQL 补监控

```bash
./dist/mysql-installer-amd64.run addon-install \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  -y
```

### 8.5 给已有 MySQL 补定时备份

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

### 8.6 立即执行一次备份

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

### 8.7 从 latest 恢复

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

### 8.8 运行 benchmark

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

## 9. 按 README 做验证

### 9.1 构建验证

检查 GitHub Actions 或 release 产物是否存在：

- `mysql-installer-amd64.run`
- `mysql-installer-amd64.run.sha256`
- `mysql-installer-arm64.run`
- `mysql-installer-arm64.run.sha256`

### 9.2 安装验证

```bash
kubectl get pods -n <ns>
kubectl get sts -n <ns>
kubectl get svc -n <ns>
kubectl get pvc -n <ns>
```

如果开启 NodePort，再检查：

```bash
kubectl get svc -n <ns> <nodeport-service-name> -o yaml
```

### 9.3 addon 验证

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

### 9.4 backup / restore 验证

```bash
kubectl get jobs -n <ns>
kubectl logs -n <ns> job/<job-name>
```

如果 `latest.txt` 指向旧文件，可以删掉对应快照后再次执行：

```bash
./dist/mysql-installer-amd64.run restore ... --restore-snapshot latest
```

确认它会自动回退到当前最新 `.sql.gz`。

### 9.5 benchmark 验证

```bash
kubectl get jobs -n <ns>
kubectl logs -n <ns> job/<benchmark-job-name>
ls -l ./reports
```

应看到：

- `*.log`
- `*.txt`
- `*.json`

---

## 10. 维护约定

1. 日常维护只改 `scripts/install/modules/*.sh`
2. 不直接把根目录 `install.sh` 当主源码编辑
3. 修改后执行 `scripts/assemble-install.sh install.sh`
4. 如果改动影响用户行为，同步更新 `README`、`docs/ARCHITECTURE.zh-CN.md`、`docs/ADDONS.zh-CN.md`、`docs/USE-CASES.zh-CN.md`
5. 只有在职责边界明显扩张时才新增模块，不回退到“一个函数一个文件”

---

## 11. 相关文档

- [架构说明](docs/ARCHITECTURE.zh-CN.md)
- [Addon 说明](docs/ADDONS.zh-CN.md)
- [使用场景](docs/USE-CASES.zh-CN.md)
- [测试说明](docs/TESTING.zh-CN.md)
- [2026-04-06 installer 源码组织 ADR](docs/plans/2026-04-06-installer-source-layout-adr.md)

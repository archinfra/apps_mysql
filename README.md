# apps_mysql

面向 Kubernetes 的 MySQL 8.4 LTS 离线交付、监控、压测与数据保护接入工具包。

当前标准交付基线：

- `apps_mysql`: `v1.6.0`
- MySQL: `8.4.11 LTS`
- `mysqld-exporter`: `v0.19.0`
- 架构：`amd64` / `arm64`
- 部署模式：**单实例、单副本**
- 监控：默认开启
- NodePort：默认关闭
- root / exporter 密码：默认不再使用固定密码

> 当前版本明确只提供单实例 MySQL。`--mysql-replicas` 必须为 `1`；多副本 StatefulSet 不等于 MySQL HA。

---

## 1. 这个仓库解决什么问题

仓库会构建 3 类离线 `.run` 产物：

```text
mysql-installer-<version>-<arch>.run
mysql-monitoring-<version>-<arch>.run
mysql-benchmark-<version>-<arch>.run
```

能力边界如下：

| 产物 | 用途 |
| --- | --- |
| `mysql-installer` | 新装 / 对齐 MySQL、监控、日志、数据保护注册 |
| `mysql-monitoring` | 给已有 MySQL 补独立 exporter / ServiceMonitor / Dashboard / Alert |
| `mysql-benchmark` | 对现有 MySQL 执行标准化 sysbench 压测并输出报告 |

备份恢复任务本身由独立 `dataprotection` 系统执行；`apps_mysql` 负责注册 `BackupAddon / BackupSource / BackupPolicy`。

---

## 2. 最快开始

### 2.1 新装一个默认单实例

```bash
./mysql-installer-v1.6.0-amd64.run install -y
```

默认会：

- 创建 namespace `aict`（不存在时）
- 创建单副本 StatefulSet `mysql`
- 创建 headless Service `mysql`
- 创建 PVC `data-mysql-0`
- 自动生成 root 密码并写入 `Secret/mysql-auth`
- 默认开启 `mysqld-exporter v0.19.0`
- 默认创建 metrics Service / ServiceMonitor / PrometheusRule
- 默认创建 Grafana Dashboard ConfigMap
- 默认关闭 NodePort
- 如果 dataprotection CRD 与 BackupStorage 已存在，则自动注册数据保护对象

查看 root 密码：

```bash
kubectl get secret -n aict mysql-auth \
  -o jsonpath='{.data.mysql-root-password}' | base64 -d; echo
```

查看状态：

```bash
./mysql-installer-v1.6.0-amd64.run status -n aict
```

集群内默认访问地址：

```text
mysql-0.mysql.aict.svc.cluster.local:3306
```

---

## 3. 默认部署契约

| 项目 | 默认值 | 说明 |
| --- | --- | --- |
| namespace | `aict` | 可通过 `--namespace` 修改 |
| StatefulSet | `mysql` | 单副本 |
| Service | `mysql` | headless Service |
| replicas | `1` | 当前固定支持单实例 |
| MySQL | `8.4.11` | LTS 基线 |
| exporter | `v0.19.0` | 默认 sidecar |
| root Secret | `mysql-auth` | 首次安装自动生成密码 |
| StorageClass | `nfs` | **兼容默认值；生产建议显式指定块存储** |
| PVC | `20Gi` | 生产通常应显式扩大 |
| MySQL port | `3306` | ClusterIP 内访问 |
| NodePort | 关闭 | 需要时显式 `--enable-nodeport` |
| NodePort port | `30306` | 仅开启 NodePort 后生效 |
| monitoring | 开启 | exporter + rules + dashboard |
| ServiceMonitor | 开启 | CRD 不存在时自动跳过 |
| metrics port | `9104` | `mysql-metrics` |
| Fluent Bit | 关闭 | 默认依赖 stdout/stderr |
| data protection | 开启 | 条件满足时自动注册 |
| slow query threshold | `2s` | `--mysql-slow-query-time` 可调 |
| wait timeout | `10m` | `--wait-timeout` 可调 |
| resource profile | `mid` | `low / mid / high` |

### 安装端依赖

运行已经构建好的 `.run` 安装包时：

- 必需：`kubectl`
- 默认镜像导入/推送模式需要：`docker`
- **不要求目标环境安装 `jq`**

`jq` 只用于仓库侧执行 `build.sh` 构建离线安装包，不属于客户环境运行依赖。

---

## 4. 推荐安装方式

### 4.1 测试 / Demo

适合功能验证、小数据量环境：

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-demo \
  --resource-profile low \
  --storage-class nfs \
  --storage-size 20Gi \
  --disable-data-protection \
  -y
```

推荐原则：

- `low`
- 20Gi 起步
- NFS 可以用于测试
- NodePort 仍建议默认关闭
- 监控建议保留开启

### 4.2 标准生产环境

推荐作为大多数私有化项目的起点：

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-prod \
  --storage-class ceph-rbd \
  --storage-size 100Gi \
  --resource-profile mid \
  --root-password 'Strong-Password-Here' \
  --backup-storage-name minio-primary \
  --backup-schedule '0 */6 * * *' \
  --backup-retention-ref keep-last-3 \
  -y
```

推荐原则：

- 优先使用 Ceph RBD、SAN、Local PV、云盘等块存储
- PVC 建议从 `100Gi` 起，根据业务增长评估
- 监控、告警、Dashboard 保持默认开启
- NodePort 保持关闭，通过业务网络、Gateway、VPN、跳板机等受控方式访问
- root 密码可显式指定；不指定则安装器自动生成
- 数据保护系统可用时保留默认注册

### 4.3 较高负载 / 较大工作集

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-prod \
  --storage-class ceph-rbd \
  --storage-size 500Gi \
  --resource-profile high \
  --mysql-slow-query-time 1 \
  --root-password 'Strong-Password-Here' \
  -y
```

建议先使用 `mysql-benchmark` 在目标存储与节点上做压测，再确定最终资源配置。

> `resource-profile` 只控制 Kubernetes CPU / Memory requests 与 limits，**不会自动按容器内存同比扩大 `innodb_buffer_pool_size`**。当前 MySQL runtime baseline 的 buffer pool 是 `512M`。如果是 4Gi、8Gi 或更大内存的生产实例，应根据实际工作集进一步定制 `manifests/mysql-runtime-config.yaml` 并重新构建交付包。

### 4.4 确实需要 NodePort

默认不开放 NodePort。如现场网络明确需要：

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-prod \
  --enable-nodeport \
  --node-port 30306 \
  --root-password 'Strong-Password-Here' \
  -y
```

外部访问：

```text
<NODE_IP>:30306
```

生产环境开启 NodePort 后，应同时通过防火墙、ACL、NetworkPolicy 或上层网络控制来源地址。

---

## 5. Resource Profile

支持：

```text
low
mid
midd   # mid 的兼容别名
high
```

| Profile | MySQL request | MySQL limit | Exporter request | Exporter limit | 建议用途 |
| --- | --- | --- | --- | --- | --- |
| `low` | `200m / 512Mi` | `500m / 1Gi` | `50m / 64Mi` | `100m / 128Mi` | Demo / 验证 |
| `mid` | `500m / 1Gi` | `1 CPU / 2Gi` | `100m / 128Mi` | `200m / 256Mi` | 标准生产起点 |
| `high` | `1 CPU / 2Gi` | `2 CPU / 4Gi` | `200m / 256Mi` | `500m / 512Mi` | 较高负载 |

可选 Fluent Bit 对应资源也会随 profile 调整。

这些 profile 是交付起点，不是容量承诺。最终资源必须结合：

- 数据量
- QPS / TPS
- 活跃连接数
- 热数据规模
- SQL 类型
- 磁盘 IOPS / latency
- 备份窗口

一起评估。

---

## 6. MySQL 8.4 默认运行配置

安装器会对齐 `manifests/mysql-runtime-config.yaml`，该文件是当前 MySQL 8.4 运行基线。

### 6.1 安全与网络面

```ini
bind-address=0.0.0.0
mysqlx=0
skip_name_resolve=ON
local_infile=OFF
max_allowed_packet=64M
max_connections=300
back_log=128
thread_cache_size=64
```

说明：

- `mysqlx=0`：默认关闭不使用的 X Protocol
- `local_infile=OFF`：降低不必要的文件导入风险
- `skip_name_resolve=ON`：避免授权解析依赖 DNS，并减少连接建立抖动
- `max_connections=300`：给出可控上限，避免无限扩大连接占用

### 6.2 InnoDB 与持久性

```ini
default_storage_engine=InnoDB
innodb_flush_log_at_trx_commit=1
sync_binlog=1
innodb_buffer_pool_size=512M
innodb_log_buffer_size=64M
innodb_redo_log_capacity=1G
innodb_file_per_table=ON
```

当前默认优先事务持久性，不为了 benchmark 使用高风险的异步刷盘参数。

### 6.3 临时表与缓存

```ini
tmp_table_size=32M
max_heap_table_size=32M
table_open_cache=2000
table_definition_cache=1400
```

不要简单把 `tmp_table_size` / `max_heap_table_size` 调得很大，因为这些配置与并发连接共同影响内存占用。

### 6.4 日志与可观测性

```ini
performance_schema=ON
log_error_verbosity=2
slow_query_log=ON
long_query_time=2
log_queries_not_using_indexes=OFF
```

`long_query_time` 可通过安装参数调整：

```bash
--mysql-slow-query-time 1
```

### 6.5 Binlog / GTID

```ini
log_bin=mycluster
binlog_format=ROW
binlog_expire_logs_seconds=604800
enforce_gtid_consistency=ON
gtid_mode=ON
```

默认保留 7 天 binlog，为审计、排障、备份和后续 PITR 能力预留基础。

### 如何做长期个性化 MySQL 配置

对于以下参数：

- `innodb_buffer_pool_size`
- `innodb_redo_log_capacity`
- `max_connections`
- `tmp_table_size`
- `table_open_cache`
- binlog 保留周期

当前没有全部暴露成 CLI 参数。需要长期固化时，推荐：

1. 修改 `manifests/mysql-runtime-config.yaml`
2. 提交代码评审
3. 重新构建 `.run` 安装包
4. 在测试环境验证后再交付

不建议把 `kubectl edit configmap` 当成长期配置管理方式，因为再次执行 installer 会按仓库基线重新对齐。

---

## 7. 密码与安全模型

### root

首次安装：

- 传 `--root-password`：使用显式密码
- 不传：自动生成随机密码

已有环境再次执行 installer：

- 如果 `Secret/mysql-auth` 已存在，会复用已有密码
- 不会因为 reconcile 自动随机换 root 密码

查看密码：

```bash
kubectl get secret -n aict mysql-auth \
  -o jsonpath='{.data.mysql-root-password}' | base64 -d; echo
```

### mysqld-exporter

Exporter 不再使用 root 账号。

默认账号：

```text
mysqld_exporter
```

安装器自动生成 exporter 密码，并创建 / 对齐低权限账号，权限主要包括：

```text
PROCESS
REPLICATION CLIENT
SELECT
```

同时限制 `MAX_USER_CONNECTIONS 3`。

### 健康检查

MySQL 8.4 runtime probe 使用本地 TCP `mysqladmin ping`，不再依赖旧的固定密码 health-check 用户。

---

## 8. 监控设计

默认内嵌：

```text
mysqld-exporter v0.19.0
metrics Service: mysql-metrics:9104
ServiceMonitor: mysql-monitor
PrometheusRule: mysql-alerts
Grafana folder: Middleware/MySQL
```

Prometheus 发现协议：

```yaml
monitoring.archinfra.io/stack: default
```

Grafana Dashboard 自动发现：

```yaml
grafana_dashboard: "1"
grafana_folder: Middleware/MySQL
```

### 默认 exporter collectors

除 exporter 默认 collector 外，额外开启：

```text
collect.info_schema.innodb_metrics
collect.info_schema.processlist
collect.binlog_size
```

没有默认全开高基数 performance schema collector，避免不必要的 Prometheus cardinality 和数据库采集开销。

---

## 9. Grafana Dashboard

默认创建两套 Dashboard：

```text
Middleware/MySQL
├── MySQL / Overview
└── MySQL / Performance
```

### MySQL / Overview

用于值班与快速判断：

- MySQL Up / Uptime
- Connection Usage
- Threads Running
- QPS
- Slow Query Ratio
- SELECT / INSERT / UPDATE / DELETE throughput
- Connections / Threads
- Slow / Aborted Connections
- InnoDB Buffer Pool Hit Ratio
- Deadlocks / Row Lock Wait
- Temporary Tables on Disk
- MySQL Container CPU
- CPU throttling
- MySQL Container Memory
- PVC Usage

### MySQL / Performance

用于进一步性能分析，重点查看：

- Buffer Pool 使用与脏页
- InnoDB row operations
- Query throughput
- Connection 行为
- Lock / contention
- 临时表
- Binlog
- Process / InnoDB 相关性能指标

---

## 10. 默认告警与阈值

当前单实例生产基线包含以下核心告警：

| Alert | Severity | 默认条件 |
| --- | --- | --- |
| `MySQLExporterDown` | critical | exporter 连续 `2m` 无法被抓取 |
| `MySQLDown` | critical | `mysql_up == 0` 持续 `2m` |
| `MySQLConnectionsHigh` | warning | connections > `80%` 持续 `10m` |
| `MySQLConnectionsCritical` | critical | connections > `90%` 持续 `5m` |
| `MySQLAbortedConnectionsHigh` | warning | 10m aborted ratio > `5%`，持续 `10m` |
| `MySQLThreadsRunningHigh` | warning | running threads > `16` 持续 `10m` |
| `MySQLSlowQueryRatioHigh` | warning | slow query ratio > `1%` 持续 `10m` |
| `MySQLSlowQueryRatioCritical` | critical | slow query ratio > `5%` 持续 `5m` |
| `MySQLDeadlocksDetected` | warning | 最近 10m 出现 deadlock |
| `MySQLRowLockWaitHigh` | warning | current row lock waits > `5` 持续 `5m` |
| `MySQLBufferPoolHitRatioLow` | warning | 有有效读负载时 hit ratio < `99%` 持续 `15m` |
| `MySQLBufferPoolHitRatioCritical` | critical | 有有效读负载时 hit ratio < `95%` 持续 `10m` |
| `MySQLTmpDiskTablesHigh` | warning | 临时表数量足够时 disk tmp ratio > `25%` 持续 `15m` |
| `MySQLPVCUsageHigh` | warning | PVC > `80%` 持续 `15m` |
| `MySQLPVCUsageCritical` | critical | PVC > `90%` 持续 `5m` |

这些阈值是统一交付 baseline。对于明确的高并发、批处理、ETL 或特殊业务，应结合历史数据再调，避免简单照搬。

---

## 11. 已有 MySQL 只补监控

如果不希望修改已有 StatefulSet，使用独立 monitoring 包：

```bash
./mysql-monitoring-v1.6.0-amd64.run addon-install \
  --namespace aict \
  --addons monitoring,service-monitor \
  --monitoring-target mysql-0.mysql.aict:3306 \
  --mysql-password 'Admin-Password' \
  -y
```

它会额外创建 exporter Deployment / Service / Secret / ServiceMonitor / PrometheusRule / Dashboard，不修改原 MySQL StatefulSet。

如果已有管理员凭据允许建账，安装器会创建低权限 exporter 用户。

---

## 12. 日志

默认：

- error log：`/var/log/mysql/error.log`
- slow log：`/var/log/mysql/slow.log`
- error log 同步到容器 stderr
- 未启用 Fluent Bit 时 slow log 同步到容器 stdout

直接查看：

```bash
kubectl logs -n aict mysql-0 -c mysql --tail=200
```

如果平台已经统一采集容器 stdout/stderr，通常无需启用 Fluent Bit sidecar。

确需 Pod 内独立慢日志采集链路时：

```bash
--enable-fluentbit
```

---

## 13. 数据保护

默认参数：

```text
backup namespace: backup-system
primary storage: minio-primary
schedule: 0 */6 * * *
retention: keep-last-3
```

安装器会检查 dataprotection CRD 与 BackupStorage：

- 条件满足：自动注册 `BackupAddon / BackupSource / BackupPolicy`
- 条件不满足：给出 warning 并跳过注册，不阻断 MySQL 本体安装

典型生产安装：

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-prod \
  --storage-class ceph-rbd \
  --storage-size 100Gi \
  --backup-storage-name minio-primary \
  --backup-secondary-storage-name minio-dr \
  --backup-schedule '0 */6 * * *' \
  --backup-retention-ref keep-last-3 \
  --backup-notification-ref ops-alert \
  -y
```

备份恢复执行仍属于 dataprotection controller，不由 `apps_mysql` 直接执行。

---

## 14. Benchmark

```bash
./mysql-benchmark-v1.6.0-amd64.run benchmark \
  --namespace mysql-prod \
  --mysql-host mysql-0.mysql.mysql-prod.svc.cluster.local \
  --mysql-user root \
  --mysql-password 'Strong-Password-Here' \
  --benchmark-profile oltp-read-write \
  --benchmark-threads 64 \
  --benchmark-time 300 \
  --benchmark-tables 8 \
  --benchmark-table-size 100000 \
  --report-dir ./reports \
  -y
```

支持 profile：

```text
standard
oltp-point-select
oltp-read-only
oltp-read-write
```

输出包括：

- 完整 Job 日志
- 文本报告
- JSON 结构化报告

生产调优建议先测：

1. 存储 latency / IOPS
2. `mid` profile
3. `high` profile
4. 再决定 MySQL runtime 参数是否需要调整

---

## 15. 常用运维命令

### 查看资源

```bash
kubectl get sts,pod,svc,pvc -n aict
kubectl get servicemonitor,prometheusrule -n aict
```

### 查看 MySQL 日志

```bash
kubectl logs -n aict mysql-0 -c mysql --tail=200
```

### 查看 exporter

```bash
kubectl logs -n aict mysql-0 -c mysqld-exporter --tail=200
```

### 进入 MySQL

```bash
MYSQL_PWD="$(kubectl get secret -n aict mysql-auth -o jsonpath='{.data.mysql-root-password}' | base64 -d)"
kubectl exec -it -n aict mysql-0 -c mysql -- \
  env MYSQL_PWD="${MYSQL_PWD}" mysql -uroot
```

### 重跑 installer

Installer 采用声明式对齐思路。相同 namespace / StatefulSet name / Secret 下重跑可用于配置对齐。

注意：runtime ConfigMap 通过 `subPath` 挂载，配置发生变化时 installer 会滚动重启单实例 Pod 使配置生效。

---

## 16. 卸载与数据保留

默认卸载不删除 PVC：

```bash
./mysql-installer-v1.6.0-amd64.run uninstall -n aict -y
```

只有明确需要删除数据时才使用：

```bash
--delete-pvc
```

生产环境执行卸载前应先确认：

- 最新备份成功
- 恢复路径已验证
- PVC 是否需要保留
- 是否存在依赖 MySQL 的业务

---

## 17. MySQL 8.0 -> 8.4 升级说明

**不要把更换 image tag 当作完整数据库升级流程。**

当前 v1.6.0 主要作为 MySQL 8.4.11 的新装标准基线。

已有 MySQL 8.0 PVC 升级到 8.4 前至少应该完成：

1. 全量备份
2. 恢复验证
3. MySQL Upgrade Checker
4. schema / charset / deprecated configuration 检查
5. 在测试环境复制数据进行升级演练
6. 规划停机或切换窗口
7. 升级后执行业务、数据一致性和监控验收

更详细的 8.4 基线说明见：

```text
docs/MYSQL-8.4-BASELINE.md
```

---

## 18. 参数速查

### 安装

```text
--namespace <ns>
--root-password <password>
--auth-secret <name>
--mysql-replicas 1
--storage-class <name>
--storage-size <size>
--resource-profile <low|mid|high>
--service-name <name>
--sts-name <name>
--mysql-slow-query-time <seconds>
--wait-timeout <duration>
```

### 访问暴露

```text
--enable-nodeport
--disable-nodeport
--node-port <30000-32767>
--nodeport-service-name <name>
```

### 监控

```text
--enable-monitoring
--disable-monitoring
--enable-service-monitor
--disable-service-monitor
--exporter-user <user>
--exporter-password <password>
--monitoring-target <host:port>
```

### 日志

```text
--enable-fluentbit
--disable-fluentbit
```

### 数据保护

```text
--enable-data-protection
--disable-data-protection
--backup-namespace <ns>
--backup-storage-name <name>
--backup-secondary-storage-name <name>
--backup-schedule <cron>
--backup-retention-ref <name>
--backup-notification-ref <name>
--backup-database <name>
```

### 镜像仓库

```text
--registry <repo-prefix>
--skip-image-prepare
```

安装包内置帮助：

```bash
./mysql-installer-v1.6.0-amd64.run help install
./mysql-installer-v1.6.0-amd64.run help params
./mysql-installer-v1.6.0-amd64.run help architecture
```

---

## 19. 构建离线安装包

构建机需要：

- Docker
- `jq`
- Bash

示例：

```bash
./build.sh --arch amd64 --profile integrated --version v1.6.0
./build.sh --arch arm64 --profile integrated --version v1.6.0
./build.sh --arch all --profile all --version v1.6.0
```

CI 会验证：

- installer shell syntax
- MySQL `8.4.11` BOM
- exporter `v0.19.0` BOM
- amd64 / arm64 镜像可用性
- Grafana Dashboard JSON
- Monitoring invariants
- checksum
- integrated / monitoring / benchmark 六种组合构建

---

## 20. 生产交付建议清单

正式交付前建议至少确认：

- [ ] 使用 MySQL 8.4.11 LTS
- [ ] replicas = 1，明确这是单实例方案
- [ ] 使用可靠块存储而非临时测试 NFS
- [ ] PVC 容量按数据增长预留
- [ ] NodePort 默认关闭；如开启则限制来源
- [ ] root 密码已安全保存
- [ ] exporter 使用独立低权限账号
- [ ] Prometheus target 为 UP
- [ ] PrometheusRule 已加载
- [ ] Grafana `MySQL / Overview` 与 `MySQL / Performance` 可正常打开
- [ ] 告警阈值结合现场负载复核
- [ ] slow query 阈值符合业务 SLA
- [ ] BackupPolicy 正常运行
- [ ] 至少做过一次真实恢复验证
- [ ] 使用 `mysql-benchmark` 留存目标环境基准报告
- [ ] 任何 MySQL runtime 参数变更都已进入代码和交付包，而不是只做现场手改

---

## 21. 相关文档

```text
docs/MYSQL-8.4-BASELINE.md
docs/MONITORING-V2.zh-CN.md
docs/ARCHITECTURE.zh-CN.md
docs/ADDONS.zh-CN.md
docs/TESTING.zh-CN.md
docs/USE-CASES.zh-CN.md
```

README 作为使用入口；更细的设计、测试和历史决策放在 `docs/` 中。
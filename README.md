# apps_mysql

面向 Kubernetes 的 MySQL 8.4 LTS 离线交付、监控、日志与压测工具包。

当前标准交付基线：

- `apps_mysql`: `v1.6.0`
- MySQL: `8.4.11 LTS`
- `mysqld-exporter`: `v0.19.0`
- 架构：`amd64` / `arm64`
- 部署模式：**单实例、单副本**
- NodePort：**默认关闭**
- 远程 root：**默认开启，默认 `root@'%'`**
- `mysql_native_password`：**暂时默认开启用于旧客户端兼容，后续计划关闭**
- 监控 / 告警 / Dashboard：默认开启

> 当前版本明确只提供单实例 MySQL。`--mysql-replicas` 必须为 `1`；多副本 StatefulSet 不等于 MySQL HA。

---

## 1. 产物与能力边界

仓库构建 3 类离线 `.run` 产物：

```text
mysql-installer-v1.6.0-<arch>.run
mysql-monitoring-v1.6.0-<arch>.run
mysql-benchmark-v1.6.0-<arch>.run
```

| 产物 | 用途 |
| --- | --- |
| `mysql-installer` | 新装 / reconcile MySQL、本地日志、内嵌监控、Dashboard、Alert |
| `mysql-monitoring` | 给已有 MySQL 补独立 exporter / ServiceMonitor / Dashboard / Alert |
| `mysql-benchmark` | 对 MySQL 执行标准化 sysbench 压测并输出报告 |

备份能力目前不是本轮交付重点。仓库仍保留 dataprotection 接入协议，但客户交付可通过 `--disable-data-protection` 暂时关闭，不影响 MySQL 本体、监控和日志能力。

---

## 2. 最快开始

### 2.1 默认安装

```bash
./mysql-installer-v1.6.0-amd64.run install -y
```

默认会：

- 创建 namespace `aict`（不存在时）
- 创建单副本 StatefulSet `mysql`
- 创建 headless Service `mysql`
- 创建 PVC `data-mysql-0`
- 自动生成 root 密码并写入 `Secret/mysql-auth`
- 创建并幂等对齐 `root@'%'`
- 默认启用 `mysql_native_password` 兼容插件
- 默认关闭 NodePort
- 默认开启 `mysqld-exporter v0.19.0`
- 创建 metrics Service / ServiceMonitor / PrometheusRule
- 创建 `MySQL / Overview` 与 `MySQL / Performance` Dashboard
- 默认输出错误日志与慢查询日志到容器日志

查看 root 密码：

```bash
kubectl get secret -n aict mysql-auth \
  -o jsonpath='{.data.mysql-root-password}' | base64 -d; echo
```

集群内访问地址：

```text
mysql-0.mysql.aict.svc.cluster.local:3306
```

查看状态：

```bash
./mysql-installer-v1.6.0-amd64.run status -n aict
```

---

## 3. 当前默认部署契约

| 项目 | 默认值 | 说明 |
| --- | --- | --- |
| namespace | `aict` | `--namespace` 可改 |
| StatefulSet | `mysql` | 单实例 |
| Service | `mysql` | headless Service |
| replicas | `1` | 当前固定单实例 |
| MySQL | `8.4.11 LTS` | amd64 / arm64 |
| exporter | `v0.19.0` | 默认 sidecar |
| root Secret | `mysql-auth` | 首次安装随机生成 |
| remote root | `true` | 默认创建 `root@'%'` |
| NodePort | `false` | 默认不暴露集群外端口 |
| StorageClass | `nfs` | 兼容默认；生产建议块存储 |
| PVC | `20Gi` | 生产建议显式扩大 |
| MySQL port | `3306` | 集群内 Service |
| NodePort port | `30306` | 只有开启 NodePort 才生效 |
| monitoring | `true` | exporter + rules + dashboards |
| Fluent Bit | `false` | 默认使用 stdout/stderr |
| log emptyDir limit | `2Gi` | 防止日志无限占用节点临时盘 |
| slow query threshold | `2s` | 可调 |
| timezone | `UTC` | DB 与错误日志统一 UTC |
| charset | `utf8mb4` | 显式固定 |
| collation | `utf8mb4_0900_ai_ci` | 显式固定 |
| wait timeout | `10m` | 可调 |
| resource profile | `mid` | `low / mid / high` |

### 安装端依赖

运行已经构建好的 `.run`：

- 必需：`kubectl`
- 默认离线镜像导入/推送：`docker`
- **目标/离线环境不要求安装 `jq`**

`jq` 只用于仓库侧执行 `build.sh` 构建离线安装包。

---

## 4. 推荐安装方式

### 4.1 Demo / 测试

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-demo \
  --resource-profile low \
  --storage-class nfs \
  --storage-size 20Gi \
  --disable-data-protection \
  -y
```

### 4.2 标准生产安装

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-prod \
  --storage-class ceph-rbd \
  --storage-size 100Gi \
  --resource-profile mid \
  --root-password 'Strong-Password-Here' \
  --disable-data-protection \
  -y
```

推荐原则：

- 优先使用 Ceph RBD / SAN / Local PV / 云盘等可靠块存储
- NodePort 保持关闭
- remote root 可以保留用于当前 Archinfra 组件兼容，但应通过集群网络 / NetworkPolicy / ACL 控制来源
- 生产 PVC 建议从 `100Gi` 起，根据增长量评估
- 监控、规则、Dashboard 保持默认开启

### 4.3 较高负载

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-prod \
  --storage-class ceph-rbd \
  --storage-size 500Gi \
  --resource-profile high \
  --mysql-slow-query-time 1 \
  --root-password 'Strong-Password-Here' \
  --disable-data-protection \
  -y
```

如需进一步调整 Buffer Pool：

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-prod \
  --resource-profile high \
  --innodb-buffer-pool-size 3G \
  -y
```

> 自定义 Buffer Pool 时必须同时考虑容器 memory limit、连接数、临时表和 per-session buffer，不能把全部内存都分给 InnoDB Buffer Pool。

---

## 5. Resource Profile

| Profile | MySQL Request | MySQL Limit | 默认 InnoDB Buffer Pool | 典型用途 |
| --- | --- | --- | --- | --- |
| `low` | `200m / 512Mi` | `500m / 1Gi` | `384M` | Demo / 小环境 |
| `mid` | `500m / 1Gi` | `1 CPU / 2Gi` | `1G` | 默认生产基线 |
| `high` | `1 CPU / 2Gi` | `2 CPU / 4Gi` | `2G` | 较高负载 |

`midd`、`middle`、`medium` 作为 `mid` 兼容别名。

覆盖 Buffer Pool：

```text
--innodb-buffer-pool-size 384M|1G|2G|...
```

---

## 6. root 账号与远程访问

### 6.1 默认策略

MySQL 容器初始化出的 `root@localhost` 保留本地管理能力。

安装完成后，installer 会使用本地 root 幂等执行远程 root 对齐：

```sql
CREATE USER IF NOT EXISTS 'root'@'%'
  IDENTIFIED WITH mysql_native_password BY '<Secret 中的密码>';

ALTER USER 'root'@'%'
  IDENTIFIED WITH mysql_native_password BY '<Secret 中的密码>';

GRANT ALL PRIVILEGES ON *.*
  TO 'root'@'%'
  WITH GRANT OPTION;
```

因此：

- 新装数据库会创建远程 root
- 老 PVC 重新跑 installer 也会自动补齐远程 root
- root 密码来自 `Secret/mysql-auth`
- 不依赖 `/docker-entrypoint-initdb.d` 只执行一次的初始化语义

### 6.2 remote root 不等于公网暴露

默认：

```text
remote root = true
NodePort    = false
```

也就是说默认只允许**能访问 Kubernetes MySQL Service 网络的客户端**尝试连接，并没有对所有外部主机开放 3306。

真正的网络访问范围仍应由：

- Kubernetes NetworkPolicy
- 防火墙 / ACL
- VPN / 堡垒机
- 项目网络边界

控制。

### 6.3 限制 root 来源

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --root-remote-host '10.%' \
  -y
```

`--root-remote-host` 是 **MySQL account host pattern**，不是 CIDR 网络策略。

### 6.4 关闭远程 root

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --disable-remote-root \
  -y
```

安装器会删除它管理的 `root@'%'` / 指定 host，保留 `root@localhost`。

### 6.5 root 密码 reconcile 规则

首次安装不传 `--root-password`：自动生成随机密码。

已有 `Secret/mysql-auth`：自动复用。

如果已有环境再次执行 install，却传入一个与现有 Secret 不同的 `--root-password`，installer 会**拒绝执行**，避免只改 Secret 而没有同步修改 MySQL 内部账号导致数据库被锁死。

root 在线轮换密码应走独立变更流程，不通过普通 `install` 隐式完成。

---

## 7. `mysql_native_password` 兼容策略

MySQL 8.4 已默认关闭并弃用 `mysql_native_password`，但当前一些历史 JDBC / MySQL client 可能仍依赖它。

为了当前私有化交付兼容性，本项目暂时默认：

```ini
mysql_native_password=ON
```

并让 installer 管理的远程 `root@<host>` 使用 `mysql_native_password`。

本地 `root@localhost` 和 `mysqld_exporter` 不强制使用该旧插件，默认仍使用 MySQL 8.4 的 `caching_sha2_password`。

当 Nacos 和所有业务客户端完成兼容验证后，可测试：

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --disable-native-password \
  -y
```

此时远程 root 会重新对齐为 MySQL 默认认证插件。

> 这是一项**过渡兼容策略**，不是长期安全目标，见文末 TODO。

---

## 8. NodePort

NodePort 默认关闭。

确需集群外直连时：

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --enable-nodeport \
  --node-port 30306 \
  -y
```

访问：

```text
<NODE_IP>:30306
```

再次执行：

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --disable-nodeport \
  -y
```

会删除之前遗留的 NodePort Service，reconcile 是幂等的。

---

## 9. MySQL 8.4 Runtime Baseline

运行配置来自：

```text
manifests/mysql-runtime-config.yaml
```

核心设置：

```ini
[mysqld]
bind-address=0.0.0.0
mysqlx=0
skip_name_resolve=ON
local_infile=OFF
mysql_native_password=ON

character_set_server=utf8mb4
collation_server=utf8mb4_0900_ai_ci
default_time_zone='+00:00'
log_timestamps=UTC

max_connections=300
back_log=128
thread_cache_size=64
max_allowed_packet=64M

innodb_flush_log_at_trx_commit=1
sync_binlog=1
innodb_buffer_pool_size=<profile>
innodb_log_buffer_size=64M
innodb_redo_log_capacity=1G
innodb_file_per_table=ON

tmp_table_size=32M
max_heap_table_size=32M
table_open_cache=2000
table_definition_cache=1400

performance_schema=ON
slow_query_log=ON
long_query_time=2
log_queries_not_using_indexes=OFF

log_bin=mycluster
binlog_format=ROW
binlog_expire_logs_seconds=604800
enforce_gtid_consistency=ON
gtid_mode=ON
```

设计原则：

- 单实例默认优先事务持久性，不使用 benchmark 型激进参数
- UTF-8 / UTC 明确成为 Archinfra 交付协议
- 保留 GTID / ROW binlog，为后续数据保护能力留基础
- `local_infile` 默认关闭
- X Protocol 默认关闭

---

## 10. Probe 与优雅停机

当前 StatefulSet：

```text
startupProbe
  periodSeconds: 10
  failureThreshold: 60
  => 最长约 10 分钟启动保护窗口

livenessProbe
  periodSeconds: 10
  failureThreshold: 3

readinessProbe
  periodSeconds: 5
  failureThreshold: 3

terminationGracePeriodSeconds: 120
```

这样可以覆盖：

- 首次初始化
- 较大数据目录启动
- InnoDB crash recovery
- 配置 reconcile / rollout restart

`startupProbe` 成功前 liveness 不会误杀正在恢复的 MySQL。

---

## 11. 日志

### 默认日志流

MySQL error log：

```text
/var/log/mysql/error.log
        -> tail
        -> mysql container stderr
```

Slow query log：

```text
/var/log/mysql/slow.log
        -> tail
        -> mysql container stdout
```

因此默认即可：

```bash
kubectl logs -n aict mysql-0 -c mysql --tail=200
kubectl logs -n aict mysql-0 -c mysql -f
```

### 本地日志空间

`/var/log/mysql` 使用 `emptyDir`：

```text
sizeLimit = 2Gi
```

可以通过：

```text
--mysql-log-size-limit <size>
```

调整。

Pod 内日志不是长期归档介质；正式环境应以 Kubernetes stdout/stderr + Loki / Elasticsearch / 其他集中日志平台作为长期保存路径。

### Fluent Bit

如项目明确需要 slow log sidecar：

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --enable-fluentbit \
  -y
```

启用后慢日志由 Fluent Bit sidecar tail 并输出，错误日志仍在 MySQL stderr。

---

## 12. 监控

默认内嵌：

```text
mysqld-exporter v0.19.0
```

独立低权限账号：

```text
mysqld_exporter
```

权限：

```text
PROCESS
REPLICATION CLIENT
SELECT
MAX_USER_CONNECTIONS 3
```

默认 collector：

```text
global status / variables
info_schema.innodb_metrics
info_schema.processlist
binlog_size
```

没有默认全开 performance schema 高基数 collector。

### Prometheus 发现协议

ServiceMonitor：

```yaml
monitoring.archinfra.io/stack: default
```

Grafana Dashboard：

```yaml
grafana_dashboard: "1"
grafana_folder: Middleware/MySQL
```

### Dashboard

```text
MySQL / Overview
MySQL / Performance
```

Overview 主要看：

- MySQL Up / Uptime
- Connections / Threads
- QPS / SQL throughput
- Slow Query Ratio
- Buffer Pool Hit Ratio
- Deadlock / Lock Wait
- Temporary Tables on Disk
- Pod CPU / Memory
- PVC Usage

Performance 主要看：

- Buffer Pool pages / reads
- InnoDB row operations
- InnoDB waits
- Transactions
- Binlog size
- Temporary tables
- Open files / tables
- MySQL network throughput

### 默认告警

| Alert | 默认阈值 |
| --- | --- |
| `MySQLExporterDown` | 2m |
| `MySQLDown` | 2m |
| `MySQLConnectionsHigh` | >80% / 10m |
| `MySQLConnectionsCritical` | >90% / 5m |
| `MySQLAbortedConnectionsHigh` | >5% / 10m |
| `MySQLThreadsRunningHigh` | >16 / 10m |
| `MySQLSlowQueryRatioHigh` | >1% / 10m |
| `MySQLSlowQueryRatioCritical` | >5% / 5m |
| `MySQLDeadlocksDetected` | >0 / 10m |
| `MySQLRowLockWaitHigh` | >5 / 5m |
| `MySQLBufferPoolHitRatioLow` | <99% / 15m，且有有效读负载 |
| `MySQLBufferPoolHitRatioCritical` | <95% / 10m，且有有效读负载 |
| `MySQLTmpDiskTablesHigh` | >25% / 15m |
| `MySQLPVCUsageHigh` | >80% / 15m |
| `MySQLPVCUsageCritical` | >90% / 5m |

这些是交付初始基线，生产项目应根据真实负载二次调参。

---

## 13. Manifest 结构

运行资源已经拆分，不再使用旧的单一大 manifest：

```text
manifests/
├── mysql-core.yaml
│   ├── Service
│   ├── StatefulSet
│   ├── exporter secret
│   ├── metrics service
│   ├── Fluent Bit config
│   └── NodePort(optional)
│
├── mysql-runtime-config.yaml
│   ├── probe scripts
│   └── MySQL 8.4 my.cnf
│
└── mysql-observability.yaml
    ├── ServiceMonitor
    ├── PrometheusRule
    └── Grafana dashboards
```

旧的：

```text
localroot
mysqlhealthchecker
health@passw0rd
local@paasw0rd
local_infile=1
旧 auth_socket 配置
```

已经从 manifest 交付路径中移除。

对历史 PVC reconcile 时，installer 还会清理可能遗留的：

```text
localroot@localhost
mysqlhealthchecker@localhost
ConfigMap/mysql-init-users
```

---

## 14. 常用参数

```text
--namespace <ns>
--root-password <password>
--auth-secret <name>

--enable-remote-root
--disable-remote-root
--root-remote-host <host>

--enable-native-password
--disable-native-password

--storage-class <name>
--storage-size <size>
--resource-profile low|mid|high
--innodb-buffer-pool-size <size>
--mysql-log-size-limit <size>

--enable-nodeport
--disable-nodeport
--node-port <port>

--enable-monitoring
--disable-monitoring
--enable-service-monitor
--disable-service-monitor
--enable-fluentbit
--disable-fluentbit

--mysql-slow-query-time <seconds>
--registry <repo-prefix>
--wait-timeout <duration>
```

完整帮助：

```bash
./mysql-installer-v1.6.0-amd64.run help install
./mysql-installer-v1.6.0-amd64.run help params
./mysql-installer-v1.6.0-amd64.run help logging
```

---

## 15. 只补监控

已有 MySQL，不想改 StatefulSet：

```bash
./mysql-monitoring-v1.6.0-amd64.run addon-install \
  --namespace aict \
  --addons monitoring,service-monitor \
  --monitoring-target mysql-0.mysql.aict.svc.cluster.local:3306 \
  --mysql-user root \
  --mysql-password '<MYSQL_PASSWORD>' \
  -y
```

如果目标 MySQL 已经嵌入 exporter，installer 会阻止重复叠加外置 exporter。

---

## 16. Benchmark

```bash
./mysql-benchmark-v1.6.0-amd64.run benchmark \
  --namespace aict \
  --mysql-host mysql-0.mysql.aict.svc.cluster.local \
  --mysql-user root \
  --mysql-password '<MYSQL_PASSWORD>' \
  --benchmark-profile oltp-read-write \
  --benchmark-threads 32 \
  --benchmark-time 300 \
  -y
```

支持：

```text
standard
oltp-point-select
oltp-read-only
oltp-read-write
```

报告写入 `--report-dir`，包括完整日志、文本摘要和 JSON 报告。

---

## 17. 运维命令

### Pod / Service / PVC

```bash
kubectl get pod -n aict -l app=mysql -o wide
kubectl get svc -n aict
kubectl get pvc -n aict
```

### MySQL 日志

```bash
kubectl logs -n aict mysql-0 -c mysql --tail=200
kubectl logs -n aict mysql-0 -c mysql -f
```

### 进入 MySQL

```bash
MYSQL_ROOT_PASSWORD="$(kubectl get secret -n aict mysql-auth \
  -o jsonpath='{.data.mysql-root-password}' | base64 -d)"

kubectl exec -it -n aict mysql-0 -- \
  env MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mysql -uroot
```

### 检查账号

```sql
SELECT user, host, plugin
FROM mysql.user
ORDER BY user, host;
```

### 检查交付基线

```sql
SHOW VARIABLES WHERE Variable_name IN (
  'version',
  'character_set_server',
  'collation_server',
  'time_zone',
  'local_infile',
  'max_connections',
  'innodb_buffer_pool_size',
  'innodb_flush_log_at_trx_commit',
  'sync_binlog',
  'gtid_mode'
);
```

---

## 18. 卸载与数据保留

默认：

```bash
./mysql-installer-v1.6.0-amd64.run uninstall -n aict -y
```

**不会删除 PVC**。

只有明确要求删除数据：

```bash
./mysql-installer-v1.6.0-amd64.run uninstall \
  -n aict \
  --delete-pvc \
  -y
```

这属于破坏性操作。

---

## 19. 旧 MySQL 8.0 数据目录

新环境直接使用 MySQL 8.4.11。

已有 MySQL 8.0 PVC 不应把“更换 image tag”视为完整升级流程。

正式升级至少应包括：

```text
备份 / 可恢复验证
        ->
8.0 -> 8.4 compatibility / upgrade check
        ->
废弃参数检查
        ->
测试环境升级
        ->
业务 JDBC / Nacos 连接验证
        ->
正式变更
```

当前 installer 的重点是 **MySQL 8.4.11 新装和同版本 reconcile**。

---

## 20. TODO：账号与兼容性收口

当前为了优先保证私有化交付兼容性，仍允许远程 root，并暂时开启 `mysql_native_password`。

长期目标是把账号按职责拆开：

| 场景 | 目标账号 | 状态 |
| --- | --- | --- |
| 本地数据库管理 | `root@localhost` | 已有 |
| 临时远程管理 | `root@<controlled-host>` | 当前兼容方案，后续逐步收紧 |
| Nacos | `nacos_user` | **TODO** |
| 业务应用 | `app_user` / 每应用独立账号 | **TODO** |
| Prometheus 监控 | `mysqld_exporter` | **已完成** |
| 数据保护 / 备份 | `mysql_backup` | **TODO，备份阶段再做** |

认证插件 TODO：

```text
当前：mysql_native_password=ON
        ↓
验证 Nacos JDBC / 所有业务客户端支持 caching_sha2_password
        ↓
将 Nacos / 业务迁移到专用账号
        ↓
远程 root 改为 caching_sha2_password 或直接关闭 remote root
        ↓
默认切换 mysql_native_password=OFF
```

`mysql_native_password` 在 MySQL 8.4 已属于废弃兼容能力，因此**关闭它是明确的后续安全 TODO，不应长期依赖**。

---

## 21. 生产交付检查清单

交付前至少确认：

```text
[ ] MySQL 版本 = 8.4.11
[ ] replicas = 1
[ ] root 密码不是弱口令
[ ] NodePort 是否确实需要；默认应关闭
[ ] remote root 的 host 范围是否符合项目要求
[ ] mysql_native_password 是否确实仍需兼容
[ ] StorageClass 是否为可靠存储
[ ] PVC 容量是否满足增长预估
[ ] Resource Profile 与 Buffer Pool 是否匹配
[ ] startupProbe / readiness / liveness 正常
[ ] Pod 优雅退出时间 = 120s
[ ] error log / slow log 可通过 kubectl logs 查看
[ ] 集中日志平台能采集 MySQL stdout/stderr
[ ] mysqld-exporter Target = UP
[ ] MySQL / Overview Dashboard 正常
[ ] MySQL / Performance Dashboard 正常
[ ] PrometheusRule 已加载且无 rule error
[ ] Nacos / 真实业务 JDBC 已完成连接验证
```

做到以上这些后，这个版本即可作为 **Archinfra MySQL 8.4.11 单实例标准交付基线**。

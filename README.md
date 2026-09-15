# apps_mysql

面向 Kubernetes 的 MySQL 8.4 LTS 离线交付、监控、日志与压测工具包。

## 当前标准交付基线

- `apps_mysql`: `v1.6.0`
- MySQL: `8.4.11 LTS`
- `mysqld-exporter`: `v0.19.0`
- 架构：`amd64` / `arm64`
- 部署模式：**单实例、单副本**
- 默认资源规格：**standard，MySQL 主容器 2C / 8Gi，PVC 100Gi**
- NodePort：**默认关闭**
- 远程 root：**默认开启，默认 `root@'%'`**
- `mysql_native_password`：**暂时默认开启用于旧客户端兼容，后续计划关闭**
- 监控 / 告警 / Dashboard：默认开启
- 备份：当前阶段暂不作为 MySQL 标准交付闭环，推荐安装时显式 `--disable-data-protection`

> 当前版本明确只提供单实例 MySQL。`--mysql-replicas` 必须为 `1`；多副本 StatefulSet 不等于 MySQL HA。

---

## 1. 推荐的标准安装方式

### 1.1 新环境正式交付推荐命令

当前新环境交付建议显式使用以下参数，而不是完全依赖隐式默认值：

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace aict \
  --resource-profile standard \
  --storage-class ceph-rbd \
  --storage-size 100Gi \
  --enable-remote-root \
  --root-remote-host '%' \
  --enable-native-password \
  --disable-nodeport \
  --enable-monitoring \
  --enable-service-monitor \
  --disable-fluentbit \
  --disable-data-protection \
  --mysql-slow-query-time 2 \
  --wait-timeout 10m \
  -y
```

这条命令是当前 **Archinfra MySQL 8.4.11 单实例标准交付推荐模板**。

推荐结果：

```text
Namespace             aict
MySQL                 8.4.11 LTS
Replicas              1
Resource Profile      standard
MySQL Request         1C / 4Gi
MySQL Limit           2C / 8Gi
InnoDB Buffer Pool    5G
PVC                    100Gi
StorageClass           ceph-rbd
Remote Root            ON, root@'%'
mysql_native_password  ON（过渡兼容）
NodePort               OFF
Monitoring             ON
ServiceMonitor         ON
Fluent Bit Sidecar     OFF
Slow Query Threshold   2s
Data Protection        OFF（当前阶段）
Timezone               UTC
Charset                utf8mb4
Collation              utf8mb4_0900_ai_ci
```

### 1.2 为什么推荐显式写这些参数

交付命令显式写出关键开关，主要为了让安装记录、实施文档和验收记录能够直接反映真实配置：

| 参数 | 推荐值 | 说明 |
| --- | --- | --- |
| `--namespace` | `aict` | 当前 Archinfra 业务默认命名空间；项目有独立规范时可改 |
| `--resource-profile` | `standard` | 标准交付规格，2C / 8Gi limit |
| `--storage-class` | `ceph-rbd` | 示例块存储；现场应替换为实际认可的可靠 StorageClass |
| `--storage-size` | `100Gi` | standard 新装标准容量，显式记录交付容量 |
| `--enable-remote-root` | 开启 | 当前阶段兼容 Nacos / 历史 JDBC 等使用场景 |
| `--root-remote-host` | `%` | 当前兼容默认；项目网络边界明确后建议进一步收紧 |
| `--enable-native-password` | 开启 | MySQL 8.4 过渡兼容策略，后续 TODO 关闭 |
| `--disable-nodeport` | 关闭外部暴露 | 默认只允许能访问 K8s Service 网络的客户端连接 |
| `--enable-monitoring` | 开启 | 部署 `mysqld-exporter v0.19.0` |
| `--enable-service-monitor` | 开启 | 接入标准 Prometheus Stack |
| `--disable-fluentbit` | 关闭 sidecar | 默认直接采集容器 stdout/stderr，减少重复日志组件 |
| `--disable-data-protection` | 当前关闭 | 备份体系后续独立完善，不影响本轮 MySQL 交付 |
| `--mysql-slow-query-time` | `2` | 默认慢查询阈值 2 秒 |
| `--wait-timeout` | `10m` | 给首次初始化和 InnoDB recovery 足够等待时间 |

> `ceph-rbd` 是推荐示例，不是硬编码要求。现场如果使用 SAN、Local PV、云块存储等，应替换成实际 StorageClass。生产数据库不建议因为安装器默认兼容值是 `nfs` 就直接采用 NFS。

### 1.3 root 密码推荐让安装器自动生成

推荐命令故意不传 `--root-password`。首次安装时 installer 会生成随机密码并写入 `Secret/mysql-auth`；reconcile 时复用已有 Secret。

查看密码：

```bash
kubectl get secret -n aict mysql-auth \
  -o jsonpath='{.data.mysql-root-password}' | base64 -d; echo
```

如果项目要求由密码系统预先生成，也可以显式传：

```bash
--root-password '<STRONG_PASSWORD>'
```

不要在正式交付脚本中写固定弱口令。

### 1.4 自定义私有 Registry

客户环境使用自己的 Harbor / Registry 时，在推荐命令中追加：

```bash
--registry harbor.example.com/kube4
```

MySQL 会使用对应仓库中的 `mysql:8.4.11`，Exporter 使用 `mysqld-exporter:v0.19.0`。

---

## 2. 产物与能力边界

仓库构建 3 类离线 `.run`：

```text
mysql-installer-v1.6.0-<arch>.run
mysql-monitoring-v1.6.0-<arch>.run
mysql-benchmark-v1.6.0-<arch>.run
```

| 产物 | 用途 |
| --- | --- |
| `mysql-installer` | 新装 / reconcile MySQL、资源、存储、本地日志、内嵌监控、Dashboard、Alert |
| `mysql-monitoring` | 给已有 MySQL 补独立 exporter / ServiceMonitor / Dashboard / Alert |
| `mysql-benchmark` | 对 MySQL 执行标准化 sysbench 压测并输出报告 |

备份能力目前不是本轮交付重点。仓库仍保留 dataprotection 接入协议，但当前标准交付建议使用 `--disable-data-protection`，不影响 MySQL 本体、监控和日志。

---

## 3. 三档正式资源规格

`--resource-profile` 只接受以下三个值：

| Profile | 中文名称 | MySQL Request | MySQL Limit | InnoDB Buffer Pool | 新装 PVC 默认值 | 典型用途 |
| --- | --- | --- | --- | --- | --- | --- |
| `lite` | 精简模式 | `500m / 1Gi` | **`1C / 2Gi`** | `1G` | `20Gi` | Demo、轻量项目、小数据量 |
| `standard` | 标准模式 | `1C / 4Gi` | **`2C / 8Gi`** | `5G` | `100Gi` | **默认标准交付** |
| `large` | 大规格模式 | `2C / 8Gi` | **`4C / 16Gi`** | `10G` | `500Gi` | 中高负载、较大工作集 |

不再提供其他 profile 名称或别名。安装命令、交付文档、验收记录和运维口径统一使用 `lite / standard / large`。

`1C2G / 2C8G / 4C16G` 指 **MySQL 主容器的 limit**。requests 默认约为 limit 的 50%；`mysqld-exporter`、Fluent Bit 和 initContainer 有独立的小额资源开销。

### Buffer Pool

MySQL 还需要为连接、排序、Join、临时表、Performance Schema、binlog / redo 和运行时本身预留内存，因此 Buffer Pool 不等于容器全部内存：

```text
lite      2Gi  limit -> 1G  Buffer Pool
standard  8Gi  limit -> 5G  Buffer Pool
large     16Gi limit -> 10G Buffer Pool
```

需要按压测结果调整时：

```bash
--innodb-buffer-pool-size 6G
```

---

## 4. 存储规格与 reconcile 规则

### 4.1 新安装

未显式传 `--storage-size` 时：

```text
lite      -> 20Gi
standard  -> 100Gi
large     -> 500Gi
```

StorageClass 默认保留 `nfs` 是为了兼容既有交付；生产推荐显式使用可靠块存储，例如：

```text
Ceph RBD
SAN
Local PV
云盘 / 云块存储
```

### 4.2 显式覆盖容量

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --resource-profile standard \
  --storage-class ceph-rbd \
  --storage-size 300Gi \
  -y
```

`--storage-size` 优先于 profile 默认值。

### 4.3 已有 PVC 重跑 installer

规则：

```text
已有 PVC + 未传 --storage-size
    -> 保留当前 PVC 容量
    -> resource-profile 只调整 CPU / 内存 / Buffer Pool

已有 PVC + 显式 --storage-size
    -> installer 对现有 PVC 发起 resize
```

注意：

- Kubernetes PVC 不支持缩容。
- PVC 在线扩容要求 `StorageClass.allowVolumeExpansion=true`。
- StatefulSet `volumeClaimTemplates` 是 immutable 字段，installer 会保留旧模板值并直接管理现有 PVC 的扩容。
- 已绑定 PVC 不能通过普通 reconcile 原地切换 StorageClass；必须走新 PVC + 数据迁移。

---

## 5. 三种安装规格示例

### 5.1 精简模式 `lite`

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace aict \
  --resource-profile lite \
  --storage-class nfs \
  --disable-nodeport \
  --enable-monitoring \
  --enable-service-monitor \
  --disable-data-protection \
  -y
```

```text
MySQL limit    1C / 2Gi
MySQL request  500m / 1Gi
Buffer Pool    1G
PVC            20Gi
```

适合 Demo、功能验证和轻量项目，不建议用于持续高并发生产负载。

### 5.2 标准模式 `standard`

优先使用第 1 节的标准推荐命令。

```text
MySQL limit    2C / 8Gi
MySQL request  1C / 4Gi
Buffer Pool    5G
PVC            100Gi
```

### 5.3 大规格模式 `large`

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace aict \
  --resource-profile large \
  --storage-class ceph-rbd \
  --storage-size 500Gi \
  --enable-remote-root \
  --disable-nodeport \
  --enable-monitoring \
  --enable-service-monitor \
  --disable-data-protection \
  -y
```

```text
MySQL limit    4C / 16Gi
MySQL request  2C / 8Gi
Buffer Pool    10G
PVC            500Gi
```

大规格仍然是单实例，不等于 HA；更高负载需要结合实际 SQL、IOPS、工作集和压测结果继续评估。

---

## 6. 当前默认部署契约

| 项目 | 默认值 |
| --- | --- |
| namespace | `aict` |
| StatefulSet | `mysql` |
| replicas | `1` |
| MySQL | `8.4.11 LTS` |
| resource profile | `standard` |
| MySQL request | `1C / 4Gi` |
| MySQL limit | `2C / 8Gi` |
| Buffer Pool | `5G` |
| StorageClass | `nfs` |
| 新装 PVC | `100Gi` |
| root Secret | `mysql-auth` |
| remote root | `true` / `root@'%'` |
| `mysql_native_password` | `ON`，过渡兼容 |
| NodePort | `false` |
| MySQL port | `3306` |
| monitoring | `true` |
| ServiceMonitor | `true` |
| Fluent Bit | `false` |
| log emptyDir limit | `2Gi` |
| slow query threshold | `2s` |
| timezone | `UTC` |
| charset | `utf8mb4` |
| collation | `utf8mb4_0900_ai_ci` |
| wait timeout | `10m` |

### 安装端依赖

运行已经构建好的 `.run`：

- 必需：`kubectl`
- 默认离线镜像导入/推送：`docker`
- 目标 / 离线环境**不要求安装 `jq`**

`jq` 只用于仓库侧 `build.sh` 构建离线安装包。

---

## 7. root 账号与远程访问

MySQL 初始化出的 `root@localhost` 保留本地管理能力。

installer 在 MySQL Ready 后幂等对齐远程 root：

```sql
CREATE USER IF NOT EXISTS 'root'@'%'
  IDENTIFIED WITH mysql_native_password BY '<Secret 中的密码>';

ALTER USER 'root'@'%'
  IDENTIFIED WITH mysql_native_password BY '<Secret 中的密码>';

GRANT ALL PRIVILEGES ON *.*
  TO 'root'@'%'
  WITH GRANT OPTION;
```

默认：

```text
remote root = true
NodePort    = false
```

因此默认没有把 3306 通过 NodePort 暴露到客户外部网络；访问范围仍应由 Kubernetes 网络、NetworkPolicy、防火墙、ACL、VPN 或堡垒机控制。

如果现场能够明确来源范围，优先收紧：

```bash
--root-remote-host '10.%'
```

关闭远程 root：

```bash
--disable-remote-root
```

---

## 8. `mysql_native_password` 兼容策略

MySQL 8.4 默认关闭并弃用 `mysql_native_password`。当前为了兼容部分历史 JDBC / MySQL client，暂时：

```ini
mysql_native_password=ON
```

installer 管理的远程 `root@<host>` 使用 `mysql_native_password`；本地 `root@localhost` 和 `mysqld_exporter` 不强制退回旧插件。

后续目标：

```text
Nacos / 业务 JDBC 验证 caching_sha2_password
        ->
迁移到专用账号
        ->
收紧 / 关闭 remote root
        ->
mysql_native_password=OFF
```

---

## 9. Runtime / Probe / 优雅停机

运行配置真源：

```text
manifests/mysql-runtime-config.yaml
```

核心基线：

```ini
bind-address=0.0.0.0
mysqlx=0
skip_name_resolve=ON
local_infile=OFF
character_set_server=utf8mb4
collation_server=utf8mb4_0900_ai_ci
default_time_zone='+00:00'
log_timestamps=UTC
max_connections=300
innodb_flush_log_at_trx_commit=1
sync_binlog=1
innodb_buffer_pool_size=<profile>
innodb_redo_log_capacity=1G
performance_schema=ON
slow_query_log=ON
binlog_format=ROW
gtid_mode=ON
```

生命周期：

```text
startupProbe: 10s * 60 failures ~= 10 分钟恢复窗口
livenessProbe: 10s
readinessProbe: 5s
terminationGracePeriodSeconds: 120
```

用于覆盖首次初始化、较大数据目录启动、InnoDB crash recovery 和滚动更新。

---

## 10. 日志

默认：

```text
/var/log/mysql/error.log -> stderr
/var/log/mysql/slow.log  -> stdout
```

查看：

```bash
kubectl logs -n aict mysql-0 -c mysql --tail=200
kubectl logs -n aict mysql-0 -c mysql -f
```

Pod 本地日志 `emptyDir` 默认上限：

```text
2Gi
```

覆盖：

```bash
--mysql-log-size-limit 4Gi
```

长期保存应进入集中日志平台，不应依赖 Pod 文件系统。因此标准安装推荐 `--disable-fluentbit`，由平台 DaemonSet / Agent 统一消费容器 stdout/stderr；只有明确需要 Pod 内文件型慢日志采集时，再使用 `--enable-fluentbit`。

---

## 11. 监控

默认内嵌：

```text
mysqld-exporter v0.19.0
```

监控账号：

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

默认 collector 包括 global status / variables、InnoDB metrics、processlist 和 binlog size。

Dashboard：

```text
MySQL / Overview
MySQL / Performance
```

主要覆盖：

- MySQL Up / Uptime
- QPS / SQL throughput
- Connections / Threads
- Slow Query Ratio
- Buffer Pool Hit Ratio
- Deadlock / Lock Wait
- Temporary Tables on Disk
- Pod CPU / Memory
- PVC Usage
- Binlog size

默认规则包括可用性、连接饱和、慢 SQL、死锁、Buffer Pool、临时表和 PVC 80% / 90% 容量告警。

---

## 12. Help 与常用参数

```bash
./mysql-installer-v1.6.0-amd64.run help
./mysql-installer-v1.6.0-amd64.run help install
./mysql-installer-v1.6.0-amd64.run help params
./mysql-installer-v1.6.0-amd64.run help logging
./mysql-installer-v1.6.0-amd64.run help examples
```

核心参数：

```text
--namespace <ns>
--root-password <password>
--auth-secret <name>

--resource-profile lite|standard|large
--storage-class <name>
--storage-size <size>
--innodb-buffer-pool-size <size>
--mysql-log-size-limit <size>

--enable-remote-root
--disable-remote-root
--root-remote-host <host>

--enable-native-password
--disable-native-password

--enable-nodeport
--disable-nodeport
--node-port <port>

--enable-monitoring
--disable-monitoring
--enable-service-monitor
--disable-service-monitor
--enable-fluentbit
--disable-fluentbit

--enable-data-protection
--disable-data-protection

--mysql-slow-query-time <seconds>
--registry <repo-prefix>
--wait-timeout <duration>
```

---

## 13. 只补监控

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

## 14. Benchmark

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

建议在目标 StorageClass 上对 `standard` / `large` 做真实压测，再确认容量、IOPS 与 Buffer Pool。

---

## 15. 卸载与数据保留

默认卸载：

```bash
./mysql-installer-v1.6.0-amd64.run uninstall -n aict -y
```

默认保留：

```text
PVC
Secret/mysql-auth
```

只有明确：

```bash
--delete-pvc
```

才删除数据盘和 root Secret。

---

## 16. 旧 MySQL 8.0 数据目录

新环境直接使用 MySQL 8.4.11。

已有 MySQL 8.0 PVC 不应把“更换 image tag”当成完整升级流程。正式升级至少需要：

```text
备份 / 可恢复验证
  -> 8.0 -> 8.4 compatibility / upgrade check
  -> 废弃参数检查
  -> 测试环境升级
  -> Nacos / 业务 JDBC 验证
  -> 正式变更
```

当前 installer 重点是 **MySQL 8.4.11 新装和同版本 reconcile**。

---

## 17. TODO：账号与兼容性收口

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
mysql_native_password=ON
  -> 验证 Nacos / 业务支持 caching_sha2_password
  -> 专用账号迁移
  -> 收紧或关闭 remote root
  -> mysql_native_password=OFF
```

---

## 18. 生产交付检查清单

```text
[ ] MySQL = 8.4.11 LTS
[ ] replicas = 1
[ ] resource-profile = lite / standard / large 中明确的一档
[ ] 标准项目优先采用 standard = 2C / 8Gi / 100Gi
[ ] MySQL CPU / Memory limit 与项目资源规划一致
[ ] InnoDB Buffer Pool 与 memory limit 匹配
[ ] StorageClass 为项目认可的可靠存储
[ ] PVC 初始容量满足增长预估
[ ] 已有 PVC 扩容时 StorageClass.allowVolumeExpansion=true
[ ] 没有尝试 PVC 缩容或原地切换 StorageClass
[ ] root 密码为随机强密码或项目密码系统生成
[ ] NodePort 默认关闭；如开启已经过安全确认
[ ] remote root host 范围符合项目要求
[ ] mysql_native_password 当前确有兼容需求
[ ] startupProbe / readiness / liveness 正常
[ ] terminationGracePeriodSeconds = 120
[ ] error log / slow log 可通过 kubectl logs 查看
[ ] mysqld-exporter Target = UP
[ ] MySQL / Overview Dashboard 正常
[ ] MySQL / Performance Dashboard 正常
[ ] PrometheusRule 已加载且无 rule error
[ ] Nacos / 真实业务 JDBC 已完成连接验证
```

完成以上检查后，可将该版本作为 **Archinfra MySQL 8.4.11 单实例标准交付基线**。

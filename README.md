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

> 当前版本明确只提供单实例 MySQL。`--mysql-replicas` 必须为 `1`；多副本 StatefulSet 不等于 MySQL HA。

---

## 1. 产物与能力边界

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

备份能力目前不是本轮交付重点。仓库仍保留 dataprotection 接入协议，客户项目可通过 `--disable-data-protection` 暂时关闭，不影响 MySQL 本体、监控和日志。

---

## 2. 三档正式资源规格

`--resource-profile` 是 MySQL 私有化交付的官方规格参数，并且**只接受以下三个值**：

| Profile | 中文名称 | MySQL Request | MySQL Limit | InnoDB Buffer Pool | 新装 PVC 默认值 | 典型用途 |
| --- | --- | --- | --- | --- | --- | --- |
| `lite` | 精简模式 | `500m / 1Gi` | **`1C / 2Gi`** | `1G` | `20Gi` | Demo、轻量项目、小数据量 |
| `standard` | 标准模式 | `1C / 4Gi` | **`2C / 8Gi`** | `5G` | `100Gi` | **默认标准交付** |
| `large` | 大规格模式 | `2C / 8Gi` | **`4C / 16Gi`** | `10G` | `500Gi` | 中高负载、较大工作集 |

不再提供其他 profile 名称或别名。这样安装命令、交付文档、验收记录和运维口径始终只有 `lite / standard / large` 三种。

其中 `1C2G / 2C8G / 4C16G` 指 **MySQL 主容器的 limit**。默认 requests 约为 limit 的 50%，用于 Kubernetes 调度；`mysqld-exporter`、Fluent Bit 和 initContainer 有独立的小额资源开销。

### 为什么 Buffer Pool 不直接等于容器内存

MySQL 还需要为下列内存留空间：

- connection / thread
- sort / join / read buffer
- temporary table
- performance_schema
- binlog / redo
- MySQL 自身运行时开销

因此当前默认约为：

```text
lite      2Gi  limit -> 1G  Buffer Pool
standard  8Gi  limit -> 5G  Buffer Pool
large     16Gi limit -> 10G Buffer Pool
```

可以显式覆盖：

```bash
--innodb-buffer-pool-size 6G
```

---

## 3. 存储规格与 reconcile 规则

### 3.1 新安装

新安装且没有显式传 `--storage-size` 时，由 profile 决定 PVC：

```text
lite      -> 20Gi
standard  -> 100Gi
large     -> 500Gi
```

StorageClass 默认仍为 `nfs`，主要为了兼容既有交付；**生产环境推荐显式指定可靠块存储**：

```text
Ceph RBD
SAN
Local PV
云盘 / 云块存储
```

标准生产示例：

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-prod \
  --resource-profile standard \
  --storage-class ceph-rbd \
  -y
```

最终默认得到：

```text
MySQL request : 1C / 4Gi
MySQL limit   : 2C / 8Gi
Buffer Pool   : 5G
PVC           : 100Gi
```

### 3.2 显式覆盖容量

项目容量不符合标准档位时：

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --resource-profile standard \
  --storage-class ceph-rbd \
  --storage-size 300Gi \
  -y
```

`--storage-size` 优先于 profile 默认值。

### 3.3 已有 PVC 重跑 installer

已有数据盘不能因为 installer 默认值改变而自动放大或缩小。

因此规则是：

```text
已有 PVC + 未传 --storage-size
    -> 保留当前 PVC 容量
    -> 切换 resource-profile 只调整 CPU / 内存 / Buffer Pool

已有 PVC + 显式 --storage-size
    -> installer 对现有 PVC 发起 resize
```

注意：

- Kubernetes PVC **不支持缩容**。
- PVC 在线扩容要求 `StorageClass.allowVolumeExpansion=true`。
- StatefulSet `volumeClaimTemplates` 属于 immutable 字段，installer 会保留旧模板值并直接 patch 现有 PVC。
- 已绑定 PVC **不能通过 reconcile 原地切换 StorageClass**；更换存储类型必须走新 PVC + 数据迁移流程。

这套规则保证历史环境不会因为新版 profile 默认容量变化，在普通 reconcile 时被意外改盘。

---

## 4. 最快开始

### 4.1 默认标准模式

```bash
./mysql-installer-v1.6.0-amd64.run install -y
```

默认：

```text
profile      standard
MySQL limit  2C / 8Gi
MySQL req    1C / 4Gi
Buffer Pool  5G
PVC          100Gi
StorageClass nfs
NodePort     OFF
remote root  ON, root@'%'
monitoring   ON
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

---

## 5. 三种推荐安装方式

### 5.1 精简模式 `lite`

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-lite \
  --resource-profile lite \
  --storage-class nfs \
  --disable-data-protection \
  -y
```

规格：

```text
1C / 2Gi limit
500m / 1Gi request
1G Buffer Pool
20Gi PVC
```

适合 Demo、功能验证和轻量项目，不建议用于持续高并发生产负载。

### 5.2 标准模式 `standard`

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-prod \
  --resource-profile standard \
  --storage-class ceph-rbd \
  --root-password 'Strong-Password-Here' \
  --disable-data-protection \
  -y
```

规格：

```text
2C / 8Gi limit
1C / 4Gi request
5G Buffer Pool
100Gi PVC
```

这是 Archinfra 当前默认单实例 MySQL 交付档位。

### 5.3 大规格模式 `large`

```bash
./mysql-installer-v1.6.0-amd64.run install \
  --namespace mysql-prod \
  --resource-profile large \
  --storage-class ceph-rbd \
  --mysql-slow-query-time 1 \
  --root-password 'Strong-Password-Here' \
  --disable-data-protection \
  -y
```

规格：

```text
4C / 16Gi limit
2C / 8Gi request
10G Buffer Pool
500Gi PVC
```

大规格仍然是单实例，不等于 HA；更高负载应结合真实压测、慢 SQL、IOPS 和工作集继续评估。

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
| NodePort | `false` |
| MySQL port | `3306` |
| monitoring | `true` |
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
- **目标/离线环境不要求安装 `jq`**

`jq` 只用于仓库侧 `build.sh` 构建离线安装包。

---

## 7. root 账号与远程访问

MySQL 容器初始化出的 `root@localhost` 保留本地管理能力。

installer 在 MySQL Ready 后幂等对齐：

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

因此默认并没有把 3306 暴露到客户外部网络；真正的访问范围仍由 Kubernetes 网络、NetworkPolicy、防火墙、ACL、VPN、堡垒机等控制。

限制来源：

```bash
--root-remote-host '10.%'
```

关闭远程 root：

```bash
--disable-remote-root
```

---

## 8. `mysql_native_password` 兼容策略

MySQL 8.4 已默认关闭并弃用 `mysql_native_password`。

当前为了兼容部分历史 JDBC / MySQL client，暂时：

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
收紧/关闭 remote root
        ->
mysql_native_password=OFF
```

---

## 9. Runtime / Probe / 优雅停机

运行配置：

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

长期保存应进入集中日志平台，不应依赖 Pod 文件系统。

---

## 11. 监控

默认内嵌：

```text
mysqld-exporter v0.19.0
```

账号：

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

默认规则包括可用性、连接饱和、慢 SQL、死锁、Buffer Pool、临时表和 PVC 80%/90% 容量告警。

---

## 12. 常用参数

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

建议对 `standard` / `large` 生产规格在目标存储上实际压测后再确认最终容量、IOPS 与 Buffer Pool。

---

## 15. 卸载与数据保留

默认：

```bash
./mysql-installer-v1.6.0-amd64.run uninstall -n aict -y
```

保留：

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

已有 MySQL 8.0 PVC 不应把“更换 image tag”视为升级流程。正式升级至少需要：

```text
备份 / 可恢复验证
  -> 8.0 -> 8.4 compatibility / upgrade check
  -> 废弃参数检查
  -> 测试环境升级
  -> Nacos / 业务 JDBC 验证
  -> 正式变更
```

当前 installer 的重点是 **MySQL 8.4.11 新装和同版本 reconcile**。

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
  -> 验证 Nacos/业务支持 caching_sha2_password
  -> 专用账号迁移
  -> 收紧或关闭 remote root
  -> mysql_native_password=OFF
```

---

## 18. 生产交付检查清单

```text
[ ] MySQL = 8.4.11
[ ] replicas = 1
[ ] resource-profile 已明确：lite / standard / large
[ ] MySQL CPU / Memory limit 与项目资源规划一致
[ ] InnoDB Buffer Pool 与 memory limit 匹配
[ ] StorageClass 为项目认可的可靠存储
[ ] PVC 初始容量满足增长预估
[ ] 已有 PVC 扩容时 StorageClass.allowVolumeExpansion=true
[ ] 没有尝试 PVC 缩容或原地切换 StorageClass
[ ] root 密码不是弱口令
[ ] NodePort 是否确实需要；默认应关闭
[ ] remote root host 范围符合项目要求
[ ] mysql_native_password 是否仍确有兼容需求
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

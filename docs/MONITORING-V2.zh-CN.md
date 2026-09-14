# MySQL Monitoring V2

`apps_mysql v1.6.0` 面向单实例、单副本 MySQL 交付，默认组合：

- MySQL `8.0.46`
- mysqld-exporter `0.19.0`
- Prometheus Operator `ServiceMonitor`
- `PrometheusRule`
- Grafana 自动发现 Dashboard

## Exporter

内嵌与外置 exporter 都统一使用专用低权限账号，不再使用 root 抓取监控。默认权限：

- `PROCESS`
- `REPLICATION CLIENT`
- `SELECT`
- `MAX_USER_CONNECTIONS 3`

默认额外开启以下低风险、低基数 collector：

- `collect.info_schema.innodb_metrics`
- `collect.info_schema.processlist`
- `collect.binlog_size`

不默认开启 table/schema/statement digest 等高基数 collector。需要 SQL digest 或表级指标时，应按项目单独评估 Prometheus cardinality 后开启。

## Dashboard

集成安装默认创建两张 Dashboard，Grafana folder 为 `Middleware/MySQL`。

### MySQL / Overview

用于值班与日常巡检，包含：

- MySQL Up / Uptime
- Connection Usage
- Threads Running
- QPS
- Slow Query Ratio
- SELECT / INSERT / UPDATE / DELETE 吞吐
- Connections / Threads 趋势
- Slow Queries / Aborted Connections
- InnoDB Buffer Pool Hit Ratio
- Deadlocks / Row Lock Waits
- Temporary Tables on Disk
- MySQL Container CPU / Memory
- PVC Usage

### MySQL / Performance

用于性能排障，包含：

- Buffer Pool data/dirty pages
- Logical reads / physical reads
- InnoDB row operations
- InnoDB log waits / row lock time
- COMMIT / ROLLBACK
- Binlog Size
- Temporary Tables
- Open Files / Open Tables
- MySQL network throughput

外置 monitoring addon 提供不依赖 Kubernetes Pod/PVC 指标的 External Overview Dashboard。

## 默认告警

| 告警 | Severity | 默认条件 |
| --- | --- | --- |
| `MySQLExporterDown` | critical | exporter target 2 分钟不可抓取 |
| `MySQLDown` | critical | `mysql_up=0` 持续 2 分钟 |
| `MySQLConnectionsHigh` | warning | connections > 80% 持续 10 分钟 |
| `MySQLConnectionsCritical` | critical | connections > 90% 持续 5 分钟 |
| `MySQLAbortedConnectionsHigh` | warning | aborted / total connections > 5% 持续 10 分钟 |
| `MySQLThreadsRunningHigh` | warning | Threads Running > 16 持续 10 分钟 |
| `MySQLSlowQueryRatioHigh` | warning | slow query ratio > 1% 持续 10 分钟 |
| `MySQLSlowQueryRatioCritical` | critical | slow query ratio > 5% 持续 5 分钟 |
| `MySQLDeadlocksDetected` | warning | 10 分钟内出现 deadlock |
| `MySQLRowLockWaitHigh` | warning | current row lock waits > 5 持续 5 分钟 |
| `MySQLBufferPoolHitRatioLow` | warning | 有效读负载下 hit ratio < 99% 持续 15 分钟 |
| `MySQLBufferPoolHitRatioCritical` | critical | 有效读负载下 hit ratio < 95% 持续 10 分钟 |
| `MySQLTmpDiskTablesHigh` | warning | 临时表落盘比例 > 25% 持续 15 分钟 |
| `MySQLPVCUsageHigh` | warning | PVC > 80% 持续 15 分钟 |
| `MySQLPVCUsageCritical` | critical | PVC > 90% 持续 5 分钟 |

这些阈值是交付基线，不是所有业务的永久固定值。上线后应结合连接池大小、业务 QPS、SQL 模型和压测基线调整。

## 单副本边界

v1.6.0 的监控基线针对单实例 MySQL。`--mysql-replicas` 参数仍为兼容性保留，但本版本不把 StatefulSet 多副本定义为 MySQL HA，不提供复制拓扑、自动主从切换或 InnoDB Cluster 能力。

## 版本策略

v1.6.0 先从 MySQL `8.0.45` 升级到 `8.0.46`，保持同一 8.0 patch 系列以降低升级风险。后续将 MySQL `8.4.x LTS` 作为独立兼容验证目标，不与 Monitoring V2 在同一次发布中混合切换。

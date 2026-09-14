# MySQL 8.4 LTS Delivery Baseline

## Version BOM

- apps_mysql: 1.6.0
- MySQL: 8.4.11 LTS
- mysqld-exporter: 0.19.0
- Fluent Bit: 3.0.7
- sysbench: 1.0.20
- architectures: amd64, arm64

## Supported topology

This release intentionally supports one MySQL instance only. `--mysql-replicas` must be `1`.

Multiple StatefulSet replicas are not treated as MySQL HA. Replication, failover and InnoDB Cluster are outside this release scope.

## Secure defaults

- NodePort is disabled by default.
- Root password is generated on first install when `--root-password` is omitted.
- Existing `mysql-auth` root password is reused on reconcile.
- mysqld-exporter uses a dedicated account with `PROCESS`, `REPLICATION CLIENT` and `SELECT`, limited to three connections.
- Exporter password is generated per installer invocation unless explicitly supplied.
- Legacy fixed-password local maintenance/health users are removed after MySQL becomes ready.
- Health probes use local `mysqladmin ping` and do not require a stored health password.
- `local_infile=OFF`, `mysqlx=0`, `skip_name_resolve=ON`.

## Runtime baseline

The installer reconciles `mysql-runtime-config.yaml` after the main manifest and restarts the single StatefulSet pod because the MySQL configuration is mounted using `subPath`.

Important settings:

- `max_connections=300`
- `thread_cache_size=64`
- `max_allowed_packet=64M`
- `innodb_buffer_pool_size=512M`
- `innodb_log_buffer_size=64M`
- `innodb_redo_log_capacity=1G`
- `innodb_flush_log_at_trx_commit=1`
- `sync_binlog=1`
- `tmp_table_size=32M`
- `max_heap_table_size=32M`
- `performance_schema=ON`
- slow query log enabled, default threshold 2s
- ROW binlog, GTID enabled, binlog retention 7 days

The default StorageClass remains `nfs` for backward compatibility, but production deployments should explicitly choose reliable block storage such as Ceph RBD, SAN or cloud block volumes when available.

## Monitoring V2

Default exporter collectors include:

- global status and global variables
- InnoDB metrics
- processlist
- binlog size

Two Grafana dashboards are delivered by the MySQL package:

- `MySQL / Overview`
- `MySQL / Performance`

The overview combines MySQL metrics with Kubernetes container/PVC metrics. The performance dashboard focuses on query throughput, connections, InnoDB, contention and temporary table behavior.

Default alert groups cover:

- exporter availability and MySQL availability
- connection utilization, aborted connections and running threads
- slow query ratio
- deadlocks and row lock waits
- InnoDB buffer-pool hit ratio
- temporary-table disk spill ratio
- PVC utilization at warning/critical thresholds

Current baseline thresholds are intended as safe initial values and should be tuned with real workload data after deployment.

## Upgrade notes

For an existing persistent MySQL 8.0 data directory, do not treat an image-tag change as the entire upgrade procedure. Before production upgrade, run a MySQL 8.0-to-8.4 compatibility/upgrade check and validate backup/restore on a copy of production data.

The installer preserves the PVC by default and reconciles the runtime configuration after applying the StatefulSet.

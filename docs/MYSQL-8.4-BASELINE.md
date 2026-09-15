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

## Delivery resource profiles

The installer exposes exactly three delivery profiles through `--resource-profile`:

| profile | purpose | MySQL request | MySQL limit | default `innodb_buffer_pool_size` | new-install PVC |
| --- | --- | ---: | ---: | ---: | ---: |
| `lite` | demo / small deployment | `500m / 1Gi` | `1C / 2Gi` | `1G` | `20Gi` |
| `standard` | default private-delivery baseline | `1C / 4Gi` | `2C / 8Gi` | `5G` | `100Gi` |
| `large` | larger working set / higher load | `2C / 8Gi` | `4C / 16Gi` | `10G` | `500Gi` |

The canonical default is `standard`.

No alternate or legacy profile names are accepted. Keeping one vocabulary avoids different meanings in installer commands, delivery documents and acceptance records.

The CPU/memory number associated with each profile refers to the MySQL main-container limit. Requests are intentionally lower to leave scheduler flexibility. Exporter, optional Fluent Bit and initContainer resources are additional small overheads.

`--innodb-buffer-pool-size` overrides the profile's buffer-pool default.

Non-empty `MYSQL_REQUEST_CPU`, `MYSQL_REQUEST_MEM`, `MYSQL_LIMIT_CPU` and `MYSQL_LIMIT_MEM` environment values remain expert overrides and are not replaced by the profile resolver.

## Storage baseline

For a new installation, the selected resource profile supplies the default PVC request:

```text
lite      20Gi
standard  100Gi
large     500Gi
```

`--storage-size` overrides that default.

The default StorageClass remains `nfs` only for backward compatibility. Production deployments should explicitly choose reliable block storage such as Ceph RBD, SAN, Local PV or cloud block volumes when available.

### Existing PVC reconcile semantics

Persistent storage is treated differently from CPU/memory because StatefulSet `volumeClaimTemplates` is immutable.

Rules:

1. Existing PVC + no explicit `--storage-size`: preserve the current PVC request, even if the selected profile has a different new-install default.
2. Existing PVC + explicit `--storage-size`: reconcile the StatefulSet with its existing volumeClaimTemplate value, then patch the PVC request directly.
3. PVC shrink is not supported by Kubernetes and is rejected.
4. PVC expansion requires `StorageClass.allowVolumeExpansion=true`.
5. A bound PVC cannot be moved to another StorageClass through ordinary reconcile. Storage-class changes require a new PVC and data migration.

This prevents a historical 20Gi deployment from being silently changed just because the default profile later becomes `standard=100Gi`.

## Access and security defaults

- NodePort is disabled by default.
- Remote root is enabled by default as `root@'%'` for the current delivery compatibility requirement, but is only reachable through networks that can reach the Kubernetes MySQL Service unless NodePort is explicitly enabled.
- `--enable-remote-root`, `--disable-remote-root` and `--root-remote-host` are idempotent reconcile controls.
- Root password is generated on first install when `--root-password` is omitted.
- Existing `mysql-auth` password is reused on reconcile.
- If an existing StatefulSet is found but its root Secret is missing, installer refuses to invent a replacement password and requires the real password explicitly.
- A conflicting `--root-password` is rejected; ordinary `install` does not perform online root-password rotation.
- mysqld-exporter uses a dedicated account with `PROCESS`, `REPLICATION CLIENT` and `SELECT`, limited to three connections.
- Health probes use local unauthenticated `mysqladmin ping` and do not require a fixed health-check account.
- Legacy `localroot` and `mysqlhealthchecker` users/configuration are removed from the delivery manifests and cleaned from historical instances during reconcile.
- `local_infile=OFF`, `mysqlx=0`, `skip_name_resolve=ON`.
- Service account token mounting and Kubernetes service-link environment injection are disabled for the MySQL Pod.

### Transitional authentication compatibility

MySQL 8.4 disables the deprecated `mysql_native_password` plugin by default. This delivery baseline temporarily enables it with:

```ini
mysql_native_password=ON
```

The installer-managed remote root account uses `mysql_native_password` while this compatibility switch is enabled. Local `root@localhost` and `mysqld_exporter` are not forced onto the legacy plugin.

This is a migration bridge, not a long-term target. After Nacos and application clients are migrated to dedicated accounts and verified with `caching_sha2_password`, the default should switch to `mysql_native_password=OFF` and remote root should be restricted or disabled.

## Runtime baseline

Runtime configuration is a separate source of truth in `manifests/mysql-runtime-config.yaml`. It is applied before creating a new StatefulSet, and existing Pods are restarted once because the ConfigMap is mounted through `subPath`.

Important settings:

- `bind-address=0.0.0.0`
- `character_set_server=utf8mb4`
- `collation_server=utf8mb4_0900_ai_ci`
- `default_time_zone='+00:00'`
- `log_timestamps=UTC`
- `max_connections=300`
- `thread_cache_size=64`
- `max_allowed_packet=64M`
- profile-aware `innodb_buffer_pool_size`
- `innodb_log_buffer_size=64M`
- `innodb_redo_log_capacity=1G`
- `innodb_flush_log_at_trx_commit=1`
- `sync_binlog=1`
- `tmp_table_size=32M`
- `max_heap_table_size=32M`
- `performance_schema=ON`
- slow query log enabled, default threshold 2s
- ROW binlog, GTID enabled, binlog retention 7 days

The profile defaults intentionally leave memory outside the Buffer Pool for connections, temporary tables, Performance Schema and other per-session/runtime allocations.

## Kubernetes lifecycle hardening

The MySQL StatefulSet includes:

- `startupProbe`: 10-second period, 60 failures allowed (about 10 minutes of startup/crash-recovery protection)
- `livenessProbe`: 10-second period
- `readinessProbe`: 5-second period
- `terminationGracePeriodSeconds=120`
- `automountServiceAccountToken=false`
- `enableServiceLinks=false`

This avoids liveness restart loops during initialization or InnoDB recovery and gives mysqld more time for a clean SIGTERM shutdown.

## Logging baseline

- MySQL error log is written to `/var/log/mysql/error.log` and tailed to container stderr.
- Slow query log is written to `/var/log/mysql/slow.log` and, by default, tailed to container stdout.
- `/var/log/mysql` uses an `emptyDir` with a default `2Gi` `sizeLimit`.
- `--mysql-log-size-limit` can change that local buffer size.
- Long-term retention belongs in the central Kubernetes log system, not in the Pod filesystem.
- Optional Fluent Bit sidecar support remains available for projects that explicitly need it.

## Monitoring V2

Default exporter collectors include:

- global status and global variables
- InnoDB metrics
- processlist
- binlog size

Two Grafana dashboards are delivered:

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

Thresholds are production starting points and should be tuned from real workload baselines.

## Manifest layout

Runtime responsibilities are separated into:

```text
mysql-core.yaml
mysql-runtime-config.yaml
mysql-observability.yaml
```

The old combined `innodb-mysql.yaml` has been removed.

## Uninstall and data retention

Default uninstall keeps both:

- MySQL PVC
- root authentication Secret

This allows the same data directory to be reattached without losing its credential contract.

`--delete-pvc` is the destructive path; when explicitly requested, the installer deletes both the PVC and root Secret.

## Account migration TODO

The long-term account model is:

- local administration: `root@localhost`
- Nacos: `nacos_user`
- applications: `app_user` or per-application users
- monitoring: `mysqld_exporter` (already implemented)
- data protection: `mysql_backup`

Remote root and `mysql_native_password` are transitional delivery compatibility mechanisms and should be tightened after dependent clients are migrated.

## Upgrade notes

For an existing persistent MySQL 8.0 data directory, do not treat an image-tag change as the entire upgrade procedure. Before production upgrade, run a MySQL 8.0-to-8.4 compatibility/upgrade check and validate recovery on a copy of production data.

The current installer is primarily the MySQL 8.4.11 new-install and same-version reconcile baseline.

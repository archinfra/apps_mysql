# Data Protection Operator

`data-protection-operator` is a generic data protection control plane for Kubernetes.

Current focus:

- keep the control plane declarative and idempotent
- make backup and restore requests observable through CRD status
- land one real data driver first, then extend to more middleware

## Current CRDs

- `BackupSource`
- `BackupRepository`
- `BackupPolicy`
- `BackupRun`
- `RestoreRequest`

## What Works Today

- `BackupSource` and `BackupRepository` basic validation/status
- `BackupPolicy -> CronJob` reconciliation
- one repository becomes one `CronJob`
- stale `CronJob` cleanup after policy shrink
- `BackupRun -> Job` reconciliation
- `RestoreRequest -> Job` reconciliation
- child `Job` status aggregation back to CRD phase/conditions
- stable naming with truncation and hash fallback
- unit tests for reconciliation and naming

## MySQL Built-In Runtime

MySQL is now the first built-in data driver.

When `BackupSource.spec.driver=mysql` and `BackupPolicy.spec.execution.command/args` are not overridden, the operator renders real MySQL backup/restore Pods instead of the placeholder runner.

Supported in the built-in runtime:

- logical backup by `mysqldump`
- restore from `.sql.gz`
- repository type `nfs`
- repository type `s3` / `minio`
- per-database backup
- per-table backup with `database.table`
- restore mode `merge`
- restore mode `wipe-all-user-databases`
- checksum verification
- retention pruning

Current MySQL runtime strategy:

- MySQL container image runs the backup or restore script
- S3/MinIO repositories add helper containers based on `mc`
- the control plane still stays in Go; data movement is done inside Jobs

## Execution Template

`BackupPolicy.spec.execution` currently supports:

- `runnerImage`
- `helperImage`
- `imagePullPolicy`
- `command`
- `args`
- `serviceAccountName`
- `backoffLimit`
- `ttlSecondsAfterFinished`
- `nodeSelector`
- `tolerations`
- `resources`
- `extraEnv`

Defaults:

- MySQL runner image: `sealos.hub:5000/kube4/mysql:8.0.45`
- S3 helper image: `sealos.hub:5000/kube4/minio-mc:latest`
- generic placeholder image for non-MySQL drivers: `busybox:1.36`

## Current Boundaries

Not finished yet:

- Redis / MongoDB / MinIO / RabbitMQ / Milvus real drivers
- webhook / admission validation
- richer dependency watches
- metrics / tracing / events
- verification and retention execution beyond MySQL

## Next Step

1. harden the MySQL runtime with more integration coverage
2. add backup verification execution for MySQL
3. extend the same model to Redis / MongoDB / MinIO

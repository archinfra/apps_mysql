# apps_mysql

Offline MySQL installer for Kubernetes with built-in backup, restore, and benchmark workflows.

## What It Includes

- Offline `.run` installer build for `amd64` and `arm64`
- StatefulSet-based MySQL deployment
- Built-in backup CronJob and manual backup trigger
- Restore job generation from saved snapshots
- Backup/restore verification workflow
- Offline benchmark workflow with report export

## Project Layout

```text
.
|-- build.sh
|-- install.sh
|-- images/
`-- manifests/
```

## Build

```bash
chmod +x build.sh install.sh
./build.sh --arch amd64
./build.sh --arch arm64
./build.sh --arch all
```

Artifacts:

```text
dist/mysql-installer-amd64.run
dist/mysql-installer-amd64.run.sha256
dist/mysql-installer-arm64.run
dist/mysql-installer-arm64.run.sha256
```

## Install

Minimal install:

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --backup-nfs-server 192.168.10.2 \
  -y
```

If `--backup-nfs-server` is omitted, the installer prompts for it when the action needs backup storage. `--backup-nfs-path` defaults to `/data/nfs-share`.

Storage note:

- The MySQL StatefulSet expects a usable `StorageClass`
- The default is `nfs`
- In our test environment this is provided by the `apps_nfs-provisioner` package

## Backup

Manual backup:

```bash
./dist/mysql-installer-amd64.run backup \
  --namespace mysql-demo \
  --backup-nfs-server 192.168.10.2 \
  -y
```

Restore latest snapshot:

```bash
./dist/mysql-installer-amd64.run restore \
  --namespace mysql-demo \
  --backup-nfs-server 192.168.10.2 \
  --restore-snapshot latest \
  -y
```

Verify backup and restore:

```bash
./dist/mysql-installer-amd64.run verify-backup-restore \
  --namespace mysql-demo \
  --backup-nfs-server 192.168.10.2 \
  -y
```

## Benchmark

Run an offline benchmark and export a report:

```bash
./dist/mysql-installer-amd64.run benchmark \
  --namespace mysql-demo \
  --benchmark-concurrency 32 \
  --benchmark-iterations 3 \
  --benchmark-queries 2000 \
  --report-dir ./mysql-reports \
  -y
```

The script runs a built-in concurrent SQL benchmark, waits for the job, downloads the logs, and writes a report file to `./mysql-reports` by default.

## Default Runtime Values

- namespace: `aict`
- replicas: `1`
- storageClass: `nfs`
- storage size: `10Gi`
- service name: `mysql`
- nodePort service name: `mysql-nodeport`
- nodePort: `30306`
- backup NFS path: `/data/nfs-share`

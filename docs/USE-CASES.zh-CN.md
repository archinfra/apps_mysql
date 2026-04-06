# MySQL 安装器常见使用场景

说明：

1. 下文默认使用 release 产物 `./dist/mysql-installer-amd64.run`
2. 对 `backup / restore / verify-backup-restore / addon-install --addons backup`，推荐始终显式提供 `--mysql-password` 或已有的 `--mysql-auth-secret`

## 场景 1：首次安装，直接带上 NFS 备份

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --backup-nfs-path /data/nfs-share \
  -y
```

适合：

1. 一开始就希望具备标准备份能力
2. 环境里已有 NFS

## 场景 2：先把 MySQL 跑起来，后面再补能力

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --disable-monitoring \
  --disable-fluentbit \
  --disable-backup \
  -y
```

后续补备份：

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

后续补监控：

```bash
./dist/mysql-installer-amd64.run addon-install \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  -y
```

## 场景 3：集群没有 ServiceMonitor CRD

仍然可以补监控：

```bash
./dist/mysql-installer-amd64.run addon-install \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  -y
```

行为：

1. exporter Deployment 仍会安装
2. `ServiceMonitor` 会被跳过
3. 整个动作不会失败

## 场景 4：平台级 Fluent Bit + ES / OpenSearch / Loki

推荐策略：

1. MySQL 只负责数据库本体和必要 addon
2. 日志统一交给平台级 DaemonSet
3. 不默认开启 MySQL sidecar 日志采集

更适合：

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --disable-fluentbit \
  -y
```

## 场景 5：必须采集 slow log 文件

如果平台日志体系拿不到容器内文件日志，可以回到 sidecar 路径：

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --enable-fluentbit \
  -y
```

注意：

1. 这不是 addon 路径
2. 可能触发 StatefulSet 滚动更新

## 场景 6：重装但保留数据

步骤：

1. 执行 `uninstall`，不要带 `--delete-pvc`
2. 保持相同的 `namespace` 和 `--sts-name`
3. 再次执行 `install`

只要 PVC 还在，通常无需 restore。

## 场景 7：PVC 丢失，只能从备份恢复

步骤：

1. 先执行 `install` 创建新的 MySQL 实例
2. 再执行 `restore`

```bash
./dist/mysql-installer-amd64.run restore \
  --namespace mysql-demo \
  --mysql-host mysql-0.mysql.mysql-demo.svc.cluster.local \
  --mysql-user root \
  --mysql-password 'StrongPassw0rd' \
  --mysql-target-name mysql-demo \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --backup-nfs-path /data/nfs-share \
  --restore-snapshot latest \
  -y
```

## 场景 8：关闭 NodePort，仅走集群内访问

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --disable-nodeport \
  -y
```

适合：

1. 不希望额外暴露 NodePort
2. 业务只通过集群内 Service 访问 MySQL

## 场景 9：指定镜像前缀进行安装

```bash
./dist/mysql-installer-amd64.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --registry harbor.example.com/kube4 \
  -y
```

适合：

1. 目标环境有自己的 Harbor / registry
2. 希望安装时统一推送到指定镜像前缀

## 场景 10：运行 benchmark 并拿 JSON 报告

```bash
./dist/mysql-installer-amd64.run benchmark \
  --namespace mysql-demo \
  --mysql-host mysql-0.mysql.mysql-demo.svc.cluster.local \
  --mysql-user root \
  --mysql-password 'StrongPassw0rd' \
  --benchmark-profile oltp-read-write \
  --benchmark-warmup-rows 10000 \
  --benchmark-table-size 300000 \
  --report-dir ./reports \
  -y
```

执行后重点检查：

1. `./reports/*.log`
2. `./reports/*.txt`
3. `./reports/*.json`

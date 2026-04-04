# MySQL 安装器常见使用场景

## 场景 1：首次安装，直接带上 NFS 备份

```bash
./mysql-installer.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  -y
```

适合：

1. 一开始就希望具备标准备份能力。
2. 环境里已有 NFS。

## 场景 2：先把 MySQL 跑起来，后面再补能力

```bash
./mysql-installer.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --disable-monitoring \
  --disable-fluentbit \
  --disable-backup \
  -y
```

后续补备份：

```bash
./mysql-installer.run addon-install \
  --namespace mysql-demo \
  --addons backup \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  -y
```

后续补监控：

```bash
./mysql-installer.run addon-install \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  -y
```

## 场景 3：集群没有 ServiceMonitor CRD

仍然可以补监控：

```bash
./mysql-installer.run addon-install \
  --namespace mysql-demo \
  --addons monitoring,service-monitor \
  -y
```

行为：

1. exporter Deployment 仍会安装。
2. `ServiceMonitor` 会被跳过。
3. 整个动作不会失败。

## 场景 4：你要做平台级 Fluent Bit + ES

推荐策略：

1. MySQL 只负责数据库本体和必要的运维 addon。
2. 日志统一交给 DaemonSet 级 Fluent Bit。
3. 不默认开启 MySQL sidecar 日志采集。

也就是说，你更适合：

```bash
./mysql-installer.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --disable-fluentbit \
  -y
```

## 场景 5：必须采集 slow log 文件

如果平台日志体系拿不到容器内文件日志，则可以回到 sidecar 路径：

```bash
./mysql-installer.run install \
  --namespace mysql-demo \
  --root-password 'StrongPassw0rd' \
  --enable-fluentbit \
  -y
```

注意：

1. 这不是 addon 路径。
2. 可能触发 StatefulSet 滚动更新。

## 场景 6：重装但保留数据

步骤：

1. 执行 `uninstall`，不要带 `--delete-pvc`。
2. 继续使用相同的 `namespace` 和 `--sts-name`。
3. 再次执行 `install`。

只要 PVC 还在，通常无需 restore。

## 场景 7：PVC 丢失，只能从备份恢复

步骤：

1. 先执行 `install` 创建新的 MySQL 实例。
2. 再执行 `restore`。

```bash
./mysql-installer.run restore \
  --namespace mysql-demo \
  --backup-backend nfs \
  --backup-nfs-server 192.168.10.2 \
  --restore-snapshot latest \
  -y
```

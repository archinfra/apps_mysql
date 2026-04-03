# MySQL 安装器测试说明

## 1. 测试目标

测试分为三层：

1. 脚本层：参数解析、帮助输出、语法正确性。
2. 模板层：NFS / S3 双后端的资源渲染逻辑。
3. 运行层：安装、备份、恢复、压测、重复执行与 PVC 复用。

## 2. 当前已完成的本地校验

已完成：

1. `install.sh` Bash 语法检查通过。
2. `./install.sh help` 输出检查通过。
3. `./install.sh help backup` 输出检查通过。

说明：

当前本机缺少 `docker` 和 `kubectl`，因此无法在本地完成运行级验证。

## 3. 2026-04-03 远程实测结果

测试服务器：

- 地址：`36.133.245.109`
- 主机名：`node-01`
- Kubernetes：`v1.31.11`
- Docker：`28.3.3`
- 默认 StorageClass：`nfs`
- `ServiceMonitor` CRD：缺失

已实测通过：

1. `install.sh` 中文帮助输出。
2. `amd64` 离线包构建。
3. NFS 模式安装：
   使用 `mysql-e2e-core` 命名空间，关闭 `monitoring` / `fluentbit`，`nodePort=31306`。
4. 手工备份。
5. `verify-backup-restore` 闭环校验。
6. `benchmark` 压测与报告导出。
7. 不删除 PVC 的 `uninstall` + `install` 重装复用，最终查询结果为 `pvc-reuse-ok`。

实测中发现并已修复：

1. `30306` 在测试集群中已被占用，因此改用 `31306` 做测试。
2. 条件块渲染器最初只识别顶格标记，导致备份模板出现重复 env 警告，已修复为支持缩进标记。
3. `verify-backup-restore` 中的本地 SQL 执行最初使用 `root` 连接不稳定，已改用预置本地管理账号 `localroot`。
4. Job 名称最初只精确到秒，连续触发时可能撞名，已加随机后缀。

受环境限制未完成：

1. 带 `mysqld-exporter`、`fluent-bit`、`minio-mc` 镜像的完整构建，在测试机上受外部镜像源网络限制未完成。
2. S3 运行时闭环测试未完成，因为测试机当前没有可直接访问的对象存储服务。

## 4. 远程环境建议验证矩阵

### 4.1 安装类

1. NFS 模式首次安装。
2. S3 模式首次安装。
3. 同配置重复执行 `install`。
4. 关闭 `fluentbit` 后再次执行 `install`。
5. 补装 `ServiceMonitor` 后再次执行 `install`。

### 4.2 备份恢复类

1. NFS 手工备份。
2. S3 手工备份。
3. NFS 恢复最新快照。
4. S3 恢复最新快照。
5. `verify-backup-restore` 闭环校验。

### 4.3 数据复用类

1. `uninstall` 后不删 PVC，再次 `install`，验证数据仍在。
2. `uninstall --delete-pvc` 后再次 `install`，验证数据为空。

### 4.4 压测类

1. benchmark 默认参数。
2. benchmark 自定义并发与查询量。

## 5. 推荐测试步骤

### 用例 A：NFS 安装 + 备份 + 恢复

1. 安装。
2. 写入测试数据。
3. 执行 `backup`。
4. 修改数据。
5. 执行 `restore`。
6. 验证数据回滚到快照状态。

### 用例 B：S3 安装 + 备份 + 恢复

同上，只是把后端换成 `s3`。

### 用例 C：PVC 复用

1. 安装并写入数据。
2. `uninstall`，不删 PVC。
3. 再次执行 `install`。
4. 验证数据仍然存在。

## 6. 风险点

1. `minio/mc:latest` 为最新标签，后续建议换成固定版本。
2. S3 恢复路径依赖对象存储中已有完整快照目录。
3. 若集群缺少 `kubectl` 访问权限或镜像仓库权限，安装器会在运行期失败。

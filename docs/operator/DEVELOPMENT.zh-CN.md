# Data Protection Operator 开发说明

## 1. 当前阶段

当前阶段的目标不是一次性做完所有中间件的数据面，而是先把控制面和第一批真实 driver 打稳。

目前已经有两层能力：

- 控制面：CRD、controller、状态流转、幂等 reconcile
- 数据面：MySQL 内建 backup/restore runtime

## 2. 当前闭环

已经跑通的主链路：

- `BackupSource` / `BackupRepository` 状态校验
- `BackupPolicy -> CronJob`
- `BackupRun -> Job`
- `RestoreRequest -> Job`
- `Job -> CRD status`
- MySQL + NFS
- MySQL + S3/MinIO

## 3. 目录结构

Operator 位于：

- `operator/data-protection-operator`

关键目录：

- `api/v1alpha1`: CRD 类型、基础校验、命名规则
- `controllers`: controller、资源编排、driver runtime
- `config/crd/bases`: 生成后的 CRD
- `config/samples`: 示例资源
- `hack`: 开发辅助脚本

## 4. Controller 职责

### `BackupSourceReconciler`

- 校验 `spec`
- 回填 `status.phase`
- 标记 `Ready`

### `BackupRepositoryReconciler`

- 校验仓库配置
- 回填 `status.phase`
- 标记 `Ready`

### `BackupPolicyReconciler`

- 校验 source / repository 依赖
- 一个 repository 生成一个 `CronJob`
- 重复 reconcile 幂等
- 计划收缩时自动删除失效 `CronJob`

### `BackupRunReconciler`

- 解析 `policyRef` 或显式 `repositoryRefs`
- 一个 repository 生成一个一次性 `Job`
- 用稳定命名避免重复创建
- 聚合子 `Job` 状态

### `RestoreRequestReconciler`

- 解析 restore 来源
- 生成单个 restore `Job`
- 聚合子 `Job` 状态

## 5. MySQL 内建 Runtime

位置：

- `controllers/mysql_runtime.go`

设计原则：

- 优先复用现有 shell 方案里已经验证过的 MySQL 逻辑
- 控制面继续在 Go controller 里
- 数据导出/导入在 Job 容器里执行
- `nfs` 和 `s3/minio` 走不同 Pod 拓扑

当前行为：

- `nfs`: 单 MySQL 容器直接读写 NFS
- `s3/minio` backup: `mc` initContainer 预拉取历史快照，MySQL 容器产出新快照，`mc` sidecar 回传
- `s3/minio` restore: `mc` initContainer 先下载，再由 MySQL 容器恢复

## 6. 配置约束

MySQL driver 当前做了这些硬性校验：

- 不能同时设置 `databases` 和 `tables`
- `tables` 必须是 `database.table`
- `restoreMode` 只允许 `merge` 或 `wipe-all-user-databases`

## 7. 推荐开发顺序

1. 修改 API 或 controller
2. 运行 `make generate`
3. 运行 `make manifests`
4. 运行 `make test`
5. 再同步到 Linux 开发机验证

## 8. 常用命令

```bash
cd operator/data-protection-operator
make fmt
make generate
make manifests
make test
make build
```

## 9. 工程约束

- `BackupPolicy` 允许更新和清理子 `CronJob`
- `BackupRun` / `RestoreRequest` 视为请求型资源，优先稳定命名和审计
- 区分“依赖暂时不存在”和“配置本身矛盾”
- 所有 controller 都必须优先保证重复 reconcile 幂等

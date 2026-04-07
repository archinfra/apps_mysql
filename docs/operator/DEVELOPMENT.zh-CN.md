# Data Protection Operator 开发说明

## 1. 当前目标

当前阶段优先打稳控制面，而不是一次性做完所有数据面细节。

本轮已经落地的最小闭环是：

- `BackupSource` / `BackupRepository` 基础状态校验
- `BackupPolicy -> CronJob`
- `BackupRun -> Job`
- `RestoreRequest -> Job`
- 子资源状态回推到 CRD `status`

## 2. 当前目录

Operator 位于：

- `operator/data-protection-operator`

关键目录：

- `api/v1alpha1`: CRD 类型与校验
- `controllers`: controller 与资源生成器
- `config/crd/bases`: 生成后的 CRD 清单
- `config/samples`: 样例资源
- `hack`: 开发辅助脚本

## 3. 当前控制器职责

### `BackupSourceReconciler`

- 校验 `spec`
- 回填 `status.phase`
- 标记 `Ready` 条件

### `BackupRepositoryReconciler`

- 校验仓库配置
- 回填 `status.phase`
- 标记 `Ready` 条件

### `BackupPolicyReconciler`

- 校验 `source/repository` 依赖
- 一个 repository 生成一个 `CronJob`
- 重复 reconcile 不重复创建
- 计划缩容时删除失效的旧 `CronJob`
- `suspend` 时保留 `CronJob` 但置为暂停

### `BackupRunReconciler`

- 解析 `policyRef` 或显式 `repositoryRefs`
- 一个 repository 生成一个一次性 `Job`
- 使用稳定命名避免重复创建
- 根据 `Job` 状态聚合 `phase/repositories/completedAt`

### `RestoreRequestReconciler`

- 支持显式 `repositoryRef`
- 如果只给了 `backupRunRef`，且来源唯一，可自动推导仓库
- 生成单个 restore `Job`
- 根据 `Job` 状态聚合 `phase/completedAt`

## 4. Placeholder Runner 约定

当前默认 runner 只是为了先跑通控制面闭环：

- 默认镜像：`busybox:1.36`
- 默认命令：`/bin/sh -c`
- 默认行为：打印操作上下文并退出

如果你已经有自己的 runner 镜像，可以在 `BackupPolicy.spec.execution` 里覆盖：

- `runnerImage`
- `command`
- `args`
- `extraEnv`

## 5. 推荐开发顺序

1. 改 API 或 controller
2. 运行 `make generate`
3. 运行 `make manifests`
4. 运行 `make test`
5. 再同步到 Linux 开发机验证

## 6. 本地常用命令

```bash
cd operator/data-protection-operator
make fmt
make generate
make manifests
make test
make build
```

`Makefile` 已做兼容处理：

- 优先使用 PATH 里的 `go/gofmt`
- 找不到时回退到 `/usr/local/go/bin`
- Windows 下自动使用 `controller-gen.exe`

## 7. 代码约束

- `BackupPolicy` 对子 `CronJob` 允许更新与清理
- `BackupRun` / `RestoreRequest` 视为请求型资源，优先稳定命名和审计，不做激进删除重建
- 依赖“暂时不存在”与“配置本身矛盾”要区分处理
- 所有控制器都要优先保证重复 reconcile 幂等

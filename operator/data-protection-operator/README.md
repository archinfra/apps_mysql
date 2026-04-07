# Data Protection Operator

`data-protection-operator` 是一个面向通用中间件数据保护场景的 Kubernetes Operator 孵化骨架。

当前版本的重点不是一次性做完所有数据面逻辑，而是先把长期可维护的控制面打稳：

- `BackupSource`: 备份对象定义
- `BackupRepository`: 备份仓库定义
- `BackupPolicy`: 周期性备份计划
- `BackupRun`: 一次性手工备份请求
- `RestoreRequest`: 一次性恢复请求

## 当前已实现

- `BackupSource` / `BackupRepository` 基础校验与状态回填
- `BackupPolicy -> CronJob` 的幂等 reconcile
- 一个仓库一个 `CronJob`
- 计划变更后的旧 `CronJob` 自动回收
- `BackupRun -> Job` 的幂等 reconcile
- `RestoreRequest -> Job` 的幂等 reconcile
- `BackupRun` / `RestoreRequest` 从子 `Job` 状态回推上层 phase
- 稳定命名、长度裁剪和哈希兜底
- 基础单元测试

## 当前执行模型

控制器负责控制面编排，真实的数据导出/导入逻辑预留给 runner 容器。

当前如果没有显式指定执行命令，会使用默认 placeholder runner：

- 镜像默认 `busybox:1.36`
- 命令默认 `/bin/sh -c`
- 只打印操作元数据并快速退出

这意味着现在已经可以把整条 CRD -> CronJob/Job -> status 的链路跑通，但还没有接入真正的 MySQL/Redis/MongoDB/MinIO driver 执行逻辑。

## Execution 模板

`BackupPolicy.spec.execution` 当前支持：

- `runnerImage`
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

这套模板会被：

- `BackupPolicy` 生成的定时 `CronJob`
- `BackupRun` 生成的一次性 `Job`
- `RestoreRequest` 在可继承时复用

## 当前边界

当前还没有完成：

- 真正的 MySQL/Redis/MongoDB/MinIO 备份恢复 driver
- webhook / admission 校验
- 更完整的依赖联动 watch
- metrics / tracing / events
- 备份校验与清理策略的执行面

## 下一步建议

1. 先接通 `MySQL driver`，让 placeholder runner 升级为真实备份 runner
2. 把 `BackupPolicy` 的 retention / verify 逐步落到执行面
3. 再扩展 `Redis / MongoDB / MinIO`
4. 最后再评估 `RabbitMQ / Milvus`

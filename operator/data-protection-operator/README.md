# Data Protection Operator

`data-protection-operator` 是一个面向通用数据中间件的备份恢复控制面骨架。

当前阶段的目标不是一次性做完所有数据面逻辑，而是先把长期稳定的控制面抽象定下来：

- `BackupSource`
- `BackupRepository`
- `BackupPolicy`
- `BackupRun`
- `RestoreRequest`

它的设计目标是同时覆盖：

- MySQL
- Redis
- MongoDB
- MinIO
- RabbitMQ
- Milvus

当前骨架实现了：

- API 类型
- manager 启动入口
- `BackupPolicy` / `BackupRun` / `RestoreRequest` 的最小 reconciler
- 开发和远端环境文档

当前还没有落地的数据面能力：

- 真正的 CronJob/Job 编排
- runner 镜像与 driver
- repository fan-out
- restore workflow
- webhook 校验
- metrics / tracing / events

这是预期内的，当前版本是“先收敛控制面模型，再逐步接通执行面”的第一步。

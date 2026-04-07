# Data Protection Operator 开发说明

## 1. 当前目标

当前阶段先落“通用数据保护控制面”的最小骨架，不追求一次性做完全部执行逻辑。

第一阶段收敛的对象是：

- `BackupSource`
- `BackupRepository`
- `BackupPolicy`
- `BackupRun`
- `RestoreRequest`

第一阶段暂不追求：

- 完整 runner 数据面
- 真正的 CronJob/Job fan-out
- webhook
- metrics / tracing
- 多 driver 的完整实现

---

## 2. 目录结构

当前 operator 位于：

[operator/data-protection-operator](C:/Users/yuanyp8/Desktop/archinfra/apps_mysql/operator/data-protection-operator)

关键目录：

- `api/v1alpha1`: CRD 类型定义
- `controllers`: controller 骨架
- `config/samples`: 示例资源
- `hack`: 开发辅助脚本

---

## 3. 当前设计原则

### 3.1 通用控制面

通用的是：

- 备份对象
- 备份仓库
- 备份计划
- 手工备份
- 恢复请求
- 定时任务
- 保留策略
- 多中心
- 状态与审计

### 3.2 专用数据面

不通用的是各个 driver 的执行细节：

- MySQL: 逻辑备份 / 表粒度 / 恢复模式
- Redis: RDB / AOF / key scope
- MongoDB: db / collection
- MinIO: bucket / prefix / version
- RabbitMQ: definitions / queues
- Milvus: db / collection / object storage

所以控制面统一，driver 细节放在 `DriverConfig`。

---

## 4. 当前实现状态

已经完成：

- API 类型草案
- manager 入口
- `BackupPolicy` / `BackupRun` / `RestoreRequest` 的最小 reconciler
- 样例资源

当前 reconciler 还只是 scaffold：

- 接收资源
- 做基础 spec 校验
- 回填 status / conditions
- 预测将来的 CronJob / Job 命名

下一阶段再接：

- 真实 CronJob/Job 创建
- repository fan-out
- source / repository readiness check
- runner contract

---

## 5. 开发节奏建议

建议按这个顺序推进：

1. 把 API `spec/status` 稳住
2. 把 `BackupPolicy -> CronJob` 接通
3. 把 `BackupRun -> Job` 接通
4. 把 `RestoreRequest -> Job` 接通
5. 再拆 MySQL / Redis / MongoDB / MinIO driver

RabbitMQ 和 Milvus 建议放到第二批，因为恢复语义更复杂。

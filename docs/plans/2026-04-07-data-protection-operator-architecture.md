# 2026-04-07 Data Protection Operator 架构草案

## 1. 背景

随着需求从 MySQL 备份恢复扩展到 Redis、MongoDB、MinIO、RabbitMQ、Milvus，仅靠 shell 聚合脚本已经很难继续优雅承载：

1. 多中心
2. 多计划
3. 多状态
4. 多次执行
5. 多 driver
6. 恢复审计
7. 长期维护

因此需要把“数据保护控制面”抽到 Go + CRD + controller。

---

## 2. 目标

把通用能力做成统一控制面：

- 备份对象
- 备份仓库
- 备份计划
- 备份执行
- 恢复请求
- 多中心
- 保留策略
- 定时调度
- 状态与审计

---

## 3. CRD 设计

### 3.1 BackupSource

描述“谁需要被保护”。

### 3.2 BackupRepository

描述“备份存到哪里”。

### 3.3 BackupPolicy

描述“长期如何备份”：

- source
- repositories
- schedule
- retention
- verification

### 3.4 BackupRun

描述“一次具体备份执行”。

### 3.5 RestoreRequest

描述“一次恢复请求”。

---

## 4. 分层原则

### 4.1 通用控制面

Operator 负责：

- 校验 spec
- 管理状态
- 创建 CronJob / Job
- fan-out 到多个 repository
- 记录执行历史
- 施加安全约束

### 4.2 专用执行面

driver 负责：

- 如何连接源
- 如何导出/恢复
- 如何校验结果
- 如何处理各自语义

---

## 5. 当前孵化策略

当前先在 `apps_mysql` 仓库里孵化 operator 骨架，原因是：

1. 现有 backup/restore 经验都在这里
2. 便于把 shell 里已经踩过的场景沉淀进 CRD 设计

长期更合理的方向仍然是：

- 独立仓库
- 独立发布节奏
- 独立 runner 镜像与 driver 生命周期

---

## 6. 第一阶段范围

第一阶段只做：

1. API 类型
2. 基础 controller
3. 样例 CR
4. 开发环境和文档

第二阶段再接：

1. `BackupPolicy -> CronJob`
2. `BackupRun -> Job`
3. `RestoreRequest -> Job`
4. MySQL driver

第三阶段再接：

1. Redis / MongoDB / MinIO driver
2. webhook
3. metrics
4. 历史清理

RabbitMQ 和 Milvus 建议放到更后面。

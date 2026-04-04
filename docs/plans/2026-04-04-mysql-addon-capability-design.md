# MySQL Addon 能力设计说明

日期：2026-04-04

## 1. 背景

已有 MySQL 的运维场景里，经常会出现这样的诉求：

1. 先把数据库本体装起来。
2. 等监控、备份、日志平台准备好之后，再逐步补齐能力。
3. 补齐能力时尽量不要影响业务。

原有安装器虽然已经支持 `install` 重复执行，但“已有实例补能力”的表达还不够清晰，尤其没有把“会不会重建 MySQL Pod”这件事明确产品化。

## 2. 目标

本次设计目标：

1. 让“已有 MySQL 补能力”成为显式命令。
2. 把能力按“是否影响数据库工作负载”分类。
3. 给出明确的日志分层建议。
4. 对没有 `ServiceMonitor` CRD 的集群保持兼容。

## 3. 方案选择

### 方案 A：继续只用 `install`

优点：

1. 逻辑最简单。

缺点：

1. 用户很难快速判断是否会影响业务。
2. “只补一个监控能力”时，语义不清晰。

### 方案 B：所有能力都做 sidecar

优点：

1. 结构统一。

缺点：

1. 已有实例补能力时会改 StatefulSet。
2. 很容易触发滚动更新。

### 方案 C：分成“整套对齐”和“外置 addon”

优点：

1. 对业务影响边界最清晰。
2. 用户可以根据场景选择。
3. 更适合平台工程化分层。

最终选择：方案 C。

## 4. 核心决策

### 决策 1：新增 addon 命令

新增：

1. `addon-install`
2. `addon-uninstall`
3. `addon-status`

### 决策 2：monitoring addon 采用外置 Deployment

而不是继续复用 sidecar。

理由：

1. 外置 Deployment 可以做到“补能力但不动 MySQL Pod”。
2. 符合已有实例后补监控的主要诉求。

### 决策 3：backup addon 采用外置 CronJob

理由：

1. 天然就是外置能力。
2. 不需要改 StatefulSet。

### 决策 4：日志默认交给平台层

理由：

1. 你已经明确要建设 DaemonSet 级 Fluent Bit + ES。
2. 这比把日志 sidecar 塞进每个数据库实例更符合平台工程化分层。

### 决策 5：Fluent Bit sidecar 继续保留，但不进入 addon 默认路径

理由：

1. 仍有 slow log 文件级采集需求。
2. 但这条路径需要明确提示“可能触发滚动更新”。

## 5. 风险与应对

### 风险 1：集群无 ServiceMonitor CRD

应对：

1. 只跳过 `ServiceMonitor`。
2. 监控 addon 主体继续安装。

### 风险 2：已有实例已经启用 sidecar exporter

应对：

1. `addon-install monitoring` 显式拒绝叠加外置 exporter。
2. 避免重复采集和语义冲突。

### 风险 3：日志边界不清

应对：

1. help / README / 架构文档里明确说明“日志优先平台层”。

## 6. 验证要求

必须验证：

1. `addon-install backup` 不重建 MySQL Pod。
2. `backup` 手工备份链路仍可用。
3. `addon-install monitoring` 不重建 MySQL Pod。
4. `ServiceMonitor` CRD 缺失时可跳过。
5. `addon-uninstall monitoring` 不重建 MySQL Pod。
6. `addon-uninstall backup` 不重建 MySQL Pod。

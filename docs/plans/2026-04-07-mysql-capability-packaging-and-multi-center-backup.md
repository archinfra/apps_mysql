# 2026-04-07 MySQL 多中心备份与多产物方案

## 1. 背景

当前脚本虽然已经具备安装、备份恢复、压测、监控等多种能力，但对外呈现仍然偏“集成怪”：

1. 只想压测一个现有 MySQL，也要理解整套安装器
2. 只想给已有 MySQL 做多地备份，也要带着很多非目标能力
3. 备份模型还停留在“单一后端参数”，难以表达多中心、多调度、多范围导出

因此这轮目标不是简单拆代码，而是把“交付形态”和“能力抽象”一起梳理清楚。

---

## 2. 方案结论

### 2.1 对外产品形态

保留一个集成包，同时拆出三个能力包：

1. `mysql-installer-<arch>.run`
2. `mysql-backup-restore-<arch>.run`
3. `mysql-benchmark-<arch>.run`
4. `mysql-monitoring-<arch>.run`

这样既不丢离线整体交付能力，也让专项场景可以轻装上阵。

### 2.2 备份恢复抽象

把原来的单一存储配置升级成 `backup plan`：

1. 一个 plan 对应一个目的地
2. 一个 plan 对应一条 schedule
3. 一个 plan 对应一个 retention
4. 一个 plan 对应一个导出范围

于是自然支持：

1. 多个 NFS
2. 多个 MinIO / S3
3. NFS + S3 混合
4. 默认主计划 + 额外计划
5. 只导出某些库
6. 只导出某些表

---

## 3. 为什么不是彻底拆成四套独立代码

不建议四套代码各自生长，原因是：

1. backup / restore / addon backup 本身高度共享
2. benchmark 也依赖同一套参数、镜像和运行时工具
3. 真正的问题不是源码必须分裂，而是“产物职责”和“用户入口”必须清晰

因此当前采用：

1. 一套源码
2. 多个 package profile
3. 构建时按 profile 裁剪镜像和 manifest
4. 运行时按 profile 限制动作

这是更均衡的做法。

---

## 4. 恢复与安全边界

多中心和部分导出带来一个必须显式处理的风险：

1. 如果备份只包含部分库或表
2. restore 却先执行 `wipe-all-user-databases`
3. 就会删掉不在 dump 里的其他用户库

因此方案中明确约束：

1. 部分备份来源只允许 `merge`
2. `wipe-all-user-databases` 只允许全量来源
3. `verify-backup-restore` 只选择覆盖校验表的来源做恢复验证

---

## 5. 用户视角的最终表达

这套东西不再建议描述为“一个臃肿安装器”，更合适的定位是：

`MySQL 离线交付与运维工具包`

它包含两类模式：

1. 交付模式：integrated
2. 能力模式：backup-restore / benchmark / monitoring

对其他项目来说：

1. 想压测，不需要先安装 MySQL
2. 想做备份恢复，不需要带上整套安装逻辑
3. 想多中心备份，只需要组织 backup plan

---

## 6. 本轮落地项

已经落地：

1. `backup plan` 参数与校验
2. 多计划 CronJob / 手工 Job / restore-source
3. 按库 / 按表导出
4. `--backup-plan-file` 的 YAML/JSON 配置文件入口
5. 局部备份恢复的安全边界
6. 多 package profile 构建
7. GitHub Actions 矩阵产物
8. README 与文档重写

后续可继续演进：

1. 为 plan 增加更结构化的 YAML/JSON 输入方式
2. 增加导出前后校验指标
3. 增加恢复前 dry-run / plan 预览
4. 把监控包继续细分为 exporter-only 与 service-monitor-only

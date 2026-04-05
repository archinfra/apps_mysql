# 2026-04-06 Installer Source Layout ADR

## Status

Accepted

## Context

`install.sh` 需要继续保留为最终单文件产物，因为：

- 安装器分发形态本身就是单文件 `.run`
- 用户排障时习惯直接查看最终 installer
- GitHub Actions 构建时也需要一个可直接拼接 payload 的入口脚本

之前为了降低单文件维护成本，把 installer 按函数拆成了很多小文件。

这个方案在工程上暴露了几个问题：

1. 目录按“语法结构”拆，而不是按“职责域”拆。
2. 一个需求经常跨很多函数，改动分散，review 成本高。
3. 新维护者很难快速判断某类问题应该修改哪里。
4. 组装时还要依赖 `module-order.txt` 维护顺序，增加了一层额外同步成本。

## Decision

改为“单文件产物 + 职责模块源码”的模式：

- 最终产物仍然是仓库根目录 `install.sh`
- 源码组织改为 `scripts/install/modules/*.sh`
- 模块按职责划分，而不是按函数划分
- assembler 直接按模块文件名前缀排序组装，不再维护 `module-order.txt`

当前模块划分如下：

- `00-header.sh`
- `10-core.sh`
- `20-help.sh`
- `30-args.sh`
- `40-inputs-and-plan.sh`
- `50-render-and-apply.sh`
- `60-runtime.sh`
- `70-lifecycle-actions.sh`
- `80-data-actions.sh`
- `90-benchmark-and-main.sh`

## Rationale

这个方案在几个维度上更平衡：

### 可维护性

一个功能点通常会落在 1 到 2 个模块内，修改范围更容易预测。

### 可 review 性

review 时能直接看出这是“参数与校验改动”还是“benchmark 改动”，而不是在大量单函数文件里来回跳转。

### 复杂度控制

模块数保持在少量、稳定、可理解的范围内，避免目录爆炸。

### 分发兼容

不改变最终 installer 的单文件形态，对离线构建和分发方式没有负面影响。

## Consequences

正向影响：

- 更适合长期维护
- 组装逻辑更简单
- 更适合后续继续演进 install / addon / backup / benchmark

代价：

- 单个模块文件会比“一个函数一个文件”更长
- 需要团队遵守“按职责拆分”而不是重新碎片化

## Follow-up Rules

后续修改 installer 时遵循：

1. 优先修改 `scripts/install/modules/*.sh`
2. 不直接手工改 `install.sh`
3. 仅当职责边界明显扩张时才新增模块
4. 不恢复函数级拆分

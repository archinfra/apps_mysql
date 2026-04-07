# MySQL 工具包测试说明

## 1. 本轮变更重点

这轮重点不是单点修 bug，而是能力抽象升级：

1. backup 升级为多 `backup plan`
2. 支持多个 NFS、多个 MinIO/S3，以及混合多中心备份
3. 支持按库、按表导出
4. 支持 `--restore-source` 指定恢复来源
5. build / GitHub Actions 改为构建多个产物包

---

## 2. 已完成的静态校验

本地已完成：

1. `bash -n build.sh`
2. `bash -n install.sh`
3. `bash -n scripts/install/modules/*.sh`
4. 重新组装 `install.sh`

说明：

1. 组装链路是通的
2. 最终脚本语法无错误
3. 多包构建逻辑在脚本层面已接通

---

## 3. 本轮建议重点实测

### 3.1 多计划备份

建议验证：

1. 默认主计划 + 额外 `--backup-plan`
2. `--disable-default-backup-plan` 后仅保留显式计划
3. 多个 NFS 同时落地
4. NFS + MinIO 混合落地

检查：

```bash
kubectl get cronjob -n <ns>
kubectl get secret -n <ns>
kubectl logs -n <ns> job/<manual-backup-job>
```

### 3.2 范围导出

建议验证：

1. `--backup-databases`
2. `--backup-tables`
3. meta 文件中是否能看到 scope / databases / tables

### 3.3 restore-source

建议验证：

1. `--restore-source <plan-name>`
2. `--restore-source auto`
3. 指定 plan 不存在时的失败提示

### 3.4 危险模式边界

建议验证：

1. 部分库/表备份 + `--restore-mode merge`
2. 部分库/表备份 + `--restore-mode wipe-all-user-databases` 是否被阻断
3. `verify-backup-restore` 是否只挑覆盖校验表的 plan 作为恢复来源

### 3.5 多产物构建

建议检查 Actions 或本地构建结果：

1. `mysql-installer-<arch>.run`
2. `mysql-backup-restore-<arch>.run`
3. `mysql-benchmark-<arch>.run`
4. `mysql-monitoring-<arch>.run`

每个产物都应带对应 `.sha256`。

---

## 4. 推荐验证顺序

1. 先验证 `build.sh --arch amd64 --profile all`
2. 再验证 `mysql-backup-restore-*.run` 的多中心 backup addon
3. 再验证手工 `backup`
4. 再验证 `restore --restore-source`
5. 最后验证 `mysql-benchmark-*.run` 和 `mysql-monitoring-*.run`

---

## 5. 远端实测建议

如果使用你的测试机：

1. 先做一个单库或单表的小范围 plan 冒烟
2. 再上多中心计划
3. 再做 restore-source 指定恢复
4. 最后再做完整闭环校验

这样更容易在早期发现路径、凭据、对象存储目录或 NFS 挂载问题。

# MySQL 安装器测试说明

## 1. 当前阶段说明

当前这一轮的主要变化是：

1. installer 源码组织从“按函数拆分”改为“按职责模块拆分”
2. benchmark 改为使用官方 `sysbench` 镜像
3. README / 架构说明 / 使用说明 / addon 说明按新结构统一更新

这一轮在本地没有做新的集群实跑，只做了静态校验。

---

## 2. 已完成的静态校验

已完成：

1. `bash -n install.sh`
2. `bash -n build.sh`
3. `bash -n scripts/assemble-install.sh`
4. 重新组装后确认 `install.sh` 无重复函数定义

这意味着：

1. 组装链路是通的
2. 最终脚本语法层面可解析
3. 但仍需要远端环境做真实行为验证

---

## 3. 历史远端验证结论

### 3.1 已验证通过的主链路

历史上已验证通过：

1. `install` 基线安装
2. `backup`
3. `verify-backup-restore`
4. `benchmark`
5. `uninstall` 后保留 PVC 再执行 `install` 的数据复用

### 3.2 已验证通过的 addon 能力

历史上已验证通过：

1. `addon-status`
2. `addon-install backup`
3. `addon-install monitoring`
4. 无 `ServiceMonitor` CRD 时跳过逻辑
5. `addon-uninstall monitoring`
6. `addon-uninstall backup`
7. addon 路径下 MySQL Pod UID 不变

---

## 4. 当前还需要重点验证什么

针对这轮结构和文档调整，建议优先验证：

1. GitHub Actions 是否能正常从 `scripts/install/modules/*.sh` 组装出 `install.sh`
2. 构建阶段是否能直接拉取官方 `openeuler/sysbench` 镜像
3. `install --disable-nodeport` 是否不再创建 NodePort Service
4. `addon-install --addons backup` 是否仍要求显式 MySQL 认证
5. `restore --restore-snapshot latest` 是否能在 `latest.txt` 失效时自动回退
6. `benchmark` 是否仍能输出 `.log / .txt / .json`
7. README 中的典型命令是否都能跑通

---

## 5. 推荐验证顺序

### 5.1 构建验证

先看 Actions 产物是否生成：

1. `mysql-installer-amd64.run`
2. `mysql-installer-amd64.run.sha256`
3. `mysql-installer-arm64.run`
4. `mysql-installer-arm64.run.sha256`

### 5.2 install 验证

建议优先验证两条：

1. 默认安装链路
2. `--disable-nodeport` 链路

检查：

```bash
kubectl get pods -n <ns>
kubectl get sts -n <ns>
kubectl get svc -n <ns>
kubectl get pvc -n <ns>
```

### 5.3 addon 验证

建议验证：

1. `addon-install monitoring,service-monitor`
2. `addon-install backup`

重点确认 MySQL Pod UID 是否变化。

### 5.4 backup / restore 验证

建议验证：

1. 手工 `backup`
2. `restore --restore-snapshot latest`
3. latest 指向失效快照时的回退行为

### 5.5 benchmark 验证

建议验证：

1. benchmark Job 可启动
2. 报告目录里同时生成 `.log / .txt / .json`
3. JSON 里能看到 profile、TPS/QPS、延迟统计

---

## 6. 建议理解

从当前架构看，正确的验证心智模型应该是：

1. `install` 负责本体和 StatefulSet 级能力
2. `addon-install` 负责外围补能力
3. 根目录 `install.sh` 是最终产物，不是主要源码入口
4. `scripts/install/modules/*.sh` 才是后续持续维护的源码入口

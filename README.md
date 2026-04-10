# apps_mysql

面向 Kubernetes 的 MySQL 离线交付与运维工具包。

这个仓库不是单纯放一个 StatefulSet manifest，而是把下面几类能力按不同产物包做了拆分：

- MySQL 安装与对齐
- 监控补装
- 压测
- 离线 `.run` 安装包交付

从当前版本开始，备份恢复已经迁移到独立数据保护系统，不再由 `apps_mysql` 承担。

## 这套仓库是怎么设计的

`apps_mysql` 和其他单一中间件仓库不完全一样，它会构建出 3 类产物：

- `mysql-installer-<arch>.run`
- `mysql-monitoring-<arch>.run`
- `mysql-benchmark-<arch>.run`

可以这样理解：

- 想安装 MySQL 本体，用 `mysql-installer`
- 已有 MySQL，只想补监控，用 `mysql-monitoring`
- 只想做标准压测，用 `mysql-benchmark`

也就是说，`apps_mysql` 已经把“数据库本体、外围监控、压测”拆开了，使用者不需要为了压测或补监控把整套安装器一起带上。

## 产物包与能力边界

### `mysql-installer-<arch>.run`

适合：

- 首次离线安装 MySQL
- 对齐 StatefulSet / Service / PVC / Secret / ConfigMap
- 同时决定是否启用 exporter、ServiceMonitor、NodePort、Fluent Bit sidecar

支持动作：

- `install`
- `uninstall`
- `status`
- `addon-install`
- `addon-uninstall`
- `addon-status`
- `benchmark`
- `help`

### `mysql-monitoring-<arch>.run`

适合：

- 集群里已经有 MySQL
- 不想因为补监控而改动 MySQL StatefulSet
- 只想额外部署一个独立 exporter 和 `ServiceMonitor`

支持动作：

- `addon-install`
- `addon-uninstall`
- `addon-status`
- `status`
- `help`

### `mysql-benchmark-<arch>.run`

适合：

- 只对某个 MySQL 进行标准化压测
- 不携带安装和监控能力

支持动作：

- `benchmark`
- `help`

## 默认部署契约

如果你直接使用 `mysql-installer` 默认安装，关键默认值如下：

- namespace: `aict`
- StatefulSet name: `mysql`
- Service name: `mysql`
- NodePort Service name: `mysql-nodeport`
- auth secret: `mysql-auth`
- replicas: `1`
- root password: `passw0rd`
- storage class: `nfs`
- storage size: `10Gi`
- MySQL port: `3306`
- NodePort: `30306`
- monitoring: `true`
- ServiceMonitor: `true`
- metrics service name: `mysql-metrics`
- metrics port: `9104`
- Fluent Bit sidecar: `false`
- wait timeout: `10m`
- target image repo: `sealos.hub:5000/kube4`
- resource profile: `mid`

### Resource profile

Installer now supports:

- `--resource-profile low`
- `--resource-profile mid`
- `--resource-profile midd`
- `--resource-profile high`

Default is `mid`. `midd` is accepted as an alias of `mid`.

Profile intent:

- `low`: demo or lightweight validation
- `mid`: normal shared environment, baseline for `500-1000` concurrency and around `10000` users
- `high`: heavier traffic or larger working set

Per-profile baseline:

| Profile | MySQL | Exporter | Fluent Bit | Init container |
| --- | --- | --- | --- | --- |
| `low` | `200m / 512Mi` request, `500m / 1Gi` limit | `50m / 64Mi` request, `100m / 128Mi` limit | `50m / 64Mi` request, `100m / 128Mi` limit | `20m / 32Mi` request, `100m / 64Mi` limit |
| `mid` | `500m / 1Gi` request, `1 / 2Gi` limit | `100m / 128Mi` request, `200m / 256Mi` limit | `100m / 128Mi` request, `200m / 256Mi` limit | `50m / 64Mi` request, `200m / 128Mi` limit |
| `high` | `1 / 2Gi` request, `2 / 4Gi` limit | `200m / 256Mi` request, `500m / 512Mi` limit | `200m / 256Mi` request, `500m / 512Mi` limit | `100m / 128Mi` request, `300m / 256Mi` limit |

这套默认值是“单实例 MySQL + 默认开启监控 + 默认开放 NodePort”的交付方案。

## 默认拓扑

默认安装：

```bash
./mysql-installer-amd64.run install -y
```

会创建：

- 1 个 MySQL StatefulSet
- 1 个 headless Service：`mysql`
- 1 个 NodePort Service：`mysql-nodeport`
- 1 个 metrics Service：`mysql-metrics`
- 1 个 `ServiceMonitor`
- 1 个 PVC
- 1 个 MySQL root Secret
- 1 个 probe ConfigMap
- 1 个 init users ConfigMap
- 1 个 MySQL 配置 ConfigMap

如果启用了 `--enable-fluentbit`，还会多出：

- 1 个 Fluent Bit sidecar
- 1 个 Fluent Bit ConfigMap

## 默认访问地址、端口和账密

这部分是给新接手的人和 AI 最常用的“系统契约”。

### 集群内访问

默认 MySQL StatefulSet 名和 headless Service 都是 `mysql`，因此常用地址是：

- 直接连单实例：`mysql-0.mysql.aict.svc.cluster.local:3306`
- 通过 service 访问：`mysql.aict.svc.cluster.local:3306`

对于需要稳定连接单实例的下游组件，推荐使用：

- `mysql-0.mysql.aict`

这也是 `apps_nacos` 当前默认使用的 MySQL 主机名。

### 集群外访问

默认启用 NodePort，因此可以通过任意工作节点 IP 访问：

- `<NODE_IP>:30306`

### 默认账号体系

默认会初始化这些账号：

- `root`
  密码来自 `mysql-auth` Secret，默认值是 `passw0rd`
- `localroot@localhost`
  默认密码：`local@paasw0rd`
  主要用于容器内本地维护
- `mysqlhealthchecker@localhost`
  默认密码：`health@passw0rd`
  仅用于健康检查
- `repl@%`
  默认密码：`repl@passw0rd`
  用于复制场景
- `orch@%`
  默认密码：`orch@passw0rd`
  用于编排/巡检类场景

如果你使用 `addon-install` 部署独立 exporter，还会额外创建：

- `mysqld_exporter`
  默认密码：`exporter@passw0rd`

注意：

- 这些密码是仓库默认值，适合测试和初始交付
- 生产环境建议在首次安装时就显式改掉 `root` 密码
- 如果你把这套文档给 AI 使用，默认也应该要求它优先显式传入生产密码，而不是依赖仓库默认值

## 默认资源需求

### MySQL 主容器

默认主容器资源：

- request: `500m CPU / 1Gi memory`
- limit: `1 CPU / 2Gi memory`

### 内嵌 exporter sidecar

默认 exporter 资源：

- request: `100m CPU / 128Mi memory`
- limit: `200m CPU / 256Mi memory`

### 可选 Fluent Bit sidecar

开启 `--enable-fluentbit` 后，默认资源：

- request: `100m CPU / 128Mi memory`
- limit: `200m CPU / 256Mi memory`

### 默认总量

默认单实例并开启内嵌监控时：

| 项目 | 默认值 |
| --- | --- |
| CPU request | `600m` |
| Memory request | `1152Mi` |
| CPU limit | `1.2` |
| Memory limit | `2304Mi` |

如果同时启用了 Fluent Bit，则额外增加：

- request: `100m CPU / 128Mi memory`
- limit: `200m CPU / 256Mi memory`

### 存储需求

默认 PVC：

- `10Gi`

如果你把副本数调成 `N`，最低持久化存储需求也应按 `N x 10Gi` 估算。

## 日志设计

日志这块是 `apps_mysql` 和其他仓库最不一样的地方之一，因为它同时考虑了：

- `kubectl logs`
- 平台日志采集
- 可选 Fluent Bit sidecar

当前默认行为：

- 错误日志写入 `/var/log/mysql/error.log`
- slow log 写入 `/var/log/mysql/slow.log`
- 默认把错误日志转到容器 `stderr`
- 默认把 slow log 转到容器 `stdout`

所以默认就可以直接：

```bash
kubectl logs -n aict mysql-0 -c mysql
```

启用 `--enable-fluentbit` 后：

- MySQL 错误日志仍保留在 `mysql` 容器 `stderr`
- slow log 改为文件
- `fluent-bit` sidecar 负责把 slow log 转发到自己的 `stdout`

适用建议：

- 平台有统一日志采集时，优先直接采容器 stdout/stderr
- 只有明确需要 Pod 内慢日志文件时，再启用 `--enable-fluentbit`

## 监控设计

MySQL 监控支持两种模式：

### 模式 1：安装器内嵌监控

由 `mysql-installer` 直接把 exporter sidecar 放进 MySQL Pod。

默认行为：

- `monitoring=true`
- `serviceMonitor=true`
- metrics Service：`mysql-metrics`
- metrics 端口：`9104`
- `ServiceMonitor` 标签：`monitoring.archinfra.io/stack=default`

### 模式 2：addon 独立监控

由 `mysql-monitoring` 或 `mysql-installer addon-install` 单独部署一个 exporter Deployment。

默认对象：

- Deployment：`mysql-exporter`
- Service：`mysql-exporter`
- Secret：`mysql-exporter-auth`
- ServiceMonitor：`mysql-exporter-monitor`

默认监控目标：

- `mysql-0.mysql.aict:3306`

### 和 Prometheus 的关系

如果你的 Prometheus Stack 按我们统一方案启用了按标签发现，那么 MySQL 的默认 `ServiceMonitor` 会被自动发现，因为它默认带了：

- `monitoring.archinfra.io/stack=default`

## 和其他组件的依赖关系

### MySQL 不依赖谁

MySQL 默认不依赖这些组件启动：

- Redis
- Nacos
- MinIO
- RabbitMQ
- MongoDB
- Milvus

### 谁常常依赖 MySQL

在我们当前这套组件体系里，最直接依赖 MySQL 的是：

- `apps_nacos`

`apps_nacos` 的默认参数就是：

- host: `mysql-0.mysql.aict`
- port: `3306`
- database: `frame_nacos_demo`
- user: `root`

所以如果你是先装 MySQL 再装 Nacos，这两个组件天然能接上。

### 备份恢复边界

`apps_mysql` 已经不再承载备份恢复能力。

当前边界是：

- 安装、监控、压测：`apps_mysql`
- 备份恢复、多中心数据保护：独立数据保护系统

不要再从 `apps_mysql` 中寻找：

- `backup`
- `restore`
- `verify-backup-restore`

## 常见使用场景

### 场景 1：首次安装单实例 MySQL

```bash
./mysql-installer-amd64.run install \
  --namespace aict \
  --root-password 'StrongPassw0rd' \
  -y
```

### 场景 2：安装时关闭 NodePort

```bash
./mysql-installer-amd64.run install \
  --disable-nodeport \
  --root-password 'StrongPassw0rd' \
  -y
```

### 场景 3：安装时关闭内嵌监控

```bash
./mysql-installer-amd64.run install \
  --disable-monitoring \
  --disable-service-monitor \
  --root-password 'StrongPassw0rd' \
  -y
```

### 场景 4：只给已有 MySQL 补独立监控

```bash
./mysql-monitoring-amd64.run addon-install \
  --namespace aict \
  --mysql-host mysql-0.mysql.aict \
  --mysql-password 'StrongPassw0rd' \
  -y
```

### 场景 5：只做 benchmark

```bash
./mysql-benchmark-amd64.run benchmark \
  --namespace aict \
  --mysql-host mysql-0.mysql.aict \
  --mysql-password 'StrongPassw0rd' \
  -y
```

## 给 AI 或自动化系统的执行规则

如果后续把安装包放到服务器上，希望由 AI 自动安装，这几个规则最重要。

### 默认优先策略

如果没有额外约束，优先使用：

- `mysql-installer`
- `namespace=aict`
- 单实例
- 开启监控
- 开启 `ServiceMonitor`
- 开启 NodePort
- 显式传入 `--root-password`

### 成功标准

可以把下面这些作为安装成功信号：

- `mysql-0` Pod `Running`
- `mysql` Service 存在
- `mysql-nodeport` Service 存在
- PVC 已绑定
- `mysql-metrics` Service 存在
- 如果集群有 `ServiceMonitor` CRD，则 `mysql-monitor` 存在
- `kubectl logs` 能正常看到 MySQL 日志

### 失败信号

- PVC 长时间 `Pending`
- `mysql-0` `CrashLoopBackOff`
- `mysql-auth` Secret 不存在或密码未正确传入
- metrics Service 存在但 exporter 没启动
- 误把备份恢复需求交给 `apps_mysql`

## 常见排障命令

```bash
./mysql-installer-amd64.run status -n aict
kubectl get pods,svc,pvc -n aict
kubectl logs -n aict mysql-0 -c mysql --tail=200
kubectl get servicemonitor -A | grep mysql
```

如果是独立 addon 监控：

```bash
kubectl get deploy,svc -n aict | grep mysql-exporter
kubectl logs -n aict deploy/mysql-exporter --tail=200
```

## 构建与发布

当前构建会产出：

- `mysql-installer-<arch>.run`
- `mysql-monitoring-<arch>.run`
- `mysql-benchmark-<arch>.run`

运行时依赖：

- 目标机器需要 `kubectl`
- 如需导入和推送离线镜像，还需要 `docker`
- 最终 `.run` 安装包运行时不依赖 `jq`

GitHub Actions 负责：

- `main/master` 多架构构建
- `v*` tag 发布 release
## Built-in Monitoring, Alerts, And Dashboards

Default install now enables:

- `monitoring=true`
- embedded exporter
- `ServiceMonitor`
- `PrometheusRule`
- Grafana dashboard `ConfigMap`

Grafana auto-import contract:

- dashboard label: `grafana_dashboard=1`
- platform label: `monitoring.archinfra.io/stack=default`
- folder annotation: `grafana_folder=Middleware/MySQL`

Built-in alerts:

- `MySQLDown`
- `MySQLConnectionsHigh`
- `MySQLSlowQueriesHigh`

Built-in dashboard panels:

- MySQL Up
- Threads Connected
- Threads Running
- Slow Queries / 1h
- Query Rate
- Connections

If the cluster does not provide the `PrometheusRule` CRD, the installer automatically disables rule creation and keeps the main MySQL deployment path available.

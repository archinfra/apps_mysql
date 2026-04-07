# Data Protection Operator 环境处理文档

## 1. 当前指定开发机

本轮指定的 controller 开发机是：

- Host: `36.138.61.152`
- User: `root`
- Hostname: `hm-test1`
- OS: `Ubuntu 22.04.4 LTS`

当前已确认机器上已有：

- `git`
- `docker`
- `kubectl`
- `make`
- `gcc`

当前已确认机器上没有直接进 PATH 的 `go`，但存在：

- `/usr/local/go/bin/go`
- `/usr/local/go/bin/gofmt`

所以当前环境更适合用“补 PATH + 拉工具”的方式，而不是重新装一遍系统包版 Go。

---

## 2. 推荐工作目录

建议在开发机上使用：

```bash
mkdir -p /root/workspace
cd /root/workspace
git config --global http.version HTTP/1.1
git clone https://github.com/archinfra/apps_mysql.git
cd apps_mysql/operator/data-protection-operator
```

---

## 3. 初始化命令

```bash
export PATH=/usr/local/go/bin:$PATH
cd /root/workspace/apps_mysql/operator/data-protection-operator
bash hack/bootstrap-dev-env.sh
```

脚本会做：

1. 确保 `go` 在 PATH 中
2. 安装 `controller-gen` 到本地 `bin/`
3. 执行 `go mod tidy`

---

## 4. 常用开发命令

```bash
export PATH=/usr/local/go/bin:$PATH
cd /root/workspace/apps_mysql/operator/data-protection-operator
make fmt
make generate
make manifests
make test
make build
```

---

## 5. 当前环境注意点

1. Ubuntu 22.04 自带 `apt` 的 `golang-go` 只有 `1.18`，不建议作为 operator 主开发版本。
2. 当前机器已经有 `/usr/local/go/bin/go`，优先直接使用。
3. 如果后续要做 `envtest`、`kind`、`kubebuilder`，再单独补工具，不要第一天一次装满。
4. 当前项目还处于 CRD/operator 孵化阶段，建议先保证 `go test` 和 `make manifests` 跑通。
5. 这台机器曾出现过 GitHub HTTP/2 clone 异常，因此文档里默认先设 `git config --global http.version HTTP/1.1`。

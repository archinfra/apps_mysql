# Data Protection Operator 环境处理文档

## 1. 指定开发机

当前指定的 controller Linux 开发机：

- Host: `36.138.61.152`
- User: `root`
- Hostname: `hm-test1`
- OS: `Ubuntu 22.04.4 LTS`

## 2. 已确认的环境现状

机器上已有：

- `git`
- `docker`
- `kubectl`
- `make`
- `gcc`

Go 不在默认 PATH，但可直接使用：

- `/usr/local/go/bin/go`
- `/usr/local/go/bin/gofmt`

## 3. 推荐工作目录

```bash
mkdir -p /root/workspace
cd /root/workspace
git config --global http.version HTTP/1.1
git clone https://github.com/archinfra/apps_mysql.git
cd apps_mysql/operator/data-protection-operator
```

如果仓库已经存在，直接进入目录更新即可。

## 4. 初始化命令

```bash
export PATH=/usr/local/go/bin:$PATH
cd /root/workspace/apps_mysql/operator/data-protection-operator
bash hack/bootstrap-dev-env.sh
```

脚本会：

- 确保 `go` 可执行
- 安装 `controller-gen`
- 执行 `go mod tidy`

## 5. 常用验证命令

```bash
export PATH=/usr/local/go/bin:$PATH
cd /root/workspace/apps_mysql/operator/data-protection-operator
make fmt
make generate
make manifests
make test
make build
```

## 6. 本轮验证基线

当前这套 operator 开发流，至少应保证以下命令稳定通过：

- `bash hack/bootstrap-dev-env.sh`
- `make generate`
- `make manifests`
- `make test`

如果只是验证控制面闭环，不要求当前就接真实的业务备份镜像。

## 7. 注意事项

1. `apt install golang-go` 在这台机器上只有 `1.18`，不要作为主开发版本。
2. 优先补 PATH 使用 `/usr/local/go/bin`。
3. 机器曾出现过 GitHub HTTP/2 clone 异常，所以建议保留 `git config --global http.version HTTP/1.1`。
4. Windows 本地与 Linux 远端都可以跑同一份 `Makefile`，但最终仍以 Linux 远端结果为准。
5. 如果通过压缩包或脚本从 Windows 同步代码到 Linux，请排除本地产物目录 `operator/data-protection-operator/bin/`，避免把 `.exe` 或错误平台的二进制带到远端。

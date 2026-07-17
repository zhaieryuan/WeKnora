## Why

在 Apple Silicon macOS 上执行 `make dev-app` 时，Go 进程会在进入 `main` 之前崩溃。崩溃来自 Milvus 客户端间接引入的 `github.com/shoenig/go-m1cpu@v0.1.6`：其 Darwin/arm64 C 初始化路径会解引用空的 CoreFoundation 数据，导致 `SIGSEGV`，使本地开发环境即使基础设施已就绪也无法启动应用。

## What Changes

- 将间接依赖 `github.com/shoenig/go-m1cpu` 固定到包含空值保护和惰性初始化修复的兼容版本，避免 Apple Silicon 启动期崩溃。
- 保持 Milvus、gopsutil 以及其余依赖版本不变，避免为该单点故障引入无关依赖升级。
- 为 Air 热重载配置显式设置 `build.entrypoint`，消除新版 Air 对仅使用 `build.bin` 的弃用提示。
- 增加以真实 `make dev-app` 启动和 HTTP 探活为核心的验证，确保修复不止能编译，而且应用能完成初始化并提供服务。
- 不改变 REST、CLI、gRPC、数据库、配置、鉴权、租户隔离、异步任务或部署契约。

## Capabilities

### New Capabilities

- `portable-dev-app-startup`: 约束本地 Go 应用在受支持的 Apple Silicon macOS 环境中不得因 CPU 探测依赖而在启动阶段崩溃，并要求完成可服务性验证。

### Modified Capabilities

无。

## Impact

- 依赖与开发配置文件：`go.mod`、`go.sum`、`.air.toml`。
- 运行路径：`make dev-app` 启动的 Go 服务，以及 Milvus 客户端间接使用的 CPU/硬件信息探测。
- 兼容性：依赖升级保持既有 Go API，不涉及公开接口或持久化数据；若需回滚，可恢复原依赖版本，但 Apple Silicon 崩溃会随之恢复。
- 权限与数据：无用户数据、租户、RBAC、API Key 或秘密信息影响。

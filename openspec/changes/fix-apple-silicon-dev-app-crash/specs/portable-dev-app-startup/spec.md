## ADDED Requirements

### Requirement: Apple Silicon 启动阶段安全
本地 Go 应用在受支持的 Apple Silicon macOS 环境中通过 `make dev-app` 启动时 SHALL 不得因 CPU/硬件探测依赖的初始化而发生 `SIGSEGV`，且 SHALL 进入应用自身初始化流程。

#### Scenario: CPU 元数据缺失
- **WHEN** Apple Silicon 系统的 IOKit 未返回 CPU frequency 元数据
- **THEN** CPU 探测依赖安全处理缺失值，Go 进程不因空指针解引用而终止

#### Scenario: 依赖被 Milvus 间接加载
- **WHEN** 服务启动时加载包含 Milvus 客户端及其硬件信息依赖的包图
- **THEN** 进程完成 Go 包初始化并继续执行 WeKnora 的配置和容器初始化

### Requirement: 本地应用可服务性验证
Apple Silicon 启动兼容性修复 SHALL 通过相关模块测试、根模块验证和真实本地启动进行验证；真实启动 SHALL 确认服务完成监听并响应既有 HTTP 健康探测。

#### Scenario: 完整开发基础设施已就绪
- **WHEN** `make dev-start` 所需基础设施健康且开发者运行 `make dev-app`
- **THEN** 后端完成初始化、监听配置端口并对既有健康探测返回成功响应

#### Scenario: 修复保持现有契约
- **WHEN** 应用采用修复后的 CPU 探测依赖运行
- **THEN** REST、CLI、gRPC、数据库、鉴权、租户隔离和异步任务契约保持不变

### Requirement: Air 热重载配置兼容
本地开发配置 SHALL 为新版 Air 显式声明构建产物入口，并 SHALL 保持现有构建命令、临时产物路径和热重载行为不变。

#### Scenario: 本机已安装新版 Air
- **WHEN** 开发者通过 `make dev-app` 启动热重载模式
- **THEN** Air 使用显式 `build.entrypoint` 运行 `./tmp/main`，且不再输出仅配置 `build.bin` 的弃用提示

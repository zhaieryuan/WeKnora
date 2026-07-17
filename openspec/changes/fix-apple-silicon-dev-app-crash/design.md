## Context

根模块通过 Milvus Go 客户端间接依赖 `gopsutil/v3/cpu` 和 `github.com/shoenig/go-m1cpu@v0.1.6`。在当前 Apple Silicon macOS 主机上，`go-m1cpu@v0.1.6` 的包级 `init()` 会立即进入 C `initialize()`，当 IOKit 未返回预期的 CPU frequency `CFDataRef` 时继续解引用空指针，因此进程在 `main`、配置加载和日志初始化之前收到 `SIGSEGV`。

`go-m1cpu@v0.2.2` 保持 Go 访问器 API 兼容，同时把初始化改为 `sync.Once` 惰性执行，并在 C 层对缺失的 CoreFoundation 数据增加空值保护。当前仓库没有直接调用该模块；它只位于 Milvus 硬件信息采集依赖链中。

仓库的 `.air.toml` 只设置了旧的 `build.bin`。Air 1.65.3 仍能运行该配置，但启动时提示应改用 `build.entrypoint`；Air 当前生成的默认配置同时保留 `bin` 并显式设置 `entrypoint = ["./tmp/main"]`。

## Goals / Non-Goals

**Goals:**

- 消除 Apple Silicon macOS 上 `make dev-app` 的启动期 CPU 探测崩溃。
- 消除新版 Air 的 `build.bin` 弃用提示，同时保持现有热重载产物路径。
- 用最小依赖差异完成修复，并验证依赖图、相关包测试、根模块测试/静态检查和真实服务探活。
- 保持其他平台以及 Milvus 调用路径的编译兼容性。

**Non-Goals:**

- 不升级 Milvus、gopsutil 或其他无关依赖。
- 不改变应用业务代码、CPU 指标语义、REST/CLI/gRPC 契约、数据库 schema 或开发基础设施编排。
- 不处理与该崩溃栈无关的 Docker、模型凭据或业务配置问题。

## Decisions

1. **直接固定修复后的间接依赖版本。** 将 `github.com/shoenig/go-m1cpu` 从 `v0.1.6` 升到 `v0.2.2`，不添加 `replace`。这样 Go 模块最小版本选择会在整张依赖图中使用上游已发布修复，同时保留可追踪的标准模块语义。

   备选方案是整体升级 Milvus 或 gopsutil，但这会扩大 API、行为和依赖变更面，且并非修复当前空指针所必需；本次不采用。

2. **不在 WeKnora 中复制或绕过 CPU 探测实现。** 崩溃发生在第三方模块包初始化阶段，业务代码无法可靠捕获 `SIGSEGV`。使用上游的惰性初始化和 C 空值保护比在启动脚本中设置架构判断或禁用 CGO 更直接，也不会改变其他 CGO 依赖的构建方式。

3. **以真实可服务状态作为验收。** 除模块与 Go 测试外，在已启动完整开发基础设施的条件下运行 `make dev-app`，确认不再出现 `go-m1cpu` 崩溃、服务完成初始化并能通过本地 HTTP 健康探测；验证后停止测试进程，避免留下重复监听者。

4. **显式声明 Air 构建入口。** 在现有 `bin = "./tmp/main"` 旁增加 `entrypoint = ["./tmp/main"]`，与 Air 1.65.3 生成配置保持一致。保留 `bin` 以兼容仍读取该字段的 Air 版本，不修改构建命令、watch 范围或进程生命周期选项。

## Risks / Trade-offs

- [间接依赖被显式固定，未来上游可能选择其他版本] → 保留注释标明其 Apple Silicon 启动兼容性用途，并在后续 Milvus/gopsutil 升级时通过模块图重新评估是否仍需固定。
- [`v0.2.2` 调整 Apple 芯片频率探测和单位处理] → WeKnora 不直接消费该值；运行相关 Milvus 包测试、根模块测试和真实启动，验证间接调用兼容性。
- [上游 `go-m1cpu` 的 P/E-Core 频率阈值测试尚未适配当前 M5 Pro] → 直接运行上游测试确认 C 探测不再崩溃并记录频率断言失败；同时以通过的 gopsutil Apple Silicon、Milvus hardware 和 WeKnora Milvus retriever 测试验证实际依赖路径。Milvus 当前只使用 CPU 数量、占用率与时间，不消费 `Info().Mhz`，本 change 不复制上游实现或伪造缺失的 E-Core 频率。
- [真实启动可能暴露独立的配置或基础设施错误] → 依据日志继续区分并修复本地环境问题，但不把无关行为变更混入本 change。

## Migration Plan

1. 升级并固定单一模块版本，检查 `go.mod`/`go.sum` 只有预期差异。
2. 增加 Air 显式入口，运行模块、相关包和根模块验证，再运行真实启动探活并确认弃用提示消失。
3. 无数据迁移或服务端发布顺序要求。回滚时恢复旧版本与校验和；该操作会重新引入已知 Apple Silicon 崩溃，因此仅用于紧急依赖回退。

## Open Questions

无。崩溃栈、依赖链和上游修复差异均已在当前环境验证。

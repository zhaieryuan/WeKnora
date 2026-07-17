## 1. 依赖修复

- [x] 1.1 将根模块的 `github.com/shoenig/go-m1cpu` 固定到 `v0.2.2`，并更新对应校验和
- [x] 1.2 检查 `go.mod`、`go.sum` 和模块依赖链，确认没有无关依赖漂移
- [x] 1.3 为 `.air.toml` 增加显式 `build.entrypoint`，保持现有 `./tmp/main` 构建和运行路径

## 2. 兼容性与启动验证

- [x] 2.1 运行 `go-m1cpu`、gopsutil Apple Silicon、Milvus hardware 及 WeKnora Milvus retriever 测试；确认探测不再崩溃、实际依赖路径通过，并记录上游尚未适配 M5 的频率阈值断言
- [x] 2.2 运行根模块全量测试、静态检查和服务构建；`go vet` 与 arm64 服务构建通过，全量测试仅保留与本依赖无关的既有 SSRF 测试隔离失败（Notion 6 项、远程图片 2 项）
- [x] 2.3 在完整开发基础设施上运行 `make dev-app`，确认应用无 `SIGSEGV`、完成监听并通过既有 HTTP 健康探测
- [x] 2.4 重新运行 Air 热重载启动，确认 `build.bin` 弃用提示消失且 `/health` 仍成功

## 3. 规格与交付检查

- [x] 3.1 审阅最终 diff，运行 `openspec validate fix-apple-silicon-dev-app-crash` 并记录验证结果

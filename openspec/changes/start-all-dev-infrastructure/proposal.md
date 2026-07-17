## Why

`make dev-start` 当前只启动 PostgreSQL、Redis、DocReader 与 Langfuse，但本地后端默认会连接的 Neo4j 等基础设施处于可选 Profile 中。开发者按照现有快速启动文档启动后，容易在运行时才发现缺少容器或端口，无法获得可直接运行的完整本地环境。

## What Changes

- 将 `make dev-start` / `scripts/dev.sh start` 的默认基础设施 Profile 改为完整开发基础设施集。
- 保留 `odl-hybrid` 与 OpenSearch Dashboards 为显式按需服务，避免默认构建大型 Docling 镜像或启动仅供人工检视的界面。
- 使启动输出与开发文档准确列出默认服务、访问地址和可选服务边界。
- 为启动脚本增加回归验证，防止默认 Profile 再次遗漏后端依赖。

## Capabilities

### New Capabilities

- `complete-local-dev-environment`: `make dev-start` 提供与本地应用运行所需服务一致的完整基础设施基线，并清晰区分明确按需的服务。

### Modified Capabilities

- 无。

## Impact

- 受影响实现：`scripts/dev.sh`、`Makefile` 的帮助文本及开发文档。
- 受影响运行时：本地 Docker Compose Profile 选择、初次启动下载/资源占用及服务端口占用。
- 不影响生产 Compose、REST/gRPC/CLI 契约、数据库 schema、租户/RBAC 或外部凭据；已有 `.env` 的端口与认证变量继续由 Compose 使用。

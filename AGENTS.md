# AGENTS.md — WeKnora 开发工作手册

本手册是 Codex、Claude Code 等 AI 协作者在 WeKnora 仓库内工作的共同准则。它把项目的现有
架构、安全边界、验证方式和交付纪律整理为可执行规则；不是产品需求或替代设计文档。

WeKnora 是多租户的知识管理平台：Go 服务提供 REST API、异步文档处理与 Agent 能力，Vue 前端
提供 Web UI，Python DocReader 通过 gRPC 负责文档读取，另有独立的 Go SDK、CLI 与小程序。

---

## 1. 规则优先级与适用范围

按以下顺序处理冲突：

1. 用户的最新明确指令，以及安全、隐私与合规要求。
2. 已验证的当前代码、测试、运行时配置和外部协议。
3. 公开契约的权威来源：`docreader/proto/docreader.proto`（gRPC）、Swagger 注解和生成的
   `docs/swagger.{json,yaml}`（REST）、数据库迁移（已发布 schema）。
4. 本手册、领域设计文档和模块 README。

- 本文件覆盖仓库根目录及其子目录；更深层目录的 `AGENTS.md` 可以补充或收紧规则。
  `cli/AGENTS.md` 是 `cli/` 模块的专属手册，尤其是 CLI 输出、退出码和 AI 消费者协议，优先于
  本文件中的通用规则。
- 不得把文档、注释或历史提交当作当前事实。若它们与代码或测试冲突，先定位差异并同步修正；
  不允许让实现与文档静默分叉。
- 未从需求、现有契约、代码或测试确认的字段、默认值、权限、外部接口和业务规则都不得臆造。
  信息不足且会改变公开行为、安全边界或数据模型时，先向人类确认。

---

## 2. 开始任务前的工作门禁

### OpenSpec change-first（CRITICAL）

本仓库以 `openspec/` 的 `spec-driven` schema 管理所有开发型改动。**没有活动 OpenSpec change，
不允许修改或生成应用代码、测试、公开契约、数据库迁移、运行时配置或部署行为。** 单纯的拼写修正、
不改变行为的说明性文档修订，以及本手册/OpenSpec 治理文件本身的维护可例外；无法明确归类时，
一律先建 change。

1. 先运行 `openspec list --json` 检查活动 change；新需求以 `openspec new change <kebab-case-name>`
   创建 change，并按 OpenSpec 的 artifact 依赖顺序完成 proposal、design、specs、`tasks.md`。
2. 实现前必须运行 `openspec status --change <name> --json` 与
   `openspec instructions apply --change <name> --json`，完整阅读 `contextFiles` 指向的所有产物、
   本手册、适用子目录手册、领域文档、当前实现和相邻测试。未完成这些阅读和对 `tasks.md` 的核对，
   不得分析实现方案、修改代码或生成补丁。
3. 开始实现时，必须明确说明已阅读的文档、正在使用的 change 和本次受约束的关键边界。只实现当前
   `tasks.md` 中未完成且已确认的任务；不得自行扩需求、借机重构或把新发现的工作塞入代码。新增
   需求、设计变更或任务缺口先更新 OpenSpec 产物并验证其一致性。
4. 每完成一个有意义的里程碑，就运行该里程碑的格式化、静态检查和测试，并立即在 `tasks.md` 标记
   已完成任务。全部任务完成后运行 `openspec validate <name>`、进行自我 review 和完整 verify；
   必要的 delta specs 同步到主规格后才能 archive。

### 阅读、范围与诚信

修改前还必须完成以下核对：

1. 阅读本文件、相关目录的 `AGENTS.md`，并检查 `git status --short`；不覆盖、回退或混入他人
   未提交改动。
2. 阅读对应领域文档、路由/服务/仓储实现和相邻测试。仓库不存在单一的总设计文档，必须按任务读取
   第 11 节列出的开发、API、安全、异步、DocReader 等权威文档，而非只读 README。
3. 明确改动影响的边界：HTTP/MCP/CLI、前端、数据库、异步任务、DocReader gRPC、配置、权限、
   外部存储或向量库。跨边界时必须逐项核对契约。
4. 修改数据库、配置、鉴权、租户、数据删除、外部网络访问、模型调用或异步任务等高风险内容时，
   必须在 OpenSpec 设计和交付说明中写清影响范围、回滚/兼容策略及验证方式。

开发过程中坚持“先读再改、最小变更、每个里程碑验证”。完成前必须自查 diff，确认没有无关格式化、
生成物漂移、秘密信息或未说明的契约变化。

**Programming Conduct Rules：**

- 以暗猜接口为耻，以认真查阅为荣；以模糊执行为耻，以寻求确认为荣。
- 以盲想业务为耻，以人类确认为荣；以创造接口为耻，以复用现有为荣。
- 以跳过验证为耻，以主动测试为荣；以破坏架构为耻，以遵循规范为荣。
- 以假装理解为耻，以诚实无知为荣；以盲目修改为耻，以谨慎重构为荣。

---

## 3. 仓库地图与职责

```text
cmd/server/                         Go HTTP 服务启动入口
internal/router/                    Gin 路由、API Key 策略与异步 worker 注册
internal/handler/                   HTTP 参数绑定、响应和传输层适配
internal/application/service/       业务编排、事务边界、异步任务生产
internal/application/repository/    GORM/数据库持久化与检索仓储
internal/infrastructure/            DocReader、分块、网络读取/搜索等基础设施适配器
internal/middleware/                鉴权、RBAC、审计、错误处理和请求上下文
internal/container/                 dig 依赖装配与资源生命周期
internal/models/                    模型供应商、Embedding、Rerank、限流等能力
migrations/versioned/               PostgreSQL 的顺序版本化迁移
config/                             默认配置和 Prompt 模板
frontend/                           Vue 3 + TypeScript + Vite Web UI
docreader/                          Python 文档读取服务和 gRPC 协议实现
client/                             独立 Go SDK 模块
cli/                                独立 Go CLI 模块（受 cli/AGENTS.md 约束）
miniprogram/                        微信小程序
docs/                               开发、部署、API、安全与功能说明
```

分层规则：

- `handler/` 只处理 HTTP 输入输出、鉴权上下文和调用服务；业务编排不能复制到 Handler 或路由中。
- `application/service/` 承载业务用例、权限后的领域校验、事务与异步任务编排；不得把 HTTP/Gin
  细节向内层扩散。
- `application/repository/` 负责持久化查询；基础设施提供外部系统适配。服务层不应消费第三方 SDK
  的裸数据结构，必要时在适配器中归一化。
- `container/` 是依赖装配的唯一入口。新增可替换依赖、后台资源或服务时，必须在此注册并处理
  关闭生命周期；不要在 Handler 中临时构造共享客户端。
- 新 HTTP 端点通过 `internal/router/router.go` 注册，复用现有中间件、响应和错误模式。路由不能
  绕过鉴权、RBAC、审计或 API Key gate。

---

## 4. 不可突破的安全与租户边界

### 多租户、RBAC 与 API Key（CRITICAL）

- 身份、当前租户、角色和 API Key scope 必须来自认证中间件的可信请求上下文；禁止信任请求体、
  查询参数或缓存推断出的租户/用户身份，禁止用默认租户兜底。
- WeKnora 自己的 `tenants`、`users`、`tenant_members`、API Key、资源归属和角色矩阵是当前平台
  的权威状态；OIDC 是外部身份认证集成，不得擅自改造成 SSO 租户主数据镜像或另一套授权中心。
  身份与空间切换必须继续通过 `internal/middleware/Auth`、`TenantIDContextKey` 与现有服务解析。
- 所有资源读取、修改、任务创建和外部调用都必须维持 tenant 作用域。查询条件、缓存键、任务载荷
  与回调恢复路径不得遗漏 `tenant_id` 标识；跨租户“看不见”优先于泄露资源存在性。
- 严格沿用 `internal/router/router.go` 中的 `Viewer` / `Contributor` / `Admin` / `Owner` 及
  `Owned*OrAdmin` 守卫。资源归属、共享空间和跨租户超管均有既定模型，不能只在前端隐藏按钮。
- API Key 路径必须通过既有 `apiKeyGroup` / `apiKeyRoute` 声明所需 capability，由
  `APIKeyRouteAuthorizer` 默认拒绝未注册路径。新增、移动或改写路由时，必须同步检查 JWT、API Key
  与嵌入式访问三种调用者是否各自被正确授权。
- 权限拒绝、成员变化及其他受审计动作必须保留现有 audit 链路；不得把 RBAC 关闭或把 API Key
  视为绕过所有规则的万能开关。

### 机密、外部输入与可观测性（CRITICAL）

- 禁止提交或输出 API key、JWT、Cookie、密码、私钥、数据库连接串、真实租户数据或未经脱敏的
  请求/响应日志。以 `.env.example`、配置占位符和密钥引用描述配置；不得把本机 `.env` 写入仓库。
- URL 抓取、对象存储、MCP、模型和数据源凭据复用现有 SSRF 防护、allowlist、加密、脱敏和错误
  包装；不要另写无校验的 HTTP 客户端或把密钥写入日志、错误或前端状态。
- 传播 `context.Context`、请求 ID 和既有日志/追踪上下文。错误应含可行动的业务语义，但不能泄露
  机密、跨租户标识、内部 SQL 或上游原始响应。

---

## 5. 协议、数据和异步任务

### REST、前端与 CLI 契约

- REST API 的运行时权威参考是 Swagger；变更公开请求/响应、认证、状态码或路由时，同步更新
  Go Swagger 注解、`docs/api/` 的说明和前端调用，并运行 `make docs` 更新 `docs/swagger.*`。
- 不得在前端自行解释安全或业务状态来替代后端。前端应使用类型化 API 边界，处理加载、错误、
  权限拒绝和流式取消状态；用户可见的变更须同时验证对应后端契约。
- `/cli` 是独立 Go module。凡影响 CLI JSON/NDJSON、stderr、退出码、确认、重试、MCP 工具或
  `--dry-run` 的变更，必须完整遵守 `cli/AGENTS.md`，并更新相应 contract/acceptance 测试。

### 数据库和配置

- Schema 变更只能新增可审阅的 `migrations/versioned/` 成对迁移；不得编辑已应用迁移、手工改库或
  把生产数据修复藏进应用启动逻辑。使用 `make migrate-create name=<name>` 创建，并在适用环境验证
  `up` 与安全的 `down` 路径。
- 数据库规约以当前 PostgreSQL/GORM 与 Lite/SQLite 实现为准：表、列和索引沿用现有的小写
  `snake_case` 与既有复数表名；主键、`created_at`/`updated_at`/软删除、布尔列、精确数值、外键和
  `ON DELETE` 行为都必须与相邻模型和迁移保持一致，不能照搬 MySQL 规则或凭空添加/移除级联。
  所有 tenant 归属资源都必须持久化并查询 `tenant_id`，索引和唯一约束应把租户隔离纳入设计。
- 同时考虑标准版 PostgreSQL 与 Lite/SQLite 支持范围。若某能力不能兼容，必须显式设计隔离、
  降级和测试，不能让运行时悄然失败。
- 配置默认值放在 `config/`，部署差异走环境变量和 `.env.example`。变更配置键、默认值或启动行为时，
  同步配置说明、Docker/Helm/开发环境，并说明升级影响。

### 异步处理

- 文档解析、后处理、富化、维护和 Wiki 任务使用既有 Asynq 队列与任务接口；不要为常驻或可重试
  工作直接启动无生命周期管理的 goroutine。
- 选择 `default`、`postprocess`、`summary`/`multimodal`/`graph`/`question`、`sync`/`low`、`wiki`
  等队列时遵守 `docs/worker-pool-governance.md` 的阶段隔离和容量模型。worker 数不是模型、DocReader、
  向量库或数据库配额的替代品。
- 任务应可安全重试、可追踪、带完整租户与资源上下文；新增副作用必须明确幂等策略、失败状态、
  取消和死信处理。

### DocReader gRPC

- `docreader/proto/docreader.proto` 是唯一协议源。修改字段或 RPC 必须遵守 protobuf 兼容性：不复用
  已发布字段号，删除字段时 `reserved`，并评估滚动发布的前后端兼容性。
- 修改 proto 后运行 `cd docreader && make proto`，审阅并提交必要的 Python 与 Go 生成代码，然后同步
  `docreader/` 服务、`internal/infrastructure/docparser/` 客户端、TLS/token 行为和跨进程测试。
- 不把图像、文件或第三方 URL 的可信性假设从 Python 端泄漏到 Go 端；两端都必须保持大小限制、
  鉴权、错误语义和资源清理。

---

## 6. 编码与文档规范

### Go

- 根模块要求 Go `1.26.0`；保持 `go.mod` / `go.sum` 最小且有意图。不要在无需求时升级大量依赖。
- 格式化使用 `gofmt` / `gofumpt`；质量基线受 `.golangci.yml` 约束（`govet`、`revive`、行宽 120）。
- 使用清晰的领域命名和小而内聚的函数。导出包、类型、函数、配置项和非显而易见的安全/并发/业务
  分支必须有准确中文说明，解释目的、输入输出、约束和副作用，而不是重复名称。
- 新增或修改的模块、类型、对象字段、常量、配置项、函数和方法都必须补齐准确中文说明；说明至少
  覆盖用途、业务语义、输入输出、约束，以及必要的错误、副作用和租户边界。缺失、过时、含糊或
  与实现不一致的说明都视为未完成，禁止用名称翻译或无信息量注释充数。
- 传递 `context.Context`，及时关闭连接、流、文件和取消函数；显式处理错误。不要吞错、panic 处理
  普通输入错误，或以字符串包含/关键词命中伪造领域判断与权限决策。业务语义、流程路由和结论必须
  基于 OpenSpec、领域模型、结构化字段、明确规则或经验证的算法；禁止硬编码关键词表、字符串包含、
  正则命中或同义词枚举替代业务设计。

### TypeScript / Vue 与 Python

- 前端保持 Vue 3 Composition API、TypeScript 类型约束和现有 Pinia/i18n/API 封装；不得通过
  `any`、禁用类型检查或仅前端鉴权规避契约问题。HTML/Markdown/外部链接输出必须复用现有净化和
  安全跳转机制。
- DocReader 使用其 `pyproject.toml` / `uv.lock` 锁定的环境，保持类型、异常和资源管理一致。新增或
  修改公开 Python 类、函数、配置和协议字段同样需要准确中文说明。
- 只改动所触及模块的 lockfile。不要提交 `node_modules`、`.venv`、临时构建产物、测试数据 dump 或
  本地 IDE 文件。

---

## 7. 本地开发与验证

日常开发推荐先启动依赖，再分别启动本地后端和前端：

```bash
make dev-start       # PostgreSQL、Redis、MinIO、Neo4j、DocReader 等依赖
make dev-app         # 本地 Go 服务（检测到 Air 时可热重载）
make dev-frontend    # Vite 开发服务器
make dev-status
make dev-stop
```

按变更范围运行最小充分验证，并在提交前尽可能扩展到模块级完整检查：

```bash
# 根 Go 服务
go test -count=1 ./...
go vet ./...
make fmt
make lint

# 前端（在 frontend/）
npm ci
npm run type-check
npm test
npm run build

# CLI（在 cli/，还须遵守 cli/AGENTS.md）
go test -count=1 ./...
go vet ./...

# 小程序
npm --prefix miniprogram test

# Swagger / 数据库 / proto 仅在相关变更时
make docs
make migrate-up
(cd docreader && make proto)

# OpenSpec（所有开发型改动的门禁）
openspec status --change <name> --json
openspec validate <name>
```

- 先跑直接受影响的测试，再跑该模块全量测试；公开 API、权限、任务、迁移、协议和安全改动必须补齐
  回归测试，至少覆盖成功、拒绝/越权、错误和关键兼容路径。
- DocReader 没有统一的根级测试命令时，使用 `uv` 锁定环境运行相关 `docreader/tests` 或回归脚本，
  并在交付说明中列出实际执行的命令与未执行原因。
- 集成测试若依赖 Docker、模型供应商或真实凭据，先明确前置条件。缺少环境时不得伪称通过，应报告
  已验证的替代证据和仍待验证的边界。

当前已安装的工作流工具为 OpenSpec 1.6.0、Go 1.26、`golangci-lint` 2.12.2、`gofumpt` 0.10.0、
`swag` 1.16.4、Node/npm、uv、protoc 及 Go gRPC 生成器。缺少 Go 质量工具时直接安装到
`$(go env GOPATH)/bin`：

```bash
go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@latest
go install mvdan.cc/gofumpt@latest
go install github.com/swaggo/swag/cmd/swag@latest
```

---

## 8. 提交、评审与交付

- 使用 Conventional Commits：`feat`、`fix`、`refactor`、`docs`、`test`、`chore`、`perf`、`ci`。
- 每个提交只承载一个可说明、可验证的意图。不要把用户已有的未提交修改纳入暂存或提交，除非用户
  明确要求。
- 交付/PR 至少写明：变更目的和路径、数据/权限/API 兼容性、迁移或配置影响、执行的验证和结果、
  未验证项及原因。用户可见 UI 变化附截图或录屏。
- 修改实现后必须同步相关文档、Swagger、示例、测试和生成物；破坏性变更要提供迁移或兼容方案，
  并在变更说明中明确标注。

---

## 9. 常见反模式

- 在 Handler、Vue 页面或路由里复制服务层业务逻辑。
- 无活动 OpenSpec change 直接修改实现，未读 `contextFiles`/`tasks.md` 就开始设计或补丁，或绕过
  `tasks.md` 擅自扩大范围。
- 只在 UI 隐藏按钮，或新路由忘记 API Key policy / RBAC ownership guard。
- 把 tenant、用户、资源归属或 API Key scope 从不可信输入带入数据访问、缓存或后台任务。
- 修改已发布迁移、重用 protobuf 字段号、手工编辑生成文件却未更新源协议。
- 用裸 goroutine 绕过 Asynq 的队列、重试和生命周期治理。
- 用硬编码关键词、正则或字符串包含代替领域模型、结构化字段和明确规则。
- 为了“让测试绿”而吞错、取消安全检查、放宽跨租户查询、跳过类型检查或删除回归测试。
- 运行后把 `.env`、令牌、真实对象 URL、数据库输出或敏感日志复制到代码、文档、issue 或测试 fixture。

---

## 10. 开发前后检查清单

### 修改前

- [ ] 已阅读本手册、适用子目录手册、领域文档、实现和相邻测试。
- [ ] 已确认活动 OpenSpec change，阅读 `openspec instructions apply` 的全部 `contextFiles`，并核对
  `tasks.md`；开始实现时已说明 change、已读文档和关键约束。
- [ ] 已确认任务范围、现有工作树改动和跨模块契约影响。
- [ ] 已确认身份、租户、RBAC、API Key、审计和外部输入边界不被绕过。

### 修改后

- [ ] 已进行最小化 diff 自检，未引入无关改动或敏感信息。
- [ ] 已补充/更新实现注释、测试、Swagger/文档/生成物和配置说明。
- [ ] 已运行与改动相称的格式化、静态检查、测试和必要的集成验证。
- [ ] 已逐项标记 `tasks.md`，运行 `openspec validate <name>`，完成自我 review 和完整 verify。
- [ ] 已记录数据迁移、配置、兼容性、部署与未验证风险。

---

## 11. 关键参考

- 开发与本地启动：`docs/开发指南.md`、`docs/快速开发模式说明.md`、`Makefile`
- API 与 Swagger：`docs/api/README.md`、`cmd/server/main.go`、`internal/router/router.go`
- 认证、空间和权限：`docs/OIDC认证调用流程.md`、`docs/RBAC说明.md`、`docs/共享空间说明.md`、
  `internal/middleware/`
- 异步任务：`docs/worker-pool-governance.md`、`internal/router/`、`internal/application/service/`
- 数据源、MCP、Agent 与安全：`docs/数据源导入开发文档.md`、`docs/MCP功能使用说明.md`、
  `docs/agent-skills.md`、`docs/embed-secure-mode.md`
- DocReader：`docreader/README.md`、`docreader/proto/docreader.proto`、
  `docreader/scripts/generate_proto.sh`、`internal/infrastructure/docparser/`
- CLI：`cli/AGENTS.md`、`cli/README.md`

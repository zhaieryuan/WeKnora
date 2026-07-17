# 在仓库根目录
cp .env.example .env   # 若 .env 已存在，跳过；按需填写模型/外部服务配置

# 终端 1：启动 Docker 基础设施
make dev-start

# 终端 2：启动本地 Go 后端
make dev-app

# 终端 3：启动本地 Vue 前端
make dev-frontend

# 终端 1：启动 Docker 基础设施
make dev-start

# 终端 2：启动本地 Go 后端
make dev-app

# 终端 3：启动本地 Vue 前端
make dev-frontend
启动后访问：
前端：http://localhost:5173
后端 API：http://localhost:8080
常用命令：
make dev-status  # 查看基础设施状态
make dev-logs    # 查看基础设施日志
make dev-stop    # 停止开发环境
前置条件：Docker Desktop 已启动、安装 Go 和 Node/npm。make dev-frontend 首次会自动安装前端依赖。
注意：当前 make dev-start 默认只启动 PostgreSQL、Redis、DocReader 和 Langfuse；若开发功能需要对象存储、图数据库等，可按需启动：
make dev-start DEV_ARGS="--minio --neo4j"
# 或全部可选基础设施
make dev-start DEV_ARGS=--full
若只是体验完整 Docker 版本而不改代码：
docker compose up -d
然后访问 http://localhost 。
#!/bin/bash
# 开发环境启动脚本 - 只启动基础设施，app 和 frontend 需要手动在本地运行

# 设置颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 获取项目根目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# 日志函数
log_info() {
    printf "%b\n" "${BLUE}[INFO]${NC} $1"
}

log_success() {
    printf "%b\n" "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    printf "%b\n" "${RED}[ERROR]${NC} $1"
}

log_warning() {
    printf "%b\n" "${YELLOW}[WARNING]${NC} $1"
}

# 选择可用的 Docker Compose 命令
DOCKER_COMPOSE_BIN=""
DOCKER_COMPOSE_SUBCMD=""

detect_compose_cmd() {
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE_BIN="docker"
        DOCKER_COMPOSE_SUBCMD="compose"
        return 0
    fi
    if command -v docker-compose &> /dev/null; then
        if docker-compose version &> /dev/null; then
            DOCKER_COMPOSE_BIN="docker-compose"
            DOCKER_COMPOSE_SUBCMD=""
            return 0
        fi
    fi
    return 1
}

# 完整开发环境依赖 Compose 的 --wait/--wait-timeout 语义，确保长驻服务退出或
# 健康检查失败时不会继续输出“启动成功”。旧版 Compose 缺少该能力时应明确失败。
compose_supports_wait() {
    local up_help
    up_help=$("$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD up --help 2>&1) || return 1
    printf '%s\n' "$up_help" | grep -q -- '--wait' &&
        printf '%s\n' "$up_help" | grep -q -- '--wait-timeout'
}

# 显示帮助信息
show_help() {
    printf "%b\n" "${GREEN}WeKnora 开发环境脚本${NC}"
    echo "用法: $0 [命令] [选项]"
    echo ""
    echo "命令:"
    echo "  start      启动完整开发基础设施（默认不含按需服务）"
    echo "  stop       停止所有服务"
    echo "  restart    重启所有服务"
    echo "  logs       查看服务日志"
    echo "  status     查看服务状态"
    echo "  app        启动后端应用（本地运行）"
    echo "  frontend   启动前端开发服务器（本地运行）"
    echo "  help       显示此帮助信息"
    echo ""
    echo "默认基础设施: postgres、redis、docreader、searxng、minio、qdrant、opensearch、milvus、neo4j、dex、langfuse"
    echo ""
    echo "可选参数（用于 start 命令）:"
    echo "  --no-langfuse    不启动 Langfuse，其余完整基础设施保持启动"
    echo "  --odl-hybrid     启动 OpenDataLoader hybrid（Docling，镜像较大，按需启用）"
    echo "  --opensearch-ui  启动 OpenSearch Dashboards（仅索引检视界面，按需启用）"
    echo "  --full           与默认基础设施相同（兼容已有调用）"
    echo "  DEV_START_WAIT_SEC 可在 .env 中设置就绪等待秒数（正整数，默认 180）"
    echo ""
    echo "示例："
    echo "  $0 start                         # 启动完整开发基础设施"
    echo "  $0 start --no-langfuse            # 启动不含 Langfuse 的完整基础设施"
    echo "  $0 start --odl-hybrid             # 完整基础设施 + OpenDataLoader hybrid"
    echo "  $0 start --opensearch-ui          # 完整基础设施 + OpenSearch Dashboards"
    echo "  make dev-start DEV_ARGS=--odl-hybrid  # 同上（Makefile 传参）"
    echo "  $0 app                      # 在另一个终端启动后端"
    echo "  $0 frontend                 # 在另一个终端启动前端"
}

# 加载 .env 与可选的 .env.local（后者覆盖前者）
load_env_files() {
    if [ -f ".env" ]; then
        set -a
        # shellcheck source=/dev/null
        source .env
        set +a
    else
        return 1
    fi

    if [ -f ".env.local" ]; then
        log_info "加载 .env.local 覆盖配置..."
        set -a
        # shellcheck source=/dev/null
        source .env.local
        set +a
    fi
    return 0
}

# 检查 Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "未安装Docker，请先安装Docker"
        return 1
    fi
    
    if ! detect_compose_cmd; then
        log_error "未检测到 Docker Compose"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行"
        return 1
    fi
    
    return 0
}

# 检查 .env 是否启用了 hybrid 模式（用于 --odl-hybrid 启动后重建 docreader）
_should_enable_odl_hybrid_from_env() {
    local hybrid="${DOCREADER_ODL_HYBRID:-off}"
    hybrid=$(printf '%s' "$hybrid" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')
    case "$hybrid" in
        off|"") return 1 ;;
        *) return 0 ;;
    esac
}

_enable_odl_hybrid_profile() {
    ENABLE_ODL_HYBRID=true
}

# 等待 odl-hybrid HTTP 健康检查通过（compose 启动后服务可能仍在拉依赖）
_wait_odl_hybrid_ready() {
    local port="${ODL_HYBRID_PORT:-5002}"
    local max_wait="${ODL_HYBRID_STARTUP_WAIT_SEC:-180}"
    local waited=0
    local interval=5

    if ! command -v curl &> /dev/null; then
        log_warning "未安装 curl，跳过 odl-hybrid 就绪等待；请手动检查 http://localhost:${port}/health"
        return 0
    fi

    log_info "等待 odl-hybrid 就绪（最多 ${max_wait}s，首次需构建镜像: docker compose ... build odl-hybrid）..."
    while [ "$waited" -lt "$max_wait" ]; do
        if curl -sf "http://127.0.0.1:${port}/health" >/dev/null 2>&1; then
            log_success "odl-hybrid 已就绪 (http://localhost:${port}/health)"
            return 0
        fi
        sleep "$interval"
        waited=$((waited + interval))
    done
    log_warning "odl-hybrid 在 ${max_wait}s 内未就绪，请查看: docker logs WeKnora-odl-hybrid"
    return 1
}

# 启动基础设施服务
start_services() {
    log_info "启动开发环境基础设施服务..."
    
    check_docker
    if [ $? -ne 0 ]; then
        return 1
    fi

    cd "$PROJECT_ROOT"
    
    # 检查 .env 文件
    if [ ! -f ".env" ]; then
        log_error ".env 文件不存在，请先创建"
        return 1
    fi

    load_env_files
    if [ $? -ne 0 ]; then
        log_error ".env 文件不存在，请先创建"
        return 1
    fi

    if [ -n "${DEV_REMOTE_HOST:-}" ]; then
        log_warning "已配置 DEV_REMOTE_HOST=${DEV_REMOTE_HOST}，跳过本地 Docker 基础设施启动"
        log_info "远程服务: PostgreSQL/Redis/DocReader/Langfuse → ${DEV_REMOTE_HOST}"
        log_info "接下来: make dev-app（本地后端）或 make dev-frontend（前端）"
        return 0
    fi

    # DEV_START_WAIT_SEC 只接受正整数。显式配置为空也视为错误，避免 Compose
    # 收到无效超时后以难以定位的参数错误退出。
    local start_wait_sec
    if [ "${DEV_START_WAIT_SEC+x}" = "x" ]; then
        start_wait_sec="$DEV_START_WAIT_SEC"
    else
        start_wait_sec=180
    fi
    case "$start_wait_sec" in
        ''|*[!0-9]*)
            log_error "DEV_START_WAIT_SEC 必须是正整数（秒），当前值无效"
            return 1
            ;;
    esac
    if [ "$start_wait_sec" -le 0 ]; then
        log_error "DEV_START_WAIT_SEC 必须大于 0（秒）"
        return 1
    fi

    if ! compose_supports_wait; then
        log_error "当前 Docker Compose 不支持 up --wait/--wait-timeout，请升级 Docker Compose 后重试"
        return 1
    fi
    
    # 解析 profile 参数。完整开发基线由 Compose 的 full profile 定义，避免脚本和
    # docker-compose.dev.yml 分别维护服务列表而再次发生遗漏。
    shift  # 移除 "start" 命令本身
    PROFILES="--profile full"
    ENABLED_SERVICES="searxng minio qdrant opensearch milvus neo4j dex langfuse sandbox"
    EXCLUDE_LANGFUSE=false
    ENABLE_ODL_HYBRID=false
    ENABLE_OPENSEARCH_UI=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --minio|--qdrant|--neo4j|--dex)
                # 这些服务已属于完整默认基线；保留旧参数以兼容已有调用。
                ;;
            --langfuse)
                EXCLUDE_LANGFUSE=false
                ;;
            --no-langfuse)
                EXCLUDE_LANGFUSE=true
                ;;
            --odl-hybrid)
                _enable_odl_hybrid_profile
                ;;
            --opensearch-ui)
                ENABLE_OPENSEARCH_UI=true
                ;;
            --full)
                # 默认已使用 full；保留参数以兼容已有调用。
                ;;
            *)
                log_warning "未知参数: $1"
                ;;
        esac
        shift
    done

    # Compose profile 是叠加关系，无法从 full 中移除 Langfuse。因此 opt-out 时
    # 显式选择 full 所含的非 Langfuse 服务；postgres、redis 与 docreader 无 profile，
    # 无论何种选择都会保留。
    if [ "$EXCLUDE_LANGFUSE" = true ]; then
        PROFILES="--profile searxng --profile minio --profile qdrant --profile opensearch --profile milvus --profile neo4j --profile dex"
        ENABLED_SERVICES="searxng minio qdrant opensearch milvus neo4j dex"
    fi
    if [ "$ENABLE_ODL_HYBRID" = true ]; then
        PROFILES="$PROFILES --profile odl-hybrid"
        ENABLED_SERVICES="$ENABLED_SERVICES odl-hybrid"
    fi
    if [ "$ENABLE_OPENSEARCH_UI" = true ]; then
        PROFILES="$PROFILES --profile opensearch-ui"
        ENABLED_SERVICES="$ENABLED_SERVICES opensearch-ui"
    fi

    # 长驻服务目标始终从 Compose 的已选 profile 动态解析，避免在脚本中复制 full
    # 服务清单。三个一次性任务不作为 --wait 的顶层目标；其中两个 init 会由依赖
    # 自动启动，sandbox 则在下方单独运行并核验真实退出码。
    local selected_services
    local wait_services
    selected_services=$("$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD -f docker-compose.dev.yml $PROFILES config --services)
    local compose_rc=$?
    if [ "$compose_rc" -eq 0 ]; then
        wait_services=$(printf '%s\n' "$selected_services" | grep -Ev '^(sandbox|searxng-init|langfuse-db-init)$' | tr '\n' ' ')
        if [ -z "$wait_services" ]; then
            log_error "未解析到需要启动的长驻开发服务"
            compose_rc=1
        fi
    fi

    # sandbox 是镜像准备任务，不是长驻依赖。Compose --wait 会把顶层 Exited (0)
    # 视为失败，因此单独启动并通过 docker wait 校验它是否真正成功完成。
    if [ "$compose_rc" -eq 0 ] && printf '%s\n' "$selected_services" | grep -qx 'sandbox'; then
        "$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD -f docker-compose.dev.yml $PROFILES up -d sandbox
        compose_rc=$?
        if [ "$compose_rc" -eq 0 ]; then
            local sandbox_id
            local sandbox_exit
            sandbox_id=$("$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD -f docker-compose.dev.yml $PROFILES ps -aq sandbox | tail -n 1)
            if [ -z "$sandbox_id" ]; then
                log_error "sandbox 镜像准备任务未创建容器"
                compose_rc=1
            else
                sandbox_exit=$(docker wait "$sandbox_id")
                compose_rc=$?
                if [ "$compose_rc" -eq 0 ] && [ "$sandbox_exit" != "0" ]; then
                    log_error "sandbox 镜像准备任务失败（退出码 ${sandbox_exit}）"
                    compose_rc=1
                fi
            fi
        fi
    fi

    # 等待 Compose 认可全部长驻服务的运行/健康状态。依赖型 init 成功退出由
    # Compose 视为完成；任何非零退出、unhealthy 或超时都会返回失败。
    # odl-hybrid 后续仍单独 --build，避免每次重建 docreader。
    if [ "$compose_rc" -eq 0 ]; then
        "$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD -f docker-compose.dev.yml $PROFILES \
            up -d --wait --wait-timeout "$start_wait_sec" $wait_services
        compose_rc=$?
    fi
    if [ "$compose_rc" -eq 0 ] && [[ "$ENABLED_SERVICES" == *"odl-hybrid"* ]]; then
        log_info "构建/更新 odl-hybrid 镜像..."
        "$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD -f docker-compose.dev.yml $PROFILES up -d --build odl-hybrid
        compose_rc=$?
        if [ "$compose_rc" -eq 0 ]; then
            _wait_odl_hybrid_ready
            compose_rc=$?
        fi
        # docreader 需读取 DOCREADER_ODL_HYBRID；若刚改 .env，强制重建以注入环境变量
        if [ "$compose_rc" -eq 0 ] && _should_enable_odl_hybrid_from_env; then
            log_info "重建 docreader 以应用 DOCREADER_ODL_HYBRID=${DOCREADER_ODL_HYBRID} ..."
            "$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD -f docker-compose.dev.yml \
                up -d --force-recreate --wait --wait-timeout "$start_wait_sec" docreader
            compose_rc=$?
        fi
    fi

    if [ "$compose_rc" -eq 0 ]; then
        log_success "基础设施服务已启动"
        echo ""
        log_info "服务访问地址:"
        echo "  - PostgreSQL:    localhost:5432"
        echo "  - Redis:         localhost:6379"
        echo "  - DocReader:     localhost:50051"
        
        # 根据启用的 profile 显示额外服务
        if [[ "$ENABLED_SERVICES" == *"minio"* ]]; then
            echo "  - MinIO:         localhost:9000 (Console: localhost:9001)"
        fi
        if [[ "$ENABLED_SERVICES" == *"qdrant"* ]]; then
            echo "  - Qdrant:        localhost:6333 (gRPC: localhost:6334)"
        fi
        if [[ "$ENABLED_SERVICES" == *"opensearch"* ]]; then
            echo "  - OpenSearch:    http://localhost:9200"
        fi
        if [[ "$ENABLED_SERVICES" == *"opensearch-ui"* ]]; then
            echo "  - OpenSearch UI: http://localhost:5601"
        fi
        if [[ "$ENABLED_SERVICES" == *"milvus"* ]]; then
            echo "  - Milvus:        localhost:19530 (health: localhost:9091)"
        fi
        if [[ "$ENABLED_SERVICES" == *"neo4j"* ]]; then
            echo "  - Neo4j:         localhost:7474 (Bolt: localhost:7687)"
        fi
        if [[ "$ENABLED_SERVICES" == *"dex"* ]]; then
            echo "  - Dex:           localhost:5556"
        fi
        if [[ "$ENABLED_SERVICES" == *"langfuse"* ]]; then
            echo "  - Langfuse:      http://localhost:${LANGFUSE_WEB_PORT:-3000}"
        fi
        if [[ "$ENABLED_SERVICES" == *"odl-hybrid"* ]]; then
            echo "  - ODL Hybrid:    http://localhost:${ODL_HYBRID_PORT:-5002} (health: /health)"
            echo "                   docreader 需 DOCREADER_ODL_HYBRID=docling-fast"
        fi
        echo ""
        log_info "按需服务: --odl-hybrid（Docling 镜像构建）和 --opensearch-ui（索引检视界面）"
        
        echo ""
        log_info "接下来的步骤:"
        printf "%b\n" "${YELLOW}1. 在新终端运行后端:${NC} make dev-app"
        printf "%b\n" "${YELLOW}2. 在新终端运行前端:${NC} make dev-frontend"
        return 0
    else
        log_error "服务启动或就绪检查失败（超时 ${start_wait_sec}s）"
        "$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD -f docker-compose.dev.yml $PROFILES ps -a || true
        return 1
    fi
}

# 停止服务
stop_services() {
    log_info "停止开发环境服务..."
    
    check_docker
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    # wildcard profile 覆盖 full、Langfuse 与所有按需服务；不传 --volumes，保留
    # 开发数据。--remove-orphans 用于清理旧配置遗留的同项目容器。
    "$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD -f docker-compose.dev.yml --profile '*' down --remove-orphans
    local compose_rc=$?
    if [ "$compose_rc" -ne 0 ]; then
        log_error "服务停止失败"
        return 1
    fi

    local remaining_containers
    remaining_containers=$("$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD -f docker-compose.dev.yml --profile '*' ps -aq)
    if [ -n "$remaining_containers" ]; then
        log_error "服务停止不完整，仍有 WeKnora 开发容器残留"
        "$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD -f docker-compose.dev.yml --profile '*' ps -a || true
        return 1
    fi

    log_success "所有服务已停止"
    return 0
}

# 重启服务
restart_services() {
    stop_services || return 1
    sleep 2
    start_services start
}

# 查看日志
show_logs() {
    check_docker
    if [ $? -ne 0 ]; then
        return 1
    fi

    cd "$PROJECT_ROOT"
    "$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD -f docker-compose.dev.yml logs -f
}

# 查看状态
show_status() {
    check_docker
    if [ $? -ne 0 ]; then
        return 1
    fi

    cd "$PROJECT_ROOT"
    "$DOCKER_COMPOSE_BIN" $DOCKER_COMPOSE_SUBCMD -f docker-compose.dev.yml ps
}

# 远程开发模式下检查基础设施端口是否可达
check_remote_dev_connectivity() {
    local host="${DEV_REMOTE_HOST:-}"
    if [ -z "$host" ]; then
        return 0
    fi

    local db_port="${DB_PORT:-5432}"
    local redis_port
    redis_port="${REDIS_ADDR#*:}"
    if [ "$redis_port" = "$REDIS_ADDR" ]; then
        redis_port=6379
    fi
    local docreader_port="${DOCREADER_PORT:-50051}"

    log_info "检查远程基础设施连通性 (${host})..."
    local failed=0
    for spec in "PostgreSQL:${host}:${db_port}" "Redis:${host}:${redis_port}" "DocReader:${host}:${docreader_port}"; do
        local name="${spec%%:*}"
        local rest="${spec#*:}"
        local h="${rest%%:*}"
        local p="${rest##*:}"
        if command -v nc &> /dev/null; then
            if nc -z -G 3 "$h" "$p" 2>/dev/null; then
                log_success "${name} ${h}:${p} 可达"
            else
                log_error "${name} ${h}:${p} 不可达 (no route / connection refused)"
                failed=1
            fi
        else
            log_warning "未安装 nc，跳过 ${name} 连通性检查"
        fi
    done

    if [ "$failed" -ne 0 ]; then
        echo ""
        log_error "无法连接远程开发环境 ${host}"
        log_info "排查建议:"
        echo "  1. 确认远程机器 Docker 容器在运行 (postgres/redis/docreader)"
        echo "  2. 确认本机与 ${host} 在同一局域网 (本机: $(ipconfig getifaddr en0 2>/dev/null || echo '未知'))"
        echo "  3. 在远程检查端口映射: docker ps --format 'table {{.Names}}\t{{.Ports}}'"
        echo "  4. 检查远程防火墙是否放行 5432/6379/50051"
        return 1
    fi
    return 0
}

# 启动后端应用（本地）
start_app() {
    log_info "启动后端应用（本地开发模式）..."
    
    cd "$PROJECT_ROOT"
    
    # 检查 Go 是否安装
    if ! command -v go &> /dev/null; then
        log_error "Go 未安装"
        return 1
    fi
    
    log_info "加载环境配置..."
    if ! load_env_files; then
        log_error ".env 文件不存在，请先创建配置文件"
        return 1
    fi
    
    # 本地 docker-compose.dev 模式：把容器服务名映射到 localhost
    # 远程开发模式（DEV_REMOTE_HOST 或 .env.local 已设地址）则保留 .env/.env.local 中的值
    if [ -n "${DEV_REMOTE_HOST:-}" ]; then
        log_info "远程开发模式: 基础设施 → ${DEV_REMOTE_HOST}"
        export DB_HOST="${DB_HOST:-$DEV_REMOTE_HOST}"
        export REDIS_ADDR="${REDIS_ADDR:-$DEV_REMOTE_HOST:6379}"
        export DOCREADER_ADDR="${DOCREADER_ADDR:-$DEV_REMOTE_HOST:50051}"
        export MINIO_ENDPOINT="${MINIO_ENDPOINT:-$DEV_REMOTE_HOST:9000}"
        export MILVUS_ADDRESS="${MILVUS_ADDRESS:-$DEV_REMOTE_HOST:19530}"
        export NEO4J_URI="${NEO4J_URI:-bolt://$DEV_REMOTE_HOST:7687}"
        export QDRANT_HOST="${QDRANT_HOST:-$DEV_REMOTE_HOST}"
        if [ -z "${LANGFUSE_HOST:-}" ] || [ "$LANGFUSE_HOST" = "http://langfuse-web:3000" ]; then
            export LANGFUSE_HOST="http://${DEV_REMOTE_HOST}:3000"
        fi
    else
        export DB_HOST=localhost
        export DOCREADER_ADDR=localhost:50051
        export MINIO_ENDPOINT=localhost:9000
        export REDIS_ADDR=localhost:6379
        export MILVUS_ADDRESS=localhost:19530
        export NEO4J_URI=bolt://localhost:7687
        export QDRANT_HOST=localhost
    fi
    export DOCREADER_TRANSPORT="${DOCREADER_TRANSPORT:-grpc}"

    if ! check_remote_dev_connectivity; then
        return 1
    fi

    # .env.example uses /data/files for the Docker app container, where a
    # volume is mounted at that path. When the backend runs directly on the
    # host via dev-app, /data is often read-only or missing, so use a repo-local
    # writable directory unless the developer explicitly configured another
    # local storage path.
    if [ -z "${LOCAL_STORAGE_BASE_DIR:-}" ] || [ "$LOCAL_STORAGE_BASE_DIR" = "/data/files" ]; then
        export LOCAL_STORAGE_BASE_DIR="$PROJECT_ROOT/.local-data/files"
    fi
    mkdir -p "$LOCAL_STORAGE_BASE_DIR"
    
    # 确保必要的环境变量已设置
    if [ -z "$DB_DRIVER" ]; then
        log_error "DB_DRIVER 环境变量未设置，请检查 .env 文件"
        return 1
    fi
    
    log_info "环境变量已设置，启动应用..."
    log_info "数据库地址: $DB_HOST:${DB_PORT:-5432}"
    
    export CGO_CFLAGS="-Wno-deprecated-declarations -Wno-gnu-folding-constant"
    if [[ "$(uname)" == "Darwin" ]]; then
      export CGO_LDFLAGS="-Wl,-no_warn_duplicate_libraries"
    fi

    # 检查是否安装了 Air（热重载工具）
    if command -v air &> /dev/null; then
        log_success "检测到 Air，使用热重载模式启动..."
        log_info "修改 Go 代码后将自动重新编译和重启"
        air
    else
        log_info "未检测到 Air，使用普通模式启动"
        log_warning "提示: 安装 Air 可以实现代码修改后自动重启"
        log_info "安装命令: go install github.com/air-verse/air@latest"
        LDFLAGS="$(./scripts/get_version.sh ldflags) -X 'google.golang.org/protobuf/reflect/protoregistry.conflictPolicy=warn'"
        go run -ldflags="$LDFLAGS" ./cmd/server
    fi
}

# 启动前端（本地）
start_frontend() {
    log_info "启动前端开发服务器..."

    cd "$PROJECT_ROOT"
    if [ -f ".env" ] || [ -f ".env.local" ]; then
        load_env_files >/dev/null 2>&1 || true
    fi
    
    cd "$PROJECT_ROOT/frontend"
    
    # 检查 npm 是否安装
    if ! command -v npm &> /dev/null; then
        log_error "npm 未安装"
        return 1
    fi
    
    # 检查依赖是否已安装
    if [ ! -d "node_modules" ]; then
        log_warning "node_modules 不存在，正在安装依赖..."
        npm install
    fi
    
    log_info "启动 Vite 开发服务器..."
    log_info "前端将运行在 http://localhost:5173"
    log_info "前端 API 代理目标: ${VITE_DEV_PROXY_TARGET:-${FRONTEND_BACKEND_URL:-http://localhost:8080}}"
    
    # 运行开发服务器
    npm run dev
}

# 解析命令
CMD="${1:-help}"
case "$CMD" in
    start)
        start_services "$@"
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    logs)
        show_logs
        ;;
    status)
        show_status
        ;;
    app)
        start_app
        ;;
    frontend)
        start_frontend
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "未知命令: $CMD"
        show_help
        exit 1
        ;;
esac

# 保留所选命令的真实退出码，使 make 和 CI 能识别启动、停止或运行失败。
exit $?

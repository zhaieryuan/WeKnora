# generate_proto.sh 脚本说明文档

## 概述

`generate_proto.sh` 是一个自动化脚本，用于从 Protocol Buffer (`.proto`) 文件生成多语言（Python 和 Go）的 gRPC 客户端/服务端代码。

**脚本路径**: `docreader/scripts/generate_proto.sh`

## 脚本功能

该脚本主要完成以下功能：

1. **生成 Python 代码** - 使用 `grpc_tools.protoc` 生成 Python gRPC 代码
2. **生成 Go 代码** - 使用 `protoc` 生成 Go gRPC 代码（可选）
3. **修复导入问题** - 自动修复 Python 模块导入路径，兼容 MacOS 和 Linux

## 脚本完整代码

```bash
#!/bin/bash
set -ex

# 设置目录
PROTO_DIR="./proto"
PYTHON_OUT="./proto"
GO_OUT="./proto"

# 生成Python代码
python3 -m grpc_tools.protoc -I${PROTO_DIR} \
    --python_out=${PYTHON_OUT} \
    --pyi_out=${PYTHON_OUT} \
    --grpc_python_out=${PYTHON_OUT} \
    ${PROTO_DIR}/docreader.proto

# 生成Go代码（仅在 protoc-gen-go 可用时执行）
if command -v protoc-gen-go &> /dev/null; then
    protoc -I${PROTO_DIR} --go_out=${GO_OUT} \
        --go_opt=paths=source_relative \
        --go-grpc_out=${GO_OUT} \
        --go-grpc_opt=paths=source_relative \
        ${PROTO_DIR}/docreader.proto
else
    echo "protoc-gen-go not found, skipping Go code generation"
fi

# 修复Python导入问题（MacOS兼容版本）
if [ "$(uname)" == "Darwin" ]; then
    # MacOS版本
    sed -i '' 's/import docreader_pb2/from docreader.proto import docreader_pb2/g' ${PYTHON_OUT}/docreader_pb2_grpc.py
else
    # Linux版本
    sed -i 's/import docreader_pb2/from docreader.proto import docreader_pb2/g' ${PYTHON_OUT}/docreader_pb2_grpc.py
fi

echo "Proto files generated successfully!"
```

## 脚本详解

### 1. Shebang 和调试选项

```bash
#!/bin/bash
set -ex
```

- `#!/bin/bash` - 指定使用 bash 解释器
- `set -e` - 遇到错误立即退出（exit on error）
- `set -x` - 执行命令前打印命令（debug mode）

### 2. 目录配置

```bash
PROTO_DIR="./proto"    # .proto 文件所在目录
PYTHON_OUT="./proto"   # Python 代码输出目录
GO_OUT="./proto"       # Go 代码输出目录
```

### 3. Python 代码生成

```bash
python3 -m grpc_tools.protoc -I${PROTO_DIR} \
    --python_out=${PYTHON_OUT} \
    --pyi_out=${PYTHON_OUT} \
    --grpc_python_out=${PYTHON_OUT} \
    ${PROTO_DIR}/docreader.proto
```

**参数说明**：

| 参数 | 说明 |
|------|------|
| `-I${PROTO_DIR}` | 指定 .proto 文件的搜索目录（import 路径） |
| `--python_out=${PYTHON_OUT}` | 输出 Python 消息类代码 |
| `--pyi_out=${PYTHON_OUT}` | 输出 Python 类型提示文件（`.pyi`） |
| `--grpc_python_out=${PYTHON_OUT}` | 输出 Python gRPC 服务/客户端代码 |
| `${PROTO_DIR}/docreader.proto` | 要编译的 proto 文件 |

### 4. Go 代码生成（可选）

```bash
if command -v protoc-gen-go &> /dev/null; then
    protoc -I${PROTO_DIR} --go_out=${GO_OUT} \
        --go_opt=paths=source_relative \
        --go-grpc_out=${GO_OUT} \
        --go-grpc_opt=paths=source_relative \
        ${PROTO_DIR}/docreader.proto
else
    echo "protoc-gen-go not found, skipping Go code generation"
fi
```

**参数说明**：

| 参数 | 说明 |
|------|------|
| `--go_out=${GO_OUT}` | 输出 Go 消息类代码 |
| `--go_opt=paths=source_relative` | 生成的文件使用相对路径（推荐） |
| `--go-grpc_out=${GO_OUT}` | 输出 Go gRPC 服务/客户端代码 |
| `--go-grpc_opt=paths=source_relative` | gRPC 代码使用相对路径 |

### 5. 修复 Python 导入问题

```bash
if [ "$(uname)" == "Darwin" ]; then
    # MacOS版本
    sed -i '' 's/import docreader_pb2/from docreader.proto import docreader_pb2/g' ${PYTHON_OUT}/docreader_pb2_grpc.py
else
    # Linux版本
    sed -i 's/import docreader_pb2/from docreader.proto import docreader_pb2/g' ${PYTHON_OUT}/docreader_pb2_grpc.py
fi
```

**原因**：
- 生成的 Python gRPC 代码默认使用 `import docreader_pb2`
- 但由于目录结构，正确的导入路径应该是 `from docreader.proto import docreader_pb2`
- MacOS 和 Linux 的 `sed -i` 命令语法不同，需要分别处理

## 使用方法

### 前置依赖

**Python 代码生成依赖**：
```bash
pip install grpcio grpcio-tools
```

**Go 代码生成依赖**：
```bash
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
```

### 运行脚本

```bash
# 进入 docreader 目录
cd docreader

# 运行脚本
./scripts/generate_proto.sh
```

或使用 Makefile：
```bash
make proto
```

### 生成的文件

执行脚本后，会在 `proto/` 目录下生成以下文件：

**Python 文件**：
- `docreader_pb2.py` - 消息类定义
- `docreader_pb2.pyi` - 类型提示文件
- `docreader_pb2_grpc.py` - gRPC 服务/客户端代码

**Go 文件**（如果 protoc-gen-go 可用）：
- `docreader.pb.go` - 消息类定义
- `docreader_grpc.pb.go` - gRPC 服务/客户端代码

## 常见问题

### Q1: 提示 `protoc-gen-go not found`

**解决方法**：安装 Go protobuf 插件
```bash
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest
# 确保 $GOPATH/bin 在 PATH 中
export PATH=$PATH:$(go env GOPATH)/bin
```

### Q2: Python 导入报错 `ModuleNotFoundError`

**解决方法**：确保脚本中的 sed 命令执行成功，或者手动修改 `docreader_pb2_grpc.py` 中的导入语句。

### Q3: MacOS 上 `sed -i` 报错

**原因**：Linux 的 `sed -i` 与 MacOS 不同。
**解决方法**：脚本已处理此问题，使用 `sed -i ''`（带空字符串）。

## 输出路径选项说明

`paths=source_relative` vs `paths=import_relative`：

| 选项 | 行为 | 输出位置 |
|------|------|----------|
| `paths=source_relative` | 在 `.proto` 文件所在目录生成 | `proto/docreader.pb.go` |
| `paths=import_relative` (默认) | 根据 import 路径生成 | `proto/docreader/docreader.pb.go` |

本项目使用 `source_relative`，使生成的文件与 `.proto` 文件在同一目录，便于管理。

## 总结

`generate_proto.sh` 是一个简单但功能完整的脚本，它：

1. **自动化**了 protobuf 代码生成流程
2. **支持多语言**（Python 和 Go）
3. **处理了跨平台兼容性**（MacOS/Linux）
4. **优雅降级**（Go 插件不可用时跳过）

通过此脚本，可以轻松地将 `.proto` 定义转换为不同语言的代码，实现跨语言 gRPC 通信。

#!/bin/bash
set -ex

# 切换到脚本所在目录的父目录（即 docreader/）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# 设置目录（现在相对于脚本目录的父目录）
PROTO_DIR="./proto"
PYTHON_OUT="./proto"
GO_OUT="./proto"

# 生成Python代码
python3 -m grpc_tools.protoc -I${PROTO_DIR} \
    --python_out=${PYTHON_OUT} \
    --pyi_out=${PYTHON_OUT} \
    --grpc_python_out=${PYTHON_OUT} \
    ${PROTO_DIR}/docreader.proto

# 生成Java代码（仅在 grpc-java 插件可用时执行）
if command -v protoc-gen-grpc-java &> /dev/null || [ -f "./protoc-gen-grpc-java-1.33.0-linux-x86_64.jar" ]; then
    if [ -f "./protoc-gen-grpc-java-1.33.0-linux-x86_64.jar" ]; then
        protoc -I${PROTO_DIR} \
            --plugin=protoc-gen-grpc-java=./protoc-gen-grpc-java-1.33.0-linux-x86_64.jar \
            --grpc-java_out=${GO_OUT} \
            --java_out=${GO_OUT} \
            ${PROTO_DIR}/docreader.proto
    else
        protoc -I${PROTO_DIR} \
            --grpc-java_out=${GO_OUT} \
            --java_out=${GO_OUT} \
            ${PROTO_DIR}/docreader.proto
    fi
else
    echo "protoc-gen-grpc-java not found, skipping Java code generation"
fi

# 生成C++代码（可选，C++ 编译器通常已包含）
protoc -I${PROTO_DIR} --cpp_out=${GO_OUT} \
    ${PROTO_DIR}/docreader.proto 2>/dev/null || echo "C++ code generation failed, skipping"

# 生成TypeScript代码（仅在 protoc-gen-ts 可用时执行）
if command -v protoc-gen-ts &> /dev/null || [ -f "./node_modules/.bin/protoc-gen-ts" ]; then
    protoc -I${PROTO_DIR} \
        --plugin=protoc-gen-ts=$(which protoc-gen-ts 2>/dev/null || echo "./node_modules/.bin/protoc-gen-ts") \
        --ts_out=${GO_OUT} \
        ${PROTO_DIR}/docreader.proto
else
    echo "protoc-gen-ts not found, skipping TypeScript code generation"
fi

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
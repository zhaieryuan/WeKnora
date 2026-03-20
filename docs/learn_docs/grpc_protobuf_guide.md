# gRPC 与 Protocol Buffers 讲解

## 目录

1. [概述](#概述)
2. [Protocol Buffers 基础](#protocol-buffers-基础)
3. [gRPC 基础](#grpc-基础)
4. [实战案例：DocReader API](#实战案例docreader-api)
5. [最佳实践](#最佳实践)

---

## 概述

### 什么是 gRPC？

gRPC（Google Remote Procedure Call）是一种高性能、开源的远程过程调用（RPC）框架，由 Google 开发。它可以在任何环境中运行，支持跨语言和跨平台的服务调用。

**核心特点**：
- **基于 HTTP/2**：支持双向流、流量控制、头部压缩
- **使用 Protocol Buffers**：高效的二进制序列化格式
- **多语言支持**：自动生成 10+ 种语言的代码
- **流式传输**：支持 unary、client streaming、server streaming、bidirectional streaming

### 什么是 Protocol Buffers？

Protocol Buffers（简称 Protobuf）是 Google 开发的一种语言中立、平台中立的可扩展序列化结构数据格式，类似于 XML，但更小、更快、更简单。

**核心特点**：
- **二进制格式**：比 JSON/XML 更小更快
- **强类型**：编译时类型检查
- **版本兼容**：支持字段增删而不破坏兼容性
- **自描述**：可以通过 `.proto` 文件定义接口

---

## Protocol Buffers 基础

### .proto 文件结构

```protobuf
syntax = "proto3";              // 指定 proto 版本

package docreader;              // 包名（防止命名冲突）

// 导入其他 proto 文件
import "google/protobuf/empty.proto";

// 定义消息
message ReadRequest {
    bytes file_content = 1;     // 字段编号（唯一标识符）
    string file_name = 2;
    string file_type = 3;
    string url = 4;
    ReadConfig config = 5;      // 嵌套消息
    string request_id = 6;
}

// 定义枚举
enum ParserEngine {
    BUILTIN = 0;                // 枚举值从 0 开始
    MARKITDOWN = 1;
}

// 定义服务
service DocReader {
    rpc Read(ReadRequest) returns (ReadResponse);
    rpc ListEngines(ListEnginesRequest) returns (ListEnginesResponse);
}
```

### 基本数据类型

| Proto 类型 | Go 类型 | Python 类型 | 说明 |
|------------|---------|-------------|------|
| `double` | `float64` | `float` | 64位浮点数 |
| `float` | `float32` | `float` | 32位浮点数 |
| `int32` | `int32` | `int` | 32位整数 |
| `int64` | `int64` | `int` | 64位整数 |
| `uint32` | `uint32` | `int` | 32位无符号整数 |
| `uint64` | `uint64` | `int` | 64位无符号整数 |
| `bool` | `bool` | `bool` | 布尔值 |
| `string` | `string` | `str` | 字符串 |
| `bytes` | `[]byte` | `bytes` | 字节数组 |

### 高级类型

#### 1. repeated（数组/列表）

```protobuf
message ImageRefs {
    repeated ImageRef image_refs = 1;  // 类似数组
}
```

**生成代码**：
- Go: `[]ImageRef`
- Python: `list[ImageRef]`

#### 2. map（字典/哈希表）

```protobuf
message Metadata {
    map<string, string> metadata = 1;
}
```

**生成代码**：
- Go: `map[string]string`
- Python: `dict[str, str]`

#### 3. oneof（联合类型）

```protobuf
message Request {
    oneof payload {
        bytes file_data = 1;
        string url = 2;
    }
}
```

**生成代码**：
- Go: `interface{}`
- Python: `Union[bytes, str]`

#### 4. optional（proto3+ 可选字段）

```protobuf
message Request {
    optional string user_id = 1;  // 可选字段
}
```

### 字段编号规则

- 字段编号用于二进制格式中的标识
- 编号 1-15：使用 1 字节编码（保留给高频使用的字段）
- 编号 16-2047：使用 2 字节编码
- 不能使用 19000-19999（保留给 Protocol Buffers 实现）

### 默认值

| 类型 | 默认值 |
|------|--------|
| 数值 | 0 |
| bool | false |
| string/bytes | "" |
| enum | 枚举第一个值（必须是 0） |
| repeated | 空列表 |

---

## gRPC 基础

### 四种调用模式

#### 1. Unary RPC（一元调用）

客户端发送请求，服务端返回响应。

```protobuf
service DocReader {
    rpc Read(ReadRequest) returns (ReadResponse);  // 一元调用
}
```

#### 2. Server Streaming（服务端流）

客户端发送请求，服务端返回流式响应。

```protobuf
service DocReader {
    rpc StreamRead(ReadRequest) returns (stream Chunk);  // 服务端流
}
```

#### 3. Client Streaming（客户端流）

客户端发送流式请求，服务端返回响应。

```protobuf
service DocReader {
    rpc Upload(stream Chunk) returns (UploadResponse);  // 客户端流
}
```

#### 4. Bidirectional Streaming（双向流）

客户端和服务端都使用流式通信。

```protobuf
service DocReader {
    rpc Chat(stream Message) returns (stream Message);  // 双向流
}
```

### gRPC 通信流程

```
┌─────────┐                    ┌─────────┐
│ Client  │                    │ Server  │
└────┬────┘                    └────┬────┘
     │                              │
     │ 1. 连接（HTTP/2）            │
     │────────────────────────────>│
     │                              │
     │ 2. 发送请求（Protobuf）       │
     │────────────────────────────>│
     │                              │
     │ 3. 处理请求                   │
     │                              │
     │ 4. 返回响应（Protobuf）       │
     │<────────────────────────────│
     │                              │
     │ 5. 关闭连接                   │
     │<────────────────────────────>│
```

---

## 实战案例：DocReader API

### DocReader.proto 完整定义

```protobuf
syntax = "proto3";

package docreader;

// 解析器配置
message ReadConfig {
    string parser_engine = 1;                    // 解析引擎：builtin, markitdown
    map<string, string> parser_engine_overrides = 2;  // 引擎特定配置
}

// 图像引用
message ImageRef {
    string filename = 1;        // 文件名
    string original_ref = 2;    // 原始引用路径
    string mime_type = 3;       // MIME 类型
    string storage_key = 4;     // 存储键
    bytes image_data = 5;       // 图像数据（内联回退）
}

// 读取请求
message ReadRequest {
    oneof source {              // 数据源（二选一）
        bytes file_content = 1; // 文件内容
        string url = 2;         // URL
    }
    string file_name = 3;       // 文件名
    string file_type = 4;       // 文件类型
    string title = 5;           // 标题（用于网页）
    ReadConfig config = 6;      // 配置
    string request_id = 7;      // 请求 ID
}

// 读取响应
message ReadResponse {
    string markdown_content = 1;              // Markdown 内容
    repeated ImageRef image_refs = 2;        // 图像引用列表
    string image_dir_path = 3;               // 图像目录路径（已废弃）
    map<string, string> metadata = 4;       // 元数据
    string error = 5;                       // 错误信息
}

// 列出引擎请求
message ListEnginesRequest {}

// 引擎信息
message EngineInfo {
    string name = 1;                         // 引擎名称
    string description = 2;                  // 描述
    bool available = 3;                      // 是否可用
    repeated string supported_types = 4;     // 支持的文件类型
}

// 列出引擎响应
message ListEnginesResponse {
    repeated EngineInfo engines = 1;         // 引擎列表
}

// DocReader 服务定义
service DocReader {
    rpc Read(ReadRequest) returns (ReadResponse);
    rpc ListEngines(ListEnginesRequest) returns (ListEnginesResponse);
}
```

### Go 服务端实现

```go
// server/server.go
package server

import (
    "context"
    "log"
    "net"

    "google.golang.org/grpc"
    pb "your-project/proto"
)

type Server struct {
    pb.UnimplementedDocReaderServer  // 必须嵌入未实现的服务器
}

func (s *Server) Read(ctx context.Context, req *pb.ReadRequest) (*pb.ReadResponse, error) {
    // 处理读取请求
    resp := &pb.ReadResponse{
        MarkdownContent: "# Document Content",
        ImageRefs: []*pb.ImageRef{
            {
                Filename:    "image.png",
                OriginalRef: "images/image.png",
                MimeType:    "image/png",
            },
        },
        Metadata: map[string]string{
            "page_count": "10",
        },
    }
    return resp, nil
}

func (s *Server) ListEngines(ctx context.Context, req *pb.ListEnginesRequest) (*pb.ListEnginesResponse, error) {
    return &pb.ListEnginesResponse{
        Engines: []*pb.EngineInfo{
            {
                Name:        "builtin",
                Description: "Built-in parser",
                Available:   true,
                SupportedTypes: []string{"pdf", "docx", "md"},
            },
        },
    }, nil
}

func Start(addr string) error {
    lis, err := net.Listen("tcp", addr)
    if err != nil {
        return err
    }

    s := grpc.NewServer()
    pb.RegisterDocReaderServer(s, &Server{})

    log.Printf("Server listening on %s", addr)
    return s.Serve(lis)
}
```

### Go 客户端实现

```go
// client/client.go
package client

import (
    "context"
    "fmt"

    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials/insecure"
    pb "your-project/proto"
)

type Client struct {
    conn   *grpc.ClientConn
    client pb.DocReaderClient
}

func NewClient(addr string) (*Client, error) {
    conn, err := grpc.Dial(addr, grpc.WithTransportCredentials(insecure.NewCredentials()))
    if err != nil {
        return nil, err
    }

    return &Client{
        conn:   conn,
        client: pb.NewDocReaderClient(conn),
    }, nil
}

func (c *Client) Read(ctx context.Context, content []byte, filename, fileType string) (*pb.ReadResponse, error) {
    req := &pb.ReadRequest{
        Source: &pb.ReadRequest_FileContent{
            FileContent: content,
        },
        FileName: filename,
        FileType: fileType,
        Config: &pb.ReadConfig{
            ParserEngine: "builtin",
        },
    }

    return c.client.Read(ctx, req)
}

func (c *Client) ListEngines(ctx context.Context) (*pb.ListEnginesResponse, error) {
    return c.client.ListEngines(ctx, &pb.ListEnginesRequest{})
}

func (c *Client) Close() error {
    return c.conn.Close()
}
```

### Python 服务端实现

```python
# server/main.py
import grpc
from concurrent import futures
from proto import docreader_pb2, docreader_pb2_grpc

class DocReaderServicer(docreader_pb2_grpc.DocReaderServicer):
    def Read(self, request, context):
        # 处理读取请求
        response = docreader_pb2.ReadResponse(
            markdown_content="# Document Content",
            image_refs=[
                docreader_pb2.ImageRef(
                    filename="image.png",
                    original_ref="images/image.png",
                    mime_type="image/png"
                )
            ],
            metadata={
                "page_count": "10"
            }
        )
        return response

    def ListEngines(self, request, context):
        return docreader_pb2.ListEnginesResponse(
            engines=[
                docreader_pb2.EngineInfo(
                    name="builtin",
                    description="Built-in parser",
                    available=True,
                    supported_types=["pdf", "docx", "md"]
                )
            ]
        )

def serve(addr='[::]:50051'):
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=4))
    docreader_pb2_grpc.add_DocReaderServicer_to_server(DocReaderServicer(), server)
    server.add_insecure_port(addr)
    server.start()
    print(f"Server listening on {addr}")
    server.wait_for_termination()

if __name__ == '__main__':
    serve()
```

### Python 客户端实现

```python
# client/client.py
import grpc
from proto import docreader_pb2, docreader_pb2_grpc

class DocReaderClient:
    def __init__(self, addr='localhost:50051'):
        self.channel = grpc.insecure_channel(addr)
        self.stub = docreader_pb2_grpc.DocReaderStub(self.channel)

    def read(self, content: bytes, filename: str, file_type: str):
        request = docreader_pb2.ReadRequest(
            file_content=content,
            file_name=filename,
            file_type=file_type,
            config=docreader_pb2.ReadConfig(parser_engine="builtin")
        )
        return self.stub.Read(request)

    def list_engines(self):
        request = docreader_pb2.ListEnginesRequest()
        return self.stub.ListEngines(request)

    def close(self):
        self.channel.close()

# 使用示例
if __name__ == '__main__':
    client = DocReaderClient()
    try:
        response = client.read(
            content=b"file content",
            filename="document.pdf",
            file_type="pdf"
        )
        print(response.markdown_content)
    finally:
        client.close()
```

---

## 最佳实践

### 1. API 设计原则

- **单一职责**：每个服务专注于特定功能
- **向前兼容**：使用 `optional` 字段，不要删除字段
- **合理使用流**：大数据传输使用流式调用
- **错误处理**：使用 gRPC status codes 而非字符串错误

### 2. 性能优化

- **字段编号**：高频字段使用 1-15
- **使用 repeated 而非嵌套消息**：减少嵌套层级
- **启用压缩**：使用 `gzip` 压缩
- **连接复用**：客户端复用连接，不要频繁创建

### 3. 安全建议

- **使用 TLS**：生产环境必须启用加密
- **添加认证**：使用 OAuth2、JWT 或自定义认证
- **限制消息大小**：设置 `MaxRecvMsgSize` 和 `MaxSendMsgSize`
- **添加超时**：避免长时间挂起的请求

### 4. 错误处理

```go
import "google.golang.org/grpc/codes"
import "google.golang.org/grpc/status"

// 服务端返回错误
return nil, status.Error(codes.InvalidArgument, "Invalid file type")

// 客户端处理错误
resp, err := client.Read(ctx, req)
if err != nil {
    st, ok := status.FromError(err)
    if ok {
        switch st.Code() {
        case codes.InvalidArgument:
            // 处理无效参数
        case codes.NotFound:
            // 处理资源未找到
        }
    }
}
```

### 5. 文档生成

使用 `protoc-gen-doc` 生成 API 文档：

```bash
protoc -I. --doc_out=html,index.html:. proto/*.proto
```

---

## 总结

| 方面 | Protocol Buffers | gRPC |
|------|------------------|------|
| 作用 | 数据序列化格式 | RPC 通信框架 |
| 格式 | 二进制 | HTTP/2 + Protobuf |
| 优势 | 小、快、类型安全 | 高性能、流式、多语言 |
| 适用场景 | 数据存储、API 定义 | 微服务通信 |

**关键要点**：
1. Protocol Buffers 定义数据结构，gRPC 定义服务接口
2. `.proto` 文件是单一真相来源
3. 代码自动生成，保证类型安全
4. 支持跨语言、跨平台通信
5. 高性能，适合微服务架构

---

## 参考资料

- [Protocol Buffers 官方文档](https://protobuf.dev/)
- [gRPC 官方文档](https://grpc.io/docs/)
- [gRPC Go 教程](https://grpc.io/docs/languages/go/)
- [gRPC Python 教程](https://grpc.io/docs/languages/python/)

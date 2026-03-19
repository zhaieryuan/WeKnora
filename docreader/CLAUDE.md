# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DocReader is a gRPC service within the WeKnora ecosystem that handles document parsing, processing, and conversion to Markdown. It supports multiple document formats (PDF, Word, Markdown, Excel, images, web pages, etc.) and multiple parsing engines. The service returns converted content as Markdown with embedded image references, suitable for knowledge retrieval and document analysis systems.

## Common Commands

### Build & Development

```bash
# Generate protobuf code (both Python and Go)
make proto

# Build Go client
cd client
go build -o ../bin/client .

# Run Python gRPC server
python main.py

# Or via Makefile (if fixed)
make run

# Clean build artifacts
make clean
```

### Running the Service

The service runs as a Python gRPC server on port 50051 (configurable via `DOCREADER_GRPC_PORT`).

```bash
# Run directly
python main.py
```

### Running Tests (Go client)

```bash
# Run Go client tests
cd client
go test -v

# Run specific test
go test -v -run TestReadFromFile
```

## Architecture Overview

### Request Flow

1. **gRPC Server** (`main.py:DocReaderServicer`) receives `Read` requests (file mode or URL mode)
2. **Parser** (`parser/parser.py:Parser`) calls `parse_file()` or `parse_url()`
3. **Parser Engine Registry** (`parser/registry.py`) selects the appropriate parser engine based on `parser_engine` config
4. **Document Parser** extends `BaseParser` (`parser/base_parser.py`) and extracts content
5. **Response** returns `ReadResponse` with `markdown_content`, `image_refs`, and `metadata`

### Key Components

#### Parser Engine Registry

The `ParserEngineRegistry` in `parser/registry.py` manages multiple parsing engines:
- **builtin** (BUILTIN_ENGINE) - Default Python-based parsers:
  - `docx` → `Docx2Parser`
  - `doc` → `DocParser`
  - `pdf` → `PDFParser`
  - `md`/`markdown` → `MarkdownParser`
  - `xlsx`/`xls` → `ExcelParser`
  - Images (`jpg`, `jpeg`, `png`, `gif`, `bmp`, `tiff`, `webp`) → `ImageParser`
- **markitdown** - Microsoft's MarkItDown library (additional formats: pptx, ppt, csv)

All parsers extend `BaseParser`. The registry provides automatic fallback: if a requested engine doesn't support a file type, it falls back to the builtin engine.

#### Base Parser Interface

The `BaseParser` class (`parser/base_parser.py`) defines the interface that all parsers must implement. Key method:
- `parse()` - Extracts document content and returns a result object with:
  - `content` - The extracted text/markdown content
  - `images` - Dictionary of `{relative_path: base64_data_or_bytes}`
  - `metadata` - Optional metadata dictionary

### gRPC API

**Service:** `docreader.DocReader`

**Methods:**
- `Read(ReadRequest) returns (ReadResponse)` - Unified read method for file or URL
- `ListEngines(ListEnginesRequest) returns (ListEnginesResponse)` - List available parser engines

**ReadRequest Fields:**
- `file_content` (bytes) - File data for file mode
- `file_name` (string) - Filename
- `file_type` (string) - File extension (e.g., "pdf", "docx")
- `url` (string) - URL for URL mode
- `title` (string) - Optional title for web pages
- `config` (ReadConfig) - Parser configuration
- `request_id` (string) - Request identifier

**ReadConfig Fields:**
- `parser_engine` (string) - Engine name: "builtin", "markitdown", etc.
- `parser_engine_overrides` (map<string, string>) - Engine-specific overrides

**ReadResponse Fields:**
- `markdown_content` (string) - Converted Markdown content
- `image_refs` (repeated ImageRef) - Image references
- `image_dir_path` (string) - Image directory path (deprecated, empty)
- `metadata` (map<string, string>) - Response metadata
- `error` (string) - Error message if failed

**ImageRef Fields:**
- `filename` (string) - Image filename
- `original_ref` (string) - Original reference path
- `mime_type` (string) - MIME type
- `storage_key` (string) - Download URL from shared storage
- `image_data` (bytes) - Inline bytes fallback

### Environment Variables

All configuration is done via environment variables with `DOCREADER_` prefix (new convention, backward compatible with old names):

**gRPC:**
- `DOCREADER_GRPC_PORT` - Server port (default: 50051)
- `DOCREADER_GRPC_MAX_WORKERS` - Max worker threads (default: 4)
- `DOCREADER_GRPC_MAX_FILE_SIZE_MB` - Max file size (default: 50MB)
- `MAX_FILE_SIZE_MB` - Legacy alias for max file size

**Other:**
- `DOCREADER_EXTERNAL_HTTP_PROXY` / `DOCREADER_EXTERNAL_HTTPS_PROXY` - Proxy settings
- `DOCREADER_IMAGE_OUTPUT_DIR` - Temporary image output directory (default: /tmp/docreader)
- `LOG_LEVEL` - Logging level (default: INFO)

**Note:** OCR, VLM, and storage configuration have been removed from the Python service. These are now handled by the Go application. The Python service only extracts content and returns images as inline base64-encoded bytes.

### Go Client

The Go client (`client/client.go`) provides:
- `NewClient(addr)` - Create client with connection to server
- `Read()` - Invoke service via generated proto client
- `GetImageRefsFromResponse(resp)` - Helper to extract image metadata from response
- `Close()` - Close the connection

The client configures message size limits via `MAX_FILE_SIZE_MB` environment variable (default: 50MB).

### Health Check

The service implements gRPC health check via `grpc_health_probe`. Use:
```bash
grpc_health_probe -addr=:50051
```

## File Structure

```
docreader/
├── main.py              # gRPC server entry point
├── config.py            # Environment variable configuration
├── proto/               # Protocol Buffer definitions and generated code
│   └── docreader.proto  # API definition
├── parser/              # Document parsers
│   ├── parser.py        # Parser facade
│   ├── base_parser.py   # Base parser interface
│   ├── registry.py      # Parser engine registry
│   └── *_parser.py     # Format-specific parsers
├── models/              # Pydantic models
├── utils/               # Utility functions (tempfile, request, encoding)
├── client/              # Go gRPC client
│   └── client.go       # Go client implementation
└── scripts/             # Build scripts
    └── generate_proto.sh # Protobuf code generation
```

## Adding a New Parser

1. Create a new parser class extending `BaseParser` in `parser/`
2. Implement the `parse()` method to extract content and return a result object
3. Register the parser in `parser/registry.py`:
   - Add to the appropriate engine's file_types dictionary
   - Or register a new engine using `reg.register()`

## Adding a New Parser Engine

1. Create parser classes extending `BaseParser`
2. In `parser/registry.py`, call `reg.register()`:
   ```python
   reg.register(
       "my_engine",
       {
           "pdf": MyPDFParser,
           "docx": MyDocxParser,
       },
       description="My custom engine",
       check_available=lambda overrides: (True, ""),  # Optional
       unavailable_hint="Install dependencies for my_engine",
   )
   ```

The registry will automatically fall back to builtin if the requested engine doesn't support a file type.

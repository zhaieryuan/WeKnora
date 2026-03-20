# DocReader Java Client

Java gRPC client for the DocReader service, which handles document parsing, processing, and conversion to Markdown.

## Features

- Parse documents from file content (PDF, Word, Markdown, Excel, images, etc.)
- Parse documents from URLs
- Support for multiple parser engines (builtin, markitdown)
- Extract images and metadata from parsed documents
- Configurable message size limits
- Easy-to-use fluent API

## Requirements

- Java 11 or higher
- Maven 3.6 or higher

## Installation

### Build from Source

```bash
cd java
mvn clean install
```

The build process will:
1. Download required dependencies
2. Generate gRPC and protobuf code from `proto/docreader.proto`
3. Compile the Java source code
4. Create a JAR file in `target/`

### Add to Your Project

#### Using Maven

Add to your `pom.xml`:

```xml
<dependency>
    <groupId>com.tencent</groupId>
    <artifactId>docreader-client</artifactId>
    <version>1.0.0</version>
</dependency>
```

## Quick Start

### Basic Usage

```java
import com.tencent.weknora.docreader.client.DocReaderClient;

// Create a client
DocReaderClient client = new DocReaderClient("localhost:50051");

try {
    // Read a document from file
    byte[] fileData = Files.readAllBytes(Paths.get("document.pdf"));
    DocReaderClient.ReadResult result = client.readFromFile(fileData, "document.pdf", "pdf");

    if (result.hasError()) {
        System.err.println("Error: " + result.getError());
    } else {
        System.out.println(result.getMarkdownContent());
    }

    // Read from URL
    DocReaderClient.ReadResult urlResult = client.readFromUrl("https://example.com");
    System.out.println(urlResult.getMarkdownContent());

} finally {
    client.shutdown();
}
```

### List Available Engines

```java
List<DocReaderClient.EngineInfo> engines = client.listEngines();

for (DocReaderClient.EngineInfo engine : engines) {
    System.out.println("Engine: " + engine.getName());
    System.out.println("  Available: " + engine.isAvailable());
    System.out.println("  File Types: " + engine.getFileTypes());
}
```

### Custom Parser Configuration

```java
// Use a specific parser engine
DocReaderClient.ReadConfig config = DocReaderClient.ReadConfig.withEngine("markitdown");
DocReaderClient.ReadResult result = client.readFromFile(
    fileData,
    "document.pdf",
    "pdf",
    config
);

// With engine overrides
Map<String, String> overrides = Map.of("timeout", "30s");
DocReaderClient.ReadConfig configWithOverrides = new DocReaderClient.ReadConfig(
    "markitdown",
    overrides
);
DocReaderClient.ReadResult result2 = client.readFromUrl(
    "https://example.com",
    "My Document",
    configWithOverrides,
    "request-123"
);
```

### Working with Images

```java
DocReaderClient.ReadResult result = client.readFromFile(fileData, "document.docx", "docx");

List<DocReaderClient.ImageRefInfo> images = result.getImageRefs();

for (DocReaderClient.ImageRefInfo imageRef : images) {
    System.out.println("Filename: " + imageRef.getFilename());
    System.out.println("MIME Type: " + imageRef.getMimeType());

    // Check if image data is inline
    if (imageRef.hasInlineData()) {
        byte[] imageData = imageRef.getImageData();
        // Process inline image data
    }

    // Or if there's a storage key
    if (imageRef.hasStorageKey()) {
        String storageKey = imageRef.getStorageKey();
        // Download from storage using the key
    }
}
```

### Accessing Metadata

```java
DocReaderClient.ReadResult result = client.readFromFile(...);

Map<String, String> metadata = result.getMetadata();
metadata.forEach((key, value) -> {
    System.out.println(key + ": " + value);
});
```

### Using Deadline/Timeout

```java
// Create a client with a 10-second deadline
DocReaderClient clientWithDeadline = client.withDeadline(10000);

DocReaderClient.ReadResult result = clientWithDeadline.readFromUrl("https://example.com");

// Remember to shutdown the deadline client
clientWithDeadline.shutdown();
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MAX_FILE_SIZE_MB` | Maximum file size in MB | 50 |

### Debug Mode

```java
// Create client with debug logging enabled
DocReaderClient client = new DocReaderClient("localhost:50051", true);
```

## API Reference

### DocReaderClient

| Method | Description |
|--------|-------------|
| `DocReaderClient(String address)` | Create a new client |
| `DocReaderClient(String address, boolean debug)` | Create a client with debug mode |
| `readFromFile(byte[], String, String)` | Read from file content |
| `readFromFile(byte[], String, String, ReadConfig)` | Read from file with config |
| `readFromUrl(String)` | Read from URL |
| `readFromUrl(String, String, ReadConfig)` | Read from URL with title and config |
| `readFromUrl(String, String, ReadConfig, String)` | Read from URL with title, config, and request ID |
| `listEngines()` | List available parser engines |
| `listEngines(Map<String, String>)` | List engines with config overrides |
| `shutdown()` | Shutdown the client |
| `withDeadline(long)` | Create a client with deadline timeout |

### ReadResult

| Method | Description |
|--------|-------------|
| `getMarkdownContent()` | Get the parsed Markdown content |
| `getImageRefs()` | Get list of image references |
| `getImageDirPath()` | Get image directory path (deprecated) |
| `getMetadata()` | Get response metadata |
| `getError()` | Get error message if any |
| `hasError()` | Check if there was an error |

### ImageRefInfo

| Method | Description |
|--------|-------------|
| `getFilename()` | Get image filename |
| `getOriginalRef()` | Get original reference path |
| `getMimeType()` | Get MIME type |
| `getStorageKey()` | Get storage download URL |
| `getImageData()` | Get inline image bytes |
| `hasInlineData()` | Check if inline data is available |
| `hasStorageKey()` | Check if storage key is available |

### EngineInfo

| Method | Description |
|--------|-------------|
| `getName()` | Get engine name |
| `getDescription()` | Get engine description |
| `getFileTypes()` | Get supported file types |
| `isAvailable()` | Check if engine is available |
| `getUnavailableReason()` | Get reason if unavailable |

## Example

Run the example to see the client in action:

```bash
cd java
mvn compile exec:java -Dexec.mainClass="Example" -Dexec.args="localhost:50051"
```

Or run with a test file:

```bash
mvn compile exec:java -Dexec.mainClass="Example" -Dexec.args="localhost:50051 path/to/document.pdf"
```

## Error Handling

The client may throw `StatusRuntimeException` for gRPC-level errors:

```java
try {
    DocReaderClient.ReadResult result = client.readFromFile(...);
    if (result.hasError()) {
        // Handle service-level errors
        System.err.println("Service error: " + result.getError());
    }
} catch (StatusRuntimeException e) {
    // Handle gRPC-level errors
    System.err.println("gRPC error: " + e.getStatus());
}
```

## Project Structure

```
java/
├── pom.xml                              # Maven build configuration
├── README.md                            # This file
├── Example.java                         # Usage examples
└── src/main/java/com/tencent/weknora/docreader/
    ├── proto/                           # Generated protobuf code
    │   ├── Docreader.java
    │   ├── DocReaderGrpc.java
    │   └── DocreaderProto.java
    └── client/
        └── DocReaderClient.java        # Main client implementation
```

## Dependencies

- gRPC Java: 1.65.1
- Protobuf Java: 4.28.3
- SLF4J: 2.0.16

## License

Copyright © Tencent

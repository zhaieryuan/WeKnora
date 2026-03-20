package com.tencent.weknora.docreader.client;

import io.grpc.StatusRuntimeException;

import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;
import java.util.Map;

/**
 * DocReader Java Client Usage Examples
 *
 * This class demonstrates how to use the DocReader Java client
 * to parse documents and list available parser engines.
 */
public class Example {

    public static void main(String[] args) {
        // Default server address
        String serverAddress = args.length > 0 ? args[0] : "localhost:50051";

        DocReaderClient client = new DocReaderClient(serverAddress);

        try {
            // Example 1: List available parser engines
            listEnginesExample(client);

            // Example 2: Read from a URL
            readFromUrlExample(client);

            // Example 3: Read from a file (if a file is provided)
            if (args.length > 1) {
                readFromFileExample(client, args[1]);
            } else {
                System.out.println("\n[TIP] Provide a file path as second argument to test file reading:");
                System.out.println("java Example localhost:50051 path/to/document.pdf");
            }

        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
            e.printStackTrace();
        } finally {
            try {
                client.shutdown();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        }
    }

    /**
     * Example: List available parser engines
     */
    private static void listEnginesExample(DocReaderClient client) {
        System.out.println("=== Listing Available Parser Engines ===");

        try {
            List<DocReaderClient.EngineInfo> engines = client.listEngines();

            for (DocReaderClient.EngineInfo engine : engines) {
                System.out.printf("Engine: %s%n", engine.getName());
                System.out.printf("  Description: %s%n", engine.getDescription());
                System.out.printf("  Available: %s%n", engine.isAvailable());
                System.out.printf("  File Types: %s%n", engine.getFileTypes());

                if (!engine.isAvailable() && engine.getUnavailableReason() != null) {
                    System.out.printf("  Unavailable Reason: %s%n", engine.getUnavailableReason());
                }
                System.out.println();
            }

        } catch (StatusRuntimeException e) {
            System.err.println("Failed to list engines: " + e.getStatus());
        }
    }

    /**
     * Example: Read a document from a URL
     */
    private static void readFromUrlExample(DocReaderClient client) {
        System.out.println("=== Reading from URL ===");

        String url = "https://example.com"; // Replace with a real URL
        System.out.printf("Reading from URL: %s%n", url);

        try {
            // Basic URL reading
            DocReaderClient.ReadResult result = client.readFromUrl(url);

            if (result.hasError()) {
                System.err.println("Error reading document: " + result.getError());
            } else {
                System.out.printf("Markdown content length: %d characters%n",
                        result.getMarkdownContent().length());
                System.out.printf("Number of images: %d%n", result.getImageRefs().size());
                System.out.println("Metadata: " + result.getMetadata());

                // Print first 500 characters of the content
                String preview = result.getMarkdownContent().length() > 500
                        ? result.getMarkdownContent().substring(0, 500) + "..."
                        : result.getMarkdownContent();
                System.out.println("\nContent preview:");
                System.out.println(preview);
            }

            System.out.println("\n--- Reading with Custom Engine ---");

            // Read with a specific parser engine
            DocReaderClient.ReadConfig config = DocReaderClient.ReadConfig.withEngine("markitdown");
            DocReaderClient.ReadResult resultWithEngine = client.readFromUrl(url, null, config);

            if (resultWithEngine.hasError()) {
                System.err.println("Error with custom engine: " + resultWithEngine.getError());
            } else {
                System.out.println("Successfully read with custom engine");
            }

        } catch (StatusRuntimeException e) {
            System.err.println("Failed to read from URL: " + e.getStatus());
        }
    }

    /**
     * Example: Read a document from a file
     */
    private static void readFromFileExample(DocReaderClient client, String filePath) {
        System.out.printf("=== Reading from File: %s ===%n", filePath);

        try {
            byte[] fileContent = Files.readAllBytes(Paths.get(filePath));
            String fileName = Paths.get(filePath).getFileName().toString();
            String fileType = fileName.substring(fileName.lastIndexOf('.') + 1);

            System.out.printf("File name: %s%n", fileName);
            System.out.printf("File type: %s%n", fileType);
            System.out.printf("File size: %d bytes%n", fileContent.length);

            // Basic file reading
            DocReaderClient.ReadResult result = client.readFromFile(fileContent, fileName, fileType);

            if (result.hasError()) {
                System.err.println("Error reading document: " + result.getError());
            } else {
                System.out.printf("Markdown content length: %d characters%n",
                        result.getMarkdownContent().length());
                System.out.printf("Number of images: %d%n", result.getImageRefs().size());
                System.out.println("Metadata: " + result.getMetadata());

                // Print image references
                if (!result.getImageRefs().isEmpty()) {
                    System.out.println("\nImage References:");
                    for (DocReaderClient.ImageRefInfo imageRef : result.getImageRefs()) {
                        System.out.printf("  - %s (%s)%n", imageRef.getFilename(), imageRef.getMimeType());
                        if (imageRef.hasStorageKey()) {
                            System.out.printf("    Storage Key: %s%n", imageRef.getStorageKey());
                        }
                        if (imageRef.hasInlineData()) {
                            System.out.printf("    Inline data: %d bytes%n", imageRef.getImageData().length);
                        }
                    }
                }

                // Print content preview
                String preview = result.getMarkdownContent().length() > 1000
                        ? result.getMarkdownContent().substring(0, 1000) + "..."
                        : result.getMarkdownContent();
                System.out.println("\nContent preview:");
                System.out.println(preview);
            }

            System.out.println("\n--- Reading with Engine Configuration ---");

            // Read with engine overrides
            DocReaderClient.ReadConfig config = new DocReaderClient.ReadConfig(
                    "markitdown",
                    Map.of("timeout", "30s")
            );
            DocReaderClient.ReadResult resultWithConfig = client.readFromFile(
                    fileContent,
                    fileName,
                    fileType,
                    config
            );

            if (resultWithConfig.hasError()) {
                System.err.println("Error with engine config: " + resultWithConfig.getError());
            } else {
                System.out.println("Successfully read with custom engine configuration");
            }

        } catch (Exception e) {
            System.err.println("Failed to read from file: " + e.getMessage());
            e.printStackTrace();
        }
    }

    /**
     * Example: Using deadline timeout
     */
    private static void readWithDeadlineExample(DocReaderClient client) {
        System.out.println("=== Reading with Deadline Timeout ===");

        try {
            // Create a client with a 10-second deadline for all requests
            DocReaderClient clientWithDeadline = client.withDeadline(10000);

            DocReaderClient.ReadResult result = clientWithDeadline.readFromUrl("https://example.com");

            if (result.hasError()) {
                System.err.println("Error: " + result.getError());
            } else {
                System.out.println("Successfully read within deadline");
            }

            // Remember to shutdown the deadline client when done
            clientWithDeadline.shutdown();

        } catch (Exception e) {
            System.err.println("Error: " + e.getMessage());
        }
    }
}

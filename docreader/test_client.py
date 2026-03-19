import grpc
from docreader.proto import docreader_pb2, docreader_pb2_grpc

def test_read_from_file():
    """Test reading from a simple text file."""
    print("Testing Read (file mode)...")
    with grpc.insecure_channel('localhost:50051') as channel:
        client = docreader_pb2_grpc.DocReaderStub(channel)

        # Create a simple test document (using markdown format)
        test_content = "# Test Document\n\nHello, this is a test document.\n\n## Section 1\n\nSome content here.".encode('utf-8')

        request = docreader_pb2.ReadRequest(
            file_content=test_content,
            file_name="test.md",
            file_type="md",
            request_id="test-001",
        )

        try:
            response = client.Read(request, timeout=10)
            print(f"Success! Response:")
            print(f"  Markdown content: {response.markdown_content[:100]}...")
            print(f"  Images count: {len(response.image_refs)}")
            print(f"  Error: {response.error}")
            return response
        except grpc.RpcError as e:
            print(f"gRPC Error: {e.code()} - {e.details()}")
            return None

def test_list_engines():
    """Test listing available parser engines."""
    print("\nTesting ListEngines...")
    with grpc.insecure_channel('localhost:50051') as channel:
        client = docreader_pb2_grpc.DocReaderStub(channel)

        request = docreader_pb2.ListEnginesRequest()

        try:
            response = client.ListEngines(request, timeout=10)
            print(f"Available engines:")
            for engine in response.engines:
                status = "available" if engine.available else f"unavailable ({engine.unavailable_reason})"
                print(f"  - {engine.name}: {engine.description} [{status}]")
                print(f"    File types: {', '.join(engine.file_types)}")
            return response
        except grpc.RpcError as e:
            print(f"gRPC Error: {e.code()} - {e.details()}")
            return None

if __name__ == "__main__":
    test_list_engines()
    test_read_from_file()

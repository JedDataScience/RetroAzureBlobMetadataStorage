# Tests

This directory contains smoke tests for the Azure Blob Metadata Manager API.

## Running Tests

### Prerequisites

1. Install test dependencies:
```bash
pip install pytest requests
```

2. Ensure the API is running:
```bash
# Using Docker
docker run -p 5000:5000 \
  -e AZURE_STORAGE_CONNECTION_STRING="UseDevelopmentStorage=true" \
  -e BLOB_CONTAINER="uploads" \
  blob-manager:latest

# Or use the run.sh script
./run.sh
```

### Run Tests

```bash
# Run all tests
pytest test_smoke.py -v

# Run with API URL override
API_BASE_URL=http://localhost:5000 pytest test_smoke.py -v

# Run specific test
pytest test_smoke.py::test_health_endpoint -v
```

## Test Coverage

The smoke tests verify:
- ✅ Health endpoint functionality
- ✅ Storage connectivity
- ✅ List blobs endpoint
- ✅ File upload functionality
- ✅ Error handling
- ✅ CORS configuration

## Notes

- Tests are designed to work with Azurite (local Azure Storage emulator)
- Tests will skip if the API is not available
- Test files are created automatically if needed
- Uploaded test files are cleaned up after tests


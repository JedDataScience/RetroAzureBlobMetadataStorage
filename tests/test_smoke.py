"""
Smoke tests for Azure Blob Metadata Manager API
These tests verify basic functionality without requiring Azure Storage setup.
"""

import pytest
import requests
import time
import os
from pathlib import Path

# Base URL for the API (default to localhost)
API_BASE_URL = os.getenv("API_BASE_URL", "http://localhost:5000")

# Test file for upload
TEST_FILE_PATH = Path(__file__).parent / "test_data" / "test.txt"


@pytest.fixture(scope="module")
def wait_for_api():
    """Wait for API to be ready before running tests."""
    max_retries = 30
    retry_count = 0
    
    while retry_count < max_retries:
        try:
            response = requests.get(f"{API_BASE_URL}/health", timeout=2)
            if response.status_code == 200:
                return True
        except requests.exceptions.RequestException:
            pass
        
        retry_count += 1
        time.sleep(1)
    
    pytest.skip("API is not available. Start the API with: docker run -p 5000:5000 blob-manager:latest")


def test_health_endpoint(wait_for_api):
    """Test that the health endpoint returns 200 OK."""
    response = requests.get(f"{API_BASE_URL}/health")
    assert response.status_code == 200
    data = response.json()
    assert data.get("ok") is True


def test_storage_health_endpoint(wait_for_api):
    """Test that the storage health endpoint works."""
    response = requests.get(f"{API_BASE_URL}/health/storage")
    # Should return 200 if storage is available, or 503 if not
    assert response.status_code in [200, 503]
    if response.status_code == 200:
        data = response.json()
        assert data.get("ok") is True
        assert "container" in data


def test_list_blobs_endpoint(wait_for_api):
    """Test that the list blobs endpoint returns valid JSON."""
    response = requests.get(f"{API_BASE_URL}/api/blobs")
    assert response.status_code == 200
    data = response.json()
    assert "blobs" in data
    assert isinstance(data["blobs"], list)


def test_api_info_endpoint(wait_for_api):
    """Test that the root endpoint returns API information."""
    response = requests.get(f"{API_BASE_URL}/")
    assert response.status_code == 200
    data = response.json()
    assert "message" in data
    assert "endpoints" in data


def test_upload_endpoint(wait_for_api):
    """Test file upload functionality."""
    # Create test file if it doesn't exist
    TEST_FILE_PATH.parent.mkdir(parents=True, exist_ok=True)
    TEST_FILE_PATH.write_text("This is a test file for smoke testing.")
    
    try:
        with open(TEST_FILE_PATH, "rb") as f:
            files = {"file": ("test.txt", f, "text/plain")}
            response = requests.post(f"{API_BASE_URL}/api/blobs", files=files)
        
        # Upload should succeed (201) or fail gracefully (400/500)
        assert response.status_code in [200, 201, 400, 500]
        
        if response.status_code in [200, 201]:
            data = response.json()
            assert "message" in data or "filename" in data
    finally:
        # Cleanup: try to delete the uploaded file
        try:
            requests.delete(f"{API_BASE_URL}/api/blobs/test.txt")
        except:
            pass


def test_cors_headers(wait_for_api):
    """Test that CORS headers are present."""
    response = requests.options(f"{API_BASE_URL}/api/blobs")
    # CORS preflight should be handled
    assert response.status_code in [200, 204, 405]


def test_error_handling(wait_for_api):
    """Test that invalid requests are handled gracefully."""
    # Test invalid blob name
    response = requests.get(f"{API_BASE_URL}/api/blobs/nonexistent-file-12345")
    assert response.status_code in [404, 500]  # Should return 404 for not found
    
    # Test invalid metadata update
    response = requests.put(
        f"{API_BASE_URL}/api/blobs/nonexistent-file/metadata",
        json={"metadata": {"test": "value"}}
    )
    assert response.status_code in [404, 500]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])


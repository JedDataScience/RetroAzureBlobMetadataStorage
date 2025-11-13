#!/bin/bash

# Azure Blob Metadata Manager - One-Command Launcher
# This script builds and runs the Flask API with Azurite (Azure Storage emulator) in Docker containers

set -e  # Exit on error

echo "🚀 Azure Blob Metadata Manager - Starting..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if .env file exists and if it's using real Azure Storage
USE_AZURITE=true
if [ -f .env ]; then
    if grep -q "blob.core.windows.net" .env 2>/dev/null; then
        echo "✅ Using .env file with real Azure Storage (skipping Azurite)"
        USE_AZURITE=false
        ENV_ARGS="--env-file .env"
    else
        echo "✅ Using .env file with Azurite"
        ENV_ARGS="--env-file .env"
    fi
else
    echo "⚠️  No .env file found. Using Azurite (Azure Storage emulator) for local testing."
    ENV_ARGS="-e AZURE_STORAGE_CONNECTION_STRING=UseDevelopmentStorage=true -e BLOB_CONTAINER=uploads"
fi

# Start Azurite if needed
if [ "$USE_AZURITE" = true ]; then
    echo "📦 Starting Azurite (Azure Storage emulator)..."
    
    # Stop and remove existing Azurite container if it exists
    docker stop azurite 2>/dev/null || true
    docker rm azurite 2>/dev/null || true
    
    # Start Azurite container
    docker run -d \
      --name azurite \
      -p 10000:10000 \
      -p 10001:10001 \
      -p 10002:10002 \
      mcr.microsoft.com/azure-storage/azurite \
      azurite --blobHost 0.0.0.0 --queueHost 0.0.0.0 --tableHost 0.0.0.0
    
    echo "⏳ Waiting for Azurite to be ready..."
    sleep 3
    
    # Verify Azurite is running
    if docker ps | grep -q azurite; then
        echo "✅ Azurite is running on ports 10000-10002"
    else
        echo "❌ Failed to start Azurite. Check logs with: docker logs azurite"
        exit 1
    fi
fi

# Build the Docker image
echo "📦 Building Flask API Docker image..."
docker build -t blob-manager:latest -f web/Dockerfile ./web

# Stop and remove existing container if it exists
echo "🧹 Cleaning up existing Flask API containers..."
docker stop blob-manager 2>/dev/null || true
docker rm blob-manager 2>/dev/null || true

# Run the Flask API container
echo "🏃 Starting Flask API container..."
docker run -d \
  --name blob-manager \
  -p 5000:5000 \
  $ENV_ARGS \
  blob-manager:latest

# Wait for container to be ready
echo "⏳ Waiting for Flask API to be ready..."
sleep 5

# Check health
echo "🏥 Checking API health..."
HEALTH_OK=false
for i in {1..10}; do
    if curl -s http://localhost:5000/health > /dev/null 2>&1; then
        HEALTH_OK=true
        break
    fi
    echo "   Attempt $i/10..."
    sleep 2
done

if [ "$HEALTH_OK" = true ]; then
    echo "✅ API is healthy!"
    
    # Check storage health if using Azurite
    if [ "$USE_AZURITE" = true ]; then
        echo "🏥 Checking storage connectivity..."
        sleep 2
        STORAGE_HEALTH=$(curl -s http://localhost:5000/health/storage || echo '{"ok":false}')
        if echo "$STORAGE_HEALTH" | grep -q '"ok":true'; then
            echo "✅ Storage is connected!"
        else
            echo "⚠️  Storage health check failed, but API is running. Storage operations may not work."
            echo "   This is normal if Azurite needs more time to initialize."
        fi
    fi
    
    echo ""
    echo "🎉 Application is running!"
    echo ""
    echo "🌐 API is running at: http://localhost:5000"
    echo "📋 Health check: curl http://localhost:5000/health"
    echo "📦 List blobs: curl http://localhost:5000/api/blobs"
    if [ "$USE_AZURITE" = true ]; then
        echo "💾 Azurite is running on ports 10000-10002"
    fi
    echo ""
    echo "📝 View API logs: docker logs -f blob-manager"
    if [ "$USE_AZURITE" = true ]; then
        echo "📝 View Azurite logs: docker logs -f azurite"
    fi
    echo "🛑 Stop all services: docker stop blob-manager azurite"
    echo "🧹 Remove all containers: docker rm blob-manager azurite"
else
    echo "❌ Health check failed. Check logs with: docker logs blob-manager"
    exit 1
fi

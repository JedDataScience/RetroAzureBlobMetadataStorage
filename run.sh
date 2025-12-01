#!/bin/bash

# Azure Blob Metadata Manager - Local Development Launcher
# This script builds and runs all services in Docker containers:
# - Azurite (Azure Storage emulator)
# - Flask API backend
# - Next.js frontend
# All services are fully containerized - no host dependencies required beyond Docker

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Change to the script's directory so relative paths work correctly
cd "$SCRIPT_DIR"

echo "Azure Blob Metadata Manager - Starting..."
echo "Working directory: $(pwd)"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Frontend is now containerized, so Node.js is not required on the host
# But we'll check if user wants to skip frontend
SKIP_FRONTEND=${SKIP_FRONTEND:-false}

# This project uses Azurite for local development only
USE_AZURITE=true
ENV_ARGS="-e BLOB_CONTAINER=uploads"
echo "Using Azurite (Azure Storage emulator) for local development"

# Start Azurite (Azure Storage emulator) for local development
echo "Starting Azurite (Azure Storage emulator)..."

# Create a Docker network for container communication (if it doesn't exist)
docker network create azurite-network 2>/dev/null || true

# Stop and remove existing Azurite container if it exists
docker stop azurite 2>/dev/null || true
docker rm azurite 2>/dev/null || true

# Start Azurite container on the network
docker run -d \
  --name azurite \
  --network azurite-network \
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

# Create a connection string that works from inside Docker container
# Use the container name "azurite" since both containers are on the same Docker network
# This works cross-platform (Linux, Mac, Windows)
AZURITE_CONN_STR="DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://azurite:10000/devstoreaccount1;"
ENV_ARGS="-e AZURE_STORAGE_CONNECTION_STRING=$AZURITE_CONN_STR -e BLOB_CONTAINER=uploads"

# Build the Docker image
echo "Building Flask API Docker image..."
if [ ! -d "web" ]; then
    echo "❌ Error: 'web' directory not found in $(pwd)"
    echo "   Please run this script from the RetroAzureBlobMetadataStorage directory"
    exit 1
fi
docker build -t blob-manager:latest -f web/Dockerfile ./web

# Stop and remove existing container if it exists
echo "🧹 Cleaning up existing Flask API containers..."
docker stop blob-manager 2>/dev/null || true
docker rm blob-manager 2>/dev/null || true

# Allow API_PORT to be overridden via environment variable, default to 5001
API_PORT=${API_PORT:-5001}

# Check if the port is available
if lsof -Pi :$API_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "⚠️  Port $API_PORT is already in use."
    # Check if it's a Docker container
    CONFLICTING_CONTAINER=$(docker ps --filter "publish=$API_PORT" --format "{{.Names}}" | head -1)
    if [ -n "$CONFLICTING_CONTAINER" ]; then
        echo "   Found Docker container using port: $CONFLICTING_CONTAINER"
        echo "   Stopping conflicting container..."
        docker stop "$CONFLICTING_CONTAINER" 2>/dev/null || true
        docker rm "$CONFLICTING_CONTAINER" 2>/dev/null || true
        sleep 2
        # Check again if port is now free
        if lsof -Pi :$API_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
            echo "❌ Port $API_PORT is still in use by a non-Docker process."
            echo "   On macOS, this might be AirPlay Receiver. You can disable it in:"
            echo "   System Settings > General > AirDrop & Handoff > AirPlay Receiver"
            echo ""
            echo "   Or use a different port by setting API_PORT environment variable:"
            echo "   API_PORT=5002 ./run.sh"
            exit 1
        fi
    else
        echo "❌ Port $API_PORT is in use by a non-Docker process."
        echo "   On macOS, this might be AirPlay Receiver. You can disable it in:"
        echo "   System Settings > General > AirDrop & Handoff > AirPlay Receiver"
        echo ""
        echo "   Or use a different port by setting API_PORT environment variable:"
        echo "   API_PORT=5002 ./run.sh"
        exit 1
    fi
fi

# Run the Flask API container
echo "Starting Flask API container on port $API_PORT..."
# Connect to the same network as Azurite
docker run -d \
  --name blob-manager \
  --network azurite-network \
  -p $API_PORT:5000 \
  $ENV_ARGS \
  blob-manager:latest

# Wait for container to be ready
echo "⏳ Waiting for Flask API to be ready..."
sleep 5

# Check health
echo "Checking API health..."
HEALTH_OK=false
for i in {1..10}; do
    if curl -s http://localhost:$API_PORT/health > /dev/null 2>&1; then
        HEALTH_OK=true
        break
    fi
    echo "   Attempt $i/10..."
    sleep 2
done

if [ "$HEALTH_OK" = true ]; then
    echo "✅ API is healthy!"
    
    # Check storage health (Azurite)
    echo "Checking storage connectivity..."
    sleep 2
    STORAGE_HEALTH=$(curl -s http://localhost:$API_PORT/health/storage || echo '{"ok":false}')
    if echo "$STORAGE_HEALTH" | grep -q '"ok":true'; then
        echo "✅ Storage is connected!"
    else
        echo "⚠️  Storage health check failed, but API is running. Storage operations may not work."
        echo "   This is normal if Azurite needs more time to initialize."
    fi
    
    echo ""
    echo "🎉 Backend is running!"
    echo ""
    echo "API is running at: http://localhost:$API_PORT"
    echo "Health check: curl http://localhost:$API_PORT/health"
    echo "List blobs: curl http://localhost:$API_PORT/api/blobs"
    echo "Azurite is running on ports 10000-10002"
    
    # Build and start frontend container
    if [ "${SKIP_FRONTEND:-false}" != "true" ]; then
        echo ""
        echo "Building and starting frontend container..."
        
        # Check if frontend Dockerfile exists
        if [ ! -f "code/Dockerfile" ]; then
            echo "⚠️  Warning: code/Dockerfile not found in $(pwd). Skipping frontend setup."
            SKIP_FRONTEND_START=true
        else
            # Check if port 3000 is available
            FRONTEND_PORT=3000
            if lsof -Pi :$FRONTEND_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
                echo "⚠️  Port $FRONTEND_PORT is already in use."
                # Check if it's a Docker container
                CONFLICTING_CONTAINER=$(docker ps --filter "publish=$FRONTEND_PORT" --format "{{.Names}}" | head -1)
                if [ -n "$CONFLICTING_CONTAINER" ]; then
                    echo "   Found Docker container using port: $CONFLICTING_CONTAINER"
                    echo "   Stopping conflicting container..."
                    docker stop "$CONFLICTING_CONTAINER" 2>/dev/null || true
                    docker rm "$CONFLICTING_CONTAINER" 2>/dev/null || true
                    sleep 2
                else
                    echo "   Port $FRONTEND_PORT is in use by a non-Docker process."
                    echo "   Skipping frontend startup."
                    SKIP_FRONTEND_START=true
                fi
            fi
            
            if [ "${SKIP_FRONTEND_START:-false}" != "true" ]; then
                # Build frontend Docker image
                echo "Building frontend Docker image..."
                docker build -t blob-frontend:latest \
                  --build-arg NEXT_PUBLIC_API_URL=http://localhost:$API_PORT \
                  -f code/Dockerfile ./code
                
                # Stop and remove existing frontend container if it exists
                docker stop blob-frontend 2>/dev/null || true
                docker rm blob-frontend 2>/dev/null || true
                
                # Run frontend container
                echo "Starting frontend container on port $FRONTEND_PORT..."
                docker run -d \
                  --name blob-frontend \
                  --network azurite-network \
                  -p $FRONTEND_PORT:3000 \
                  -e NEXT_PUBLIC_API_URL=http://localhost:$API_PORT \
                  blob-frontend:latest
                
                # Wait for frontend to be ready
                echo "Waiting for frontend to be ready..."
                sleep 8
                
                # Check if frontend is responding
                if curl -s http://localhost:$FRONTEND_PORT > /dev/null 2>&1; then
                    echo "✅ Frontend is running!"
                else
                    echo "⚠️  Frontend container started but may still be initializing..."
                    echo "   Check logs: docker logs -f blob-frontend"
                fi
            fi
        fi
    fi
    
    echo ""
    echo "Application is running!"
    echo ""
    echo "API: http://localhost:$API_PORT"
    if [ "${SKIP_FRONTEND:-false}" != "true" ] && [ "${SKIP_FRONTEND_START:-false}" != "true" ]; then
        echo "Frontend: http://localhost:3000"
    elif [ "${SKIP_FRONTEND:-false}" != "true" ]; then
        echo "Frontend: http://localhost:3000 (may already be running)"
    fi
    echo ""
    echo "View API logs: docker logs -f blob-manager"
    if [ "$USE_AZURITE" = true ]; then
        echo "View Azurite logs: docker logs -f azurite"
    fi
    if [ "${SKIP_FRONTEND:-false}" != "true" ] && [ "${SKIP_FRONTEND_START:-false}" != "true" ]; then
        echo "View frontend logs: docker logs -f blob-frontend"
    fi
    echo ""
    echo "🛑 Stop all services: docker stop blob-manager blob-frontend azurite 2>/dev/null || true"
    echo "Remove all containers: docker rm blob-manager blob-frontend azurite 2>/dev/null || true"
else
    echo "❌ Health check failed. Check logs with: docker logs blob-manager"
    exit 1
fi

#!/bin/bash

# Azure Blob Metadata Manager - One-Command Launcher
# This script builds and runs the Flask API in a Docker container

set -e  # Exit on error

echo "🚀 Azure Blob Metadata Manager - Starting..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "⚠️  Warning: .env file not found. Using default values (Azurite)."
    echo "   For production, create .env from .env.example"
    ENV_ARGS="-e AZURE_STORAGE_CONNECTION_STRING=UseDevelopmentStorage=true -e BLOB_CONTAINER=uploads"
else
    echo "✅ Using .env file for configuration"
    ENV_ARGS="--env-file .env"
fi

# Build the Docker image
echo "📦 Building Docker image..."
docker build -t blob-manager:latest -f web/Dockerfile ./web

# Stop and remove existing container if it exists
echo "🧹 Cleaning up existing containers..."
docker stop blob-manager 2>/dev/null || true
docker rm blob-manager 2>/dev/null || true

# Run the container
echo "🏃 Starting container..."
docker run -d \
  --name blob-manager \
  -p 5000:5000 \
  $ENV_ARGS \
  blob-manager:latest

# Wait for container to be ready
echo "⏳ Waiting for service to be ready..."
sleep 3

# Check health
echo "🏥 Checking health..."
if curl -s http://localhost:5000/health > /dev/null; then
    echo "✅ Service is healthy!"
    echo ""
    echo "🌐 API is running at: http://localhost:5000"
    echo "📋 Health check: curl http://localhost:5000/health"
    echo "📦 List blobs: curl http://localhost:5000/api/blobs"
    echo ""
    echo "📝 View logs: docker logs -f blob-manager"
    echo "🛑 Stop service: docker stop blob-manager"
else
    echo "❌ Health check failed. Check logs with: docker logs blob-manager"
    exit 1
fi


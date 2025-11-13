#!/bin/bash

# Azure Blob Metadata Manager - One-Command Launcher
# This script builds and runs the Flask API with Azurite (Azure Storage emulator) in Docker containers
# and starts the Next.js frontend

set -e  # Exit on error

# Track frontend process for cleanup
FRONTEND_PID=""

echo "🚀 Azure Blob Metadata Manager - Starting..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Error: Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Node.js package manager is installed (pnpm, npm, or yarn)
if command -v pnpm &> /dev/null; then
    PACKAGE_MANAGER="pnpm"
elif command -v npm &> /dev/null; then
    PACKAGE_MANAGER="npm"
elif command -v yarn &> /dev/null; then
    PACKAGE_MANAGER="yarn"
else
    echo "⚠️  Warning: No Node.js package manager (pnpm/npm/yarn) found."
    echo "   Frontend will not be started. Install Node.js to enable the frontend."
    SKIP_FRONTEND=true
fi

# Check if .env file exists and if it's using real Azure Storage
USE_AZURITE=true
ENV_ARGS=""
if [ -f .env ]; then
    if grep -q "blob.core.windows.net" .env 2>/dev/null; then
        echo "✅ Using .env file with real Azure Storage (skipping Azurite)"
        USE_AZURITE=false
        ENV_ARGS="--env-file .env"
    else
        echo "✅ Using .env file (will use Azurite if connection string points to it)"
        ENV_ARGS="--env-file .env"
        # Check if .env already has Azurite connection string
        if ! grep -q "UseDevelopmentStorage=true\|devstoreaccount1\|127.0.0.1:10000" .env 2>/dev/null; then
            # .env exists but doesn't specify Azurite, so we'll start it and override
            USE_AZURITE=true
        fi
    fi
else
    echo "⚠️  No .env file found. Using Azurite (Azure Storage emulator) for local testing."
    ENV_ARGS="-e BLOB_CONTAINER=uploads"
fi

# Start Azurite if needed
if [ "$USE_AZURITE" = true ]; then
    echo "📦 Starting Azurite (Azure Storage emulator)..."
    
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
    if [ -z "$ENV_ARGS" ] || [ "$ENV_ARGS" = "-e BLOB_CONTAINER=uploads" ]; then
        ENV_ARGS="-e AZURE_STORAGE_CONNECTION_STRING=$AZURITE_CONN_STR -e BLOB_CONTAINER=uploads"
    else
        # .env file exists, override the connection string
        ENV_ARGS="$ENV_ARGS -e AZURE_STORAGE_CONNECTION_STRING=$AZURITE_CONN_STR"
    fi
fi

# Build the Docker image
echo "📦 Building Flask API Docker image..."
docker build -t blob-manager:latest -f web/Dockerfile ./web

# Stop and remove existing container if it exists
echo "🧹 Cleaning up existing Flask API containers..."
docker stop blob-manager 2>/dev/null || true
docker rm blob-manager 2>/dev/null || true

# Allow API_PORT to be overridden via environment variable, default to 5000
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
            echo "   API_PORT=5001 ./run.sh"
            exit 1
        fi
    else
        echo "❌ Port $API_PORT is in use by a non-Docker process."
        echo "   On macOS, this might be AirPlay Receiver. You can disable it in:"
        echo "   System Settings > General > AirDrop & Handoff > AirPlay Receiver"
        echo ""
        echo "   Or use a different port by setting API_PORT environment variable:"
        echo "   API_PORT=5001 ./run.sh"
        exit 1
    fi
fi

# Run the Flask API container
echo "🏃 Starting Flask API container on port $API_PORT..."
if [ "$USE_AZURITE" = true ]; then
    # Connect to the same network as Azurite
    docker run -d \
      --name blob-manager \
      --network azurite-network \
      -p $API_PORT:5000 \
      $ENV_ARGS \
      blob-manager:latest
else
    # Use default network if not using Azurite
    docker run -d \
      --name blob-manager \
      -p $API_PORT:5000 \
      $ENV_ARGS \
      blob-manager:latest
fi

# Wait for container to be ready
echo "⏳ Waiting for Flask API to be ready..."
sleep 5

# Check health
echo "🏥 Checking API health..."
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
    
    # Check storage health if using Azurite
    if [ "$USE_AZURITE" = true ]; then
        echo "🏥 Checking storage connectivity..."
        sleep 2
        STORAGE_HEALTH=$(curl -s http://localhost:$API_PORT/health/storage || echo '{"ok":false}')
        if echo "$STORAGE_HEALTH" | grep -q '"ok":true'; then
            echo "✅ Storage is connected!"
        else
            echo "⚠️  Storage health check failed, but API is running. Storage operations may not work."
            echo "   This is normal if Azurite needs more time to initialize."
        fi
    fi
    
    echo ""
    echo "🎉 Backend is running!"
    echo ""
    echo "🌐 API is running at: http://localhost:$API_PORT"
    echo "📋 Health check: curl http://localhost:$API_PORT/health"
    echo "📦 List blobs: curl http://localhost:$API_PORT/api/blobs"
    if [ "$USE_AZURITE" = true ]; then
        echo "💾 Azurite is running on ports 10000-10002"
    fi
    
    # Setup and start frontend
    if [ "${SKIP_FRONTEND:-false}" != "true" ]; then
        echo ""
        echo "🎨 Setting up frontend..."
        
        # Check if frontend dependencies are installed
        if [ ! -d "code/node_modules" ]; then
            echo "📦 Installing frontend dependencies..."
            cd code
            if [ "$PACKAGE_MANAGER" = "pnpm" ]; then
                pnpm install || {
                    echo "❌ Failed to install frontend dependencies with pnpm"
                    cd ..
                    SKIP_FRONTEND_START=true
                }
            elif [ "$PACKAGE_MANAGER" = "npm" ]; then
                npm install || {
                    echo "❌ Failed to install frontend dependencies with npm"
                    cd ..
                    SKIP_FRONTEND_START=true
                }
            elif [ "$PACKAGE_MANAGER" = "yarn" ]; then
                yarn install || {
                    echo "❌ Failed to install frontend dependencies with yarn"
                    cd ..
                    SKIP_FRONTEND_START=true
                }
            fi
            # Make sure we're back in the project root
            cd ..
        else
            echo "✅ Frontend dependencies already installed"
        fi
        
        # Check if port 3000 is available
        FRONTEND_PORT=3000
        if lsof -Pi :$FRONTEND_PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
            echo "⚠️  Port $FRONTEND_PORT is already in use."
            # Try to find if it's a Next.js dev server
            EXISTING_PROCESS=$(lsof -ti :$FRONTEND_PORT)
            if [ -n "$EXISTING_PROCESS" ]; then
                echo "   Found process using port 3000. Frontend may already be running."
                echo "   If you want to restart it, stop the existing process first."
                SKIP_FRONTEND_START=true
            else
                echo "   Using existing frontend on port 3000"
                SKIP_FRONTEND_START=true
            fi
        fi
        
        if [ "${SKIP_FRONTEND_START:-false}" != "true" ]; then
            echo "🚀 Starting frontend dev server..."
            cd code
            # Start frontend in background and capture PID
            NEXT_PUBLIC_API_URL=http://localhost:$API_PORT $PACKAGE_MANAGER dev > /tmp/frontend.log 2>&1 &
            FRONTEND_PID=$!
            cd ..
            
            # Save PID to a file for later reference
            echo $FRONTEND_PID > /tmp/frontend.pid
            
            # Wait a bit for frontend to start
            echo "⏳ Waiting for frontend to start..."
            sleep 5
            
            # Check if frontend is running
            if ps -p $FRONTEND_PID > /dev/null 2>&1; then
                # Check if port 3000 is responding
                if curl -s http://localhost:3000 > /dev/null 2>&1; then
                    echo "✅ Frontend is running!"
                else
                    echo "⚠️  Frontend process started but may still be initializing..."
                    echo "   Check logs: tail -f /tmp/frontend.log"
                fi
            else
                echo "⚠️  Frontend failed to start. Check logs: cat /tmp/frontend.log"
                echo "   You can manually start it with: cd code && NEXT_PUBLIC_API_URL=http://localhost:$API_PORT $PACKAGE_MANAGER dev"
            fi
        fi
    fi
    
    echo ""
    echo "🎉 Application is running!"
    echo ""
    echo "🌐 API: http://localhost:$API_PORT"
    if [ "${SKIP_FRONTEND:-false}" != "true" ] && [ "${SKIP_FRONTEND_START:-false}" != "true" ] && [ -n "$FRONTEND_PID" ]; then
        echo "🎨 Frontend: http://localhost:3000"
    elif [ "${SKIP_FRONTEND:-false}" != "true" ]; then
        echo "🎨 Frontend: http://localhost:3000 (may already be running)"
    fi
    echo ""
    echo "📝 View API logs: docker logs -f blob-manager"
    if [ "$USE_AZURITE" = true ]; then
        echo "📝 View Azurite logs: docker logs -f azurite"
    fi
    if [ -n "$FRONTEND_PID" ]; then
        echo "📝 View frontend logs: tail -f /tmp/frontend.log"
        echo "🛑 Stop frontend: kill $FRONTEND_PID"
        echo "   Or: kill \$(cat /tmp/frontend.pid) 2>/dev/null || true"
    elif [ -f /tmp/frontend.pid ]; then
        echo "📝 View frontend logs: tail -f /tmp/frontend.log"
        echo "🛑 Stop frontend: kill \$(cat /tmp/frontend.pid) 2>/dev/null || true"
    fi
    echo "🛑 Stop all services: docker stop blob-manager azurite"
    echo "🧹 Remove all containers: docker rm blob-manager azurite"
else
    echo "❌ Health check failed. Check logs with: docker logs blob-manager"
    exit 1
fi

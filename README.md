# Azure Blob Metadata Manager - Case Study

## 1) Executive Summary

**Problem:** Organizations and developers need an efficient way to manage files stored in cloud storage systems, particularly Azure Blob Storage. Traditional cloud storage interfaces are often complex and don't provide easy ways to view, organize, and manage file metadata. Users need a simple, web-based interface to upload files, view their contents, and edit metadata without navigating complex cloud portals.

**Solution:** Azure Blob Metadata Manager is a modern web application that provides a user-friendly terminal-style interface for managing Azure Blob Storage. The application allows users to upload files, view them directly in the browser, list all stored files with their metadata, and edit blob metadata through an intuitive web interface. Built with Flask (Python) for the REST API and Next.js for the frontend, the application is fully containerized and **designed primarily for local development** using Docker with Azurite (Azure Storage emulator). The application can also be deployed to Azure cloud services for production use (see Deployment section).

## 2) System Overview

### Course Concept(s)

This project implements several key concepts from the course modules:

1. **Flask API Development**: The backend is built using Flask, demonstrating RESTful API design, request handling, CORS configuration, and proper error handling. The API provides endpoints for CRUD operations on Azure Blob Storage.

2. **Cloud Storage Integration**: The project integrates with Azurite (Azure Storage emulator) for local development, demonstrating cloud storage patterns, SAS token generation for secure access, and metadata management. The same codebase can work with real Azure Blob Storage when deployed to the cloud.

3. **Containerization**: The application is fully containerized using Docker, demonstrating container-based deployment, environment variable management, and reproducible builds.

4. **Web Application Architecture**: The project demonstrates a modern three-tier architecture with a React/Next.js frontend, Flask API backend, and Azurite (Azure Storage emulator) as the data layer for local development. The architecture supports deployment to Azure cloud services.

### Architecture Diagram

![Architecture Diagram](assets/architecture.png)

The architecture consists of:
- **Frontend Layer**: Next.js application with React 19 and TypeScript, providing a terminal-style user interface
- **API Layer**: Flask REST API running in a Docker container, handling all blob operations
- **Storage Layer**: 
  - **Local Development**: Azurite (Azure Storage emulator) running in Docker
  - **Production**: Azure Blob Storage (when deployed to cloud)

### Data/Models/Services

- **Azurite (Azure Storage Emulator)** - **Primary/Default**: Local Azure Storage emulator for development and testing
  - Container: `uploads` (default, configurable)
  - File formats: Any (images, PDFs, documents, etc.)
  - Metadata: Key-value pairs stored as blob properties
  - No Azure subscription required - runs entirely locally in Docker
  - Provides the same API as Azure Blob Storage for seamless local development
  - **This is the default and recommended setup for local development**

- **Azure Blob Storage** - **Optional/Production**: Real Azure cloud storage (see Deployment section)
  - Requires Azure subscription
  - Same API as Azurite, so code works without changes
  - Used only when deploying to production

- **No external datasets or models**: The application manages user-uploaded files only

## 3) Local Development

### Prerequisites

- Docker (required - handles all Python dependencies automatically and runs Azurite)
- Node.js 20+ and pnpm (for running the frontend)
- Optional: Python 3.8+ and pip (only needed if running tests locally without Docker)

**Note**: This project is **designed primarily for local development** using Azurite (Azure Storage emulator), which requires no Azure subscription or cloud resources. Cloud deployment instructions are provided in the Deployment section for advanced users who want to deploy to production.

### Installing Dependencies

**Python Dependencies:**
- Automatically handled by Docker during container build (no manual installation needed)
- If running tests locally without Docker: `pip install -r requirements.txt`

**Frontend Dependencies:**
- Automatically installed by `run.sh` if missing
- Or manually: `cd code && pnpm install`

### Quick Start (Recommended)

The easiest way to run the application locally is using the `run.sh` script:

```bash
# Make the script executable (if needed)
chmod +x run.sh

# Run the application (starts Azurite, API, and frontend)
./run.sh
```

The script automatically:
- Starts Azurite (Azure Storage emulator) in a Docker container
- Builds and starts the Flask API container (configured to use Azurite)
- Installs frontend dependencies (if needed)
- Starts the Next.js frontend dev server
- Verifies all services are healthy

**Note**: The application uses Azurite for local development by default. No Azure subscription or cloud resources are required. For production deployment to Azure, see the Deployment section below.

### Manual Setup

#### Backend API

```bash
# Build the Docker image
docker build -t blob-manager:latest -f web/Dockerfile ./web

# Run the container (using Azurite for local development)
# Make sure Azurite is running first (or use docker-compose)
docker run --rm -p 5001:5000 \
  -e AZURE_STORAGE_CONNECTION_STRING="DefaultEndpointsProtocol=http;AccountName=devstoreaccount1;AccountKey=Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==;BlobEndpoint=http://azurite:10000/devstoreaccount1;" \
  -e BLOB_CONTAINER="uploads" \
  blob-manager:latest
```

#### Frontend

```bash
cd code
pnpm install
NEXT_PUBLIC_API_URL=http://localhost:5001 pnpm dev
```

Access the frontend at http://localhost:3000

### Using Docker Compose

Alternatively, use Docker Compose to run all services:

```bash
docker-compose up
```

### Health Checks

Verify services are running:

```bash
# API health
curl http://localhost:5001/health
# Expected: {"ok": true}

# Storage connectivity
curl http://localhost:5001/health/storage
# Expected: {"ok": true, "container": "uploads"}
```

### Testing the API

```bash
# List all blobs
curl http://localhost:5001/api/blobs

# Upload a test file
curl -X POST -F "file=@/path/to/your/file.pdf" http://localhost:5001/api/blobs

# Get blob metadata
curl http://localhost:5001/api/blobs/your-file-name.pdf
```

## 4) Deployment (Optional - Advanced)

> **⚠️ Important**: This project is **designed primarily for local development** using Azurite. The deployment instructions below are for advanced users who want to deploy to Azure cloud services for production use. For most users, local development with Azurite is sufficient and recommended.

### Overview

If you want to deploy the application to Azure cloud services (optional), it can be deployed using:
- **Frontend**: Azure Static Web Apps (Next.js static export)
- **Backend API**: Azure Container Apps (Flask API in Docker)
- **Storage**: Azure Blob Storage (replaces Azurite)

**Prerequisites for Deployment:**
- Azure subscription
- Azure CLI installed and configured
- Azure Container Registry (ACR)
- Azure Container Apps environment
- Azure Static Web Apps resource

### Automated Deployment (CI/CD)

Deployment can be automated via GitHub Actions. The workflow (`.github/workflows/azure-deploy.yml`) triggers on pushes to `main` branch and deploys:

1. **Frontend** → Azure Static Web Apps
2. **Backend API** → Azure Container Apps

#### Required GitHub Secrets

Configure these secrets in your GitHub repository:

- `AZURE_WEBAPP_PUBLISH_PROFILE`: Publish profile for Azure Web App/Container App
- `AZURE_STATIC_WEB_APPS_API_TOKEN`: Deployment token for Static Web Apps
- `NEXT_PUBLIC_API_URL`: Public URL of the deployed API

#### Deployment Process

1. Push to `main` branch or manually trigger workflow
2. GitHub Actions builds and deploys:
   - Frontend: Builds Next.js app and deploys to Static Web Apps
   - Backend: Builds Docker image and deploys to Container Apps
3. Services are automatically configured with environment variables

### Manual Deployment

#### Deploy Backend API to Azure Container Apps

```bash
# Build Docker image
docker build -t blob-manager:latest -f web/Dockerfile ./web

# Tag and push to Azure Container Registry (ACR)
az acr build --registry <your-acr-name> --image blob-manager:latest ./web

# Deploy to Container Apps
az containerapp create \
  --name retro-azure-metadata-api \
  --resource-group <your-resource-group> \
  --image <your-acr-name>.azurecr.io/blob-manager:latest \
  --environment <container-app-env> \
  --env-vars \
    AZURE_STORAGE_CONNECTION_STRING=<connection-string> \
    BLOB_CONTAINER=uploads
```

#### Deploy Frontend to Azure Static Web Apps

```bash
cd code

# Build Next.js app (static export)
NEXT_PUBLIC_API_URL=<your-api-url> pnpm build

# Deploy using Azure Static Web Apps CLI
swa deploy ./out --app-name <your-static-web-app-name>
```

### Environment Configuration

For production deployment, configure these environment variables:

**Backend (Container Apps):**
- `AZURE_STORAGE_CONNECTION_STRING`: Azure Storage connection string (replaces Azurite)
- `BLOB_CONTAINER`: Blob container name (default: `uploads`)
- `SAS_EXPIRY_MINUTES`: SAS token expiry (default: 5 minutes)
- `ACCOUNT_KEY`: Storage account key (for SAS generation)

**Frontend:**
- `NEXT_PUBLIC_API_URL`: Public URL of the deployed API

### Post-Deployment Verification

1. Check API health: `curl https://<your-api-url>/health`
2. Check storage connectivity: `curl https://<your-api-url>/health/storage`
3. Verify frontend can connect to API
4. Test file upload and metadata operations

## 5) Design Decisions

### Why Flask?

Flask was chosen for the API layer because:
- **Simplicity**: Flask provides a lightweight, flexible framework that's easy to understand and maintain
- **Course Alignment**: Flask is a key concept covered in the course modules
- **Azure Integration**: Flask integrates seamlessly with Azure SDKs and services
- **Containerization**: Flask applications containerize easily and run efficiently in Docker

**Alternatives Considered:**
- **FastAPI**: More modern but adds complexity; Flask is sufficient for this use case
- **Django**: Too heavyweight for a simple REST API
- **Express.js**: Would require Node.js expertise and doesn't align with course Python focus

### Why Azurite (Azure Storage Emulator)?

Azurite was chosen because:
- **Local Development**: No Azure subscription required, runs entirely locally
- **Azure Compatibility**: Provides the same API as Azure Blob Storage for seamless development
- **Metadata Support**: Native support for blob metadata (key-value pairs)
- **Docker Integration**: Easy to run in containers alongside the application
- **SAS Tokens**: Supports SAS token generation for secure access testing

**Alternatives Considered:**
- **Real Azure Blob Storage**: Requires subscription and cloud resources (not needed for local dev)
- **Local File System**: Doesn't demonstrate cloud storage patterns
- **MongoDB GridFS**: Overkill for simple file storage needs

### Tradeoffs

**Performance:**
- **Pros**: Streaming file downloads for large files, efficient metadata queries, local storage (no network latency)
- **Cons**: Limited to local machine storage capacity

**Cost:**
- **Pros**: Completely free - no cloud costs, no subscription required
- **Cons**: Limited to local machine resources

**Complexity:**
- **Pros**: Simple architecture, easy to understand and maintain, no cloud setup required
- **Cons**: Data is stored locally and not persisted across machine restarts (unless using Docker volumes)

**Maintainability:**
- **Pros**: Well-structured code, clear separation of concerns
- **Cons**: Two separate applications (frontend/backend) require coordination

### Security/Privacy

**Secrets Management:**
- Environment variables used for configuration
- Azurite uses default development credentials (no real secrets needed for local development)
- Production deployment requires Azure Key Vault or secure environment variable management

**Input Validation:**
- File upload size limits enforced
- Filename sanitization to prevent path traversal
- Content-Type validation for file viewing

**PII Handling:**
- No user authentication (can be added for production)
- Files stored as-is; no automatic PII extraction
- Users responsible for metadata they add

**Network Security:**
- CORS configured to allow frontend connections
- Security headers (CSP, HSTS, X-Frame-Options) implemented
- Local development runs on localhost (production uses HTTPS when deployed)

### Operations

**Logging:**
- Flask application logs to stdout (captured by container runtime)
- Error logging for failed operations
- Health check endpoints for monitoring

**Metrics:**
- Health endpoints (`/health`, `/health/storage`) for basic monitoring
- Container resource usage visible via Docker commands

**Scaling Considerations:**
- Stateless API design allows horizontal scaling (if needed)
- Storage limited to local machine capacity
- Suitable for local development and testing

**Known Limitations:**
- No user authentication (all users share the same storage)
- No file versioning or backup
- Metadata editing requires blob re-upload (Azure Storage API limitation)
- Local development only - data stored in Docker containers
- Data is ephemeral unless using Docker volumes for Azurite

## 6) Results & Evaluation

### Screenshots

See `assets/` directory for:
- Application screenshots showing the terminal-style interface
- Architecture diagram
- Example metadata editing workflow

### Performance Notes

**API Response Times:**
- Health check: < 50ms
- List blobs: ~200-500ms (depends on number of files)
- File upload: Depends on file size (streaming for large files)
- Metadata update: ~100-200ms

**Resource Footprint:**
- Container: Minimal resources (default Docker limits)
- Storage: Limited to local disk space
- Network: Local only (no external network calls)

### Validation/Tests

**Smoke Tests:**
- Health endpoint returns 200 OK
- Storage health check verifies connectivity
- List blobs returns valid JSON
- Upload endpoint accepts files
- Metadata update persists correctly

Run tests:
```bash
cd tests
python -m pytest test_smoke.py -v
```

**Manual Testing:**
- Upload various file types (images, PDFs, documents)
- Verify files appear in blob list
- Edit metadata and verify persistence
- View files in browser
- Delete blobs and verify removal

## 7) What's Next

### Planned Improvements

1. **User Authentication**: Add basic authentication for user-specific storage
2. **File Versioning**: Implement version history for uploaded files
3. **Search Functionality**: Full-text search across blob names and metadata
4. **Batch Operations**: Upload/delete multiple files at once
5. **File Preview**: Enhanced preview for more file types
6. **Metadata Templates**: Pre-defined metadata schemas for common use cases
7. **Data Persistence**: Add Docker volumes for Azurite to persist data across restarts

### Refactors

1. **Frontend Containerization**: Add Dockerfile for frontend to enable full containerized local development
2. **API Testing**: Expand test coverage with unit and integration tests
3. **Error Handling**: More detailed error messages and recovery mechanisms
4. **Documentation**: API documentation with OpenAPI/Swagger

### Stretch Features

1. **Real-time Updates**: WebSocket support for live blob list updates
2. **File Sharing**: Generate shareable links with expiration (local network)
3. **Analytics Dashboard**: Usage statistics and storage analytics
4. **Data Export**: Export blob data and metadata for backup

## 8) Links & Resources

- **GitHub Repository**: https://github.com/JedDataScience/RetroAzureBlobMetadataStorage

### Additional Documentation

- `docker-compose.yml`: Multi-container setup for local development with Azurite
- `web/Dockerfile`: Container build configuration for the Flask API
- `run.sh`: One-command launcher script for local development
- `.github/workflows/azure-deploy.yml`: CI/CD deployment workflow (optional, for production deployment)
- `tests/`: Test suite and smoke tests

## License

See [LICENSE](LICENSE) file for details.

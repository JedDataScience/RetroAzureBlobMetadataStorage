# Azure Blob Metadata Manager - Case Study

## 1) Executive Summary

**Problem:** Organizations and developers need an efficient way to manage files stored in cloud storage systems, particularly Azure Blob Storage. Traditional cloud storage interfaces are often complex and don't provide easy ways to view, organize, and manage file metadata. Users need a simple, web-based interface to upload files, view their contents, and edit metadata without navigating complex cloud portals.

**Solution:** Azure Blob Metadata Manager is a modern web application that provides a user-friendly terminal-style interface for managing Azure Blob Storage. The application allows users to upload files, view them directly in the browser, list all stored files with their metadata, and edit blob metadata through an intuitive web interface. Built with Flask (Python) for the REST API and Next.js for the frontend, the application is fully containerized and can run locally with Docker or be deployed to Azure cloud services.

## 2) System Overview

### Course Concept(s)

This project implements several key concepts from the course modules:

1. **Flask API Development**: The backend is built using Flask, demonstrating RESTful API design, request handling, CORS configuration, and proper error handling. The API provides endpoints for CRUD operations on Azure Blob Storage.

2. **Cloud Storage Integration**: The project integrates with Azure Blob Storage, demonstrating cloud-native data storage patterns, SAS token generation for secure access, and metadata management.

3. **Containerization**: The application is fully containerized using Docker, demonstrating container-based deployment, environment variable management, and reproducible builds.

4. **Web Application Architecture**: The project demonstrates a modern three-tier architecture with a React/Next.js frontend, Flask API backend, and Azure Blob Storage as the data layer.

### Architecture Diagram

![Architecture Diagram](assets/architecture.png)

The architecture consists of:
- **Frontend Layer**: Next.js application with React 19 and TypeScript, providing a terminal-style user interface
- **API Layer**: Flask REST API running in a Docker container, handling all blob operations
- **Storage Layer**: Azure Blob Storage for persistent file storage with metadata support

### Data/Models/Services

- **Azure Blob Storage**: Cloud storage service for file persistence
  - Container: `uploads` (default, configurable)
  - File formats: Any (images, PDFs, documents, etc.)
  - Metadata: Key-value pairs stored as blob properties
  - License: Azure Storage service (requires Azure subscription)

- **Sample Data**: For local testing, the application can use Azurite (Azure Storage emulator) which requires no external dependencies

- **No external datasets or models**: The application manages user-uploaded files only

## 3) How to Run (Local)

### Docker

The application can be run with a single Docker command:

```bash
# Build the Docker image
docker build -t blob-manager:latest -f web/Dockerfile ./web

# Run the container (using Azurite connection string for local testing)
docker run --rm -p 5000:5000 \
  -e AZURE_STORAGE_CONNECTION_STRING="UseDevelopmentStorage=true" \
  -e BLOB_CONTAINER="uploads" \
  blob-manager:latest
```

**Note**: For local testing without Azure Storage, you can use Azurite (Azure Storage emulator). See `AZURE_SETUP.md` for instructions on setting up Azurite or real Azure Storage.

**Alternative: Using run.sh script**

```bash
# Make the script executable
chmod +x run.sh

# Run the application
./run.sh
```

### Health Check

Once the container is running, verify it's working:

```bash
# Check health endpoint
curl http://localhost:5000/health

# Expected response: {"ok": true}

# Check storage health
curl http://localhost:5000/health/storage

# Expected response: {"ok": true, "container": "uploads"}
```

### Testing the API

```bash
# List all blobs
curl http://localhost:5000/api/blobs

# Upload a test file
curl -X POST -F "file=@/path/to/your/file.pdf" http://localhost:5000/api/blobs

# Get blob metadata
curl http://localhost:5000/api/blobs/your-file-name.pdf
```

### Frontend (Optional - for full application)

The frontend requires Node.js and can be run separately:

```bash
cd code
pnpm install
NEXT_PUBLIC_API_URL=http://localhost:5000 pnpm dev
```

Access the frontend at http://localhost:3000

## 4) Design Decisions

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

### Why Azure Blob Storage?

Azure Blob Storage was chosen because:
- **Cloud-Native**: Demonstrates cloud storage patterns and integration
- **Metadata Support**: Native support for blob metadata (key-value pairs)
- **Scalability**: Handles files of any size efficiently
- **SAS Tokens**: Built-in secure access mechanism for file viewing

**Alternatives Considered:**
- **AWS S3**: Similar functionality but Azure aligns with course cloud focus
- **Local File System**: Not suitable for cloud deployment demonstration
- **MongoDB GridFS**: Overkill for simple file storage needs

### Tradeoffs

**Performance:**
- **Pros**: Streaming file downloads for large files, efficient metadata queries
- **Cons**: Network latency for cloud storage (mitigated by Azure's global CDN)

**Cost:**
- **Pros**: Pay-as-you-go pricing, minimal cost for small-scale usage
- **Cons**: Can scale up with usage (addressed with cost management scripts)

**Complexity:**
- **Pros**: Simple architecture, easy to understand and maintain
- **Cons**: Requires Azure account setup (mitigated with Azurite for local testing)

**Maintainability:**
- **Pros**: Well-structured code, clear separation of concerns
- **Cons**: Two separate applications (frontend/backend) require coordination

### Security/Privacy

**Secrets Management:**
- Environment variables used for sensitive data (connection strings, keys)
- `.env.example` provided as template (no secrets committed)
- Azure Key Vault recommended for production deployments

**Input Validation:**
- File upload size limits enforced
- Filename sanitization to prevent path traversal
- Content-Type validation for file viewing

**PII Handling:**
- No user authentication (can be added for production)
- Files stored as-is; no automatic PII extraction
- Users responsible for metadata they add

**Network Security:**
- HTTPS enforced in production (Azure Container Apps)
- CORS configured to restrict frontend origins
- Security headers (CSP, HSTS, X-Frame-Options) implemented

### Operations

**Logging:**
- Flask application logs to stdout (captured by container runtime)
- Error logging for failed operations
- Health check endpoints for monitoring

**Metrics:**
- Health endpoints (`/health`, `/health/storage`) for basic monitoring
- Container resource usage visible in Azure Portal
- Can be extended with Application Insights

**Scaling Considerations:**
- Container Apps support auto-scaling (0 to N replicas)
- Stateless API design allows horizontal scaling
- Storage layer scales independently

**Known Limitations:**
- No user authentication (all users share the same storage)
- No file versioning or backup
- Metadata editing requires blob re-upload (Azure limitation)
- Frontend requires separate deployment (not included in single Docker command)

## 5) Results & Evaluation

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
- Container: 1 CPU, 2GB RAM (configurable)
- Storage: Pay-per-GB stored
- Network: Minimal (API calls only)

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

See `TESTING.md` for detailed testing procedures.

## 6) What's Next

### Planned Improvements

1. **User Authentication**: Add Azure AD integration for user-specific storage
2. **File Versioning**: Implement version history for uploaded files
3. **Search Functionality**: Full-text search across blob names and metadata
4. **Batch Operations**: Upload/delete multiple files at once
5. **File Preview**: Enhanced preview for more file types
6. **Metadata Templates**: Pre-defined metadata schemas for common use cases

### Refactors

1. **Frontend Containerization**: Add Dockerfile for frontend to enable full containerized deployment
2. **API Testing**: Expand test coverage with unit and integration tests
3. **Error Handling**: More detailed error messages and recovery mechanisms
4. **Documentation**: API documentation with OpenAPI/Swagger

### Stretch Features

1. **Real-time Updates**: WebSocket support for live blob list updates
2. **File Sharing**: Generate shareable links with expiration
3. **Analytics Dashboard**: Usage statistics and storage analytics
4. **Multi-cloud Support**: Extend to support AWS S3 and Google Cloud Storage

## 7) Links

- **GitHub Repo**: [INSERT-YOUR-REPO-URL]
- **Public Cloud App**: 
  - Frontend: https://victorious-wave-0fd8b771e.3.azurestaticapps.net
  - API: https://retro-azure-metadata-api.wonderfulisland-bcb9cf0e.westus2.azurecontainerapps.io

---

## Additional Documentation

- `AZURE_SETUP.md`: Detailed Azure Storage setup instructions
- `TESTING.md`: Comprehensive testing guide
- `docker-compose.yml`: Multi-container setup for local development
- `web/Dockerfile`: Container build configuration

## License

See [LICENSE](LICENSE) file for details.

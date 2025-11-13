# Assets

This directory contains diagrams, screenshots, and other visual assets for the project.

## Required Files

### architecture.png
Architecture diagram showing the system components and data flow.

**To create:**
1. Use a diagramming tool (draw.io, Lucidchart, or similar)
2. Include:
   - Frontend (Next.js) layer
   - API (Flask) layer
   - Storage (Azure Blob Storage) layer
   - Data flow arrows
   - Container boundaries
3. Export as PNG
4. Save as `architecture.png`

### Screenshots (Optional but Recommended)

- `screenshot-main.png` - Main application interface
- `screenshot-upload.png` - File upload interface
- `screenshot-metadata.png` - Metadata editing interface

## Quick Architecture Diagram Description

```
┌─────────────────────────────────────┐
│   User Browser                      │
│   (Next.js Frontend)                │
└──────────────┬──────────────────────┘
               │ HTTPS
               ▼
┌─────────────────────────────────────┐
│   Flask REST API                    │
│   (Docker Container)                │
│   - /api/blobs                      │
│   - /api/blobs/<name>               │
│   - /health                         │
└──────────────┬──────────────────────┘
               │ Azure SDK
               ▼
┌─────────────────────────────────────┐
│   Azure Blob Storage                │
│   - Container: uploads              │
│   - Blobs with metadata             │
└─────────────────────────────────────┘
```


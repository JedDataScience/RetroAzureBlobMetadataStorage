import os
import signal
import logging
import mimetypes
from datetime import datetime, timedelta, timezone
from urllib.parse import quote
from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from azure.storage.blob import BlobServiceClient, BlobSasPermissions, generate_blob_sas, ContentSettings

app = Flask(__name__)
CORS(app)  # Enable CORS for Next.js frontend
# Support either FLASK_SECRET (example) or FLASK_SECRET_KEY (prior scaffold)
app.secret_key = os.getenv("FLASK_SECRET") or os.getenv("FLASK_SECRET_KEY", "dev-secret")

# Add Content-Security-Policy header to upgrade insecure requests to HTTPS
# This prevents mixed content issues by automatically upgrading HTTP requests to HTTPS
@app.after_request
def add_security_headers(response):
    """Add security headers to all responses."""
    # Upgrade insecure requests (HTTP to HTTPS) to prevent mixed content
    # Allow all same-origin resources and upgrade insecure requests
    # This is permissive enough for the API to work while still upgrading HTTP to HTTPS
    csp_policy = (
        "default-src 'self'; "
        "script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
        "style-src 'self' 'unsafe-inline'; "
        "img-src 'self' data: https:; "
        "font-src 'self' data:; "
        "connect-src 'self' https:; "
        "frame-ancestors 'none'; "
        "upgrade-insecure-requests;"
    )
    response.headers['Content-Security-Policy'] = csp_policy
    # Additional security headers
    response.headers['X-Content-Type-Options'] = "nosniff"
    response.headers['X-Frame-Options'] = "DENY"
    response.headers['X-XSS-Protection'] = "1; mode=block"
    # Strict-Transport-Security (HSTS) - force HTTPS for 1 year
    response.headers['Strict-Transport-Security'] = "max-age=31536000; includeSubDomains"
    return response


def _parse_conn_str(conn: str) -> dict:
    try:
        return dict(p.split("=", 1) for p in conn.split(";") if "=" in p)
    except Exception:
        return {}


def is_azurite():
    cs = os.getenv("AZURE_STORAGE_CONNECTION_STRING", "")
    if cs.startswith("UseDevelopmentStorage=true"):
        return True
    parts = _parse_conn_str(cs)
    acct = (parts.get("AccountName") or parts.get("accountname") or "").lower()
    blob_ep = (parts.get("BlobEndpoint") or parts.get("blobendpoint") or "").lower()
    return acct == "devstoreaccount1" or ("azurite" in blob_ep) or ("127.0.0.1:10000" in blob_ep)


def bsc() -> BlobServiceClient:
    # Use reasonable retries and timeouts for better performance
    return BlobServiceClient.from_connection_string(
        os.getenv("AZURE_STORAGE_CONNECTION_STRING"),
        retry_total=3,
        retry_mode="exponential",
        retry_backoff_factor=0.5,
        connection_timeout=10,
        read_timeout=30,
    )


def blob_base_url(account_name: str) -> str:
    """
    Generate blob base URL for Azure Storage.
    In production, always uses HTTPS. Only uses HTTP for local Azurite.
    """
    # Allow an explicit public base override (useful when running Azurite on a custom host/port)
    public_base = os.getenv("PUBLIC_BLOB_BASE_URL")
    if public_base:
        # Ensure the public base URL uses HTTPS in production (unless explicitly HTTP for Azurite)
        if not public_base.startswith(('http://', 'https://')):
            # If no protocol, assume HTTPS for production
            return f"https://{public_base.rstrip('/')}/{account_name}"
        # If HTTP is specified, only allow it for localhost (Azurite)
        if public_base.startswith('http://') and 'localhost' not in public_base and '127.0.0.1' not in public_base:
            # Force HTTPS for non-localhost URLs in production
            return public_base.replace('http://', 'https://', 1).rstrip('/') + f"/{account_name}"
        return f"{public_base.rstrip('/')}/{account_name}"
    
    # Check if we're in production (Azure) or local development (Azurite)
    # In production, Azure Storage always uses HTTPS
    # Only use HTTP for local Azurite development
    
    # First, check if we're running in Azure (Container Apps, App Service, etc.)
    # Container Apps sets CONTAINER_APP_NAME, CONTAINER_APP_ENV_DNS_SUFFIX, etc.
    is_azure_production = (
        os.getenv("CONTAINER_APP_NAME") or 
        os.getenv("CONTAINER_APP_ENV_DNS_SUFFIX") or
        os.getenv("WEBSITE_SITE_NAME") or 
        os.getenv("WEBSITE_INSTANCE_ID") or
        os.getenv("APPSETTING_WEBSITE_SITE_NAME") or
        # Check if connection string contains blob.core.windows.net (Azure Storage, not Azurite)
        "blob.core.windows.net" in (os.getenv("AZURE_STORAGE_CONNECTION_STRING", "") or "").lower()
    )
    
    # Check if it's actually Azurite (local development)
    is_local_azurite = is_azurite()
    
    # Only use HTTP for local Azurite development when NOT in Azure production
    if is_local_azurite and not is_azure_production:
        # Local Azurite development - use HTTP
        host_port = os.getenv("AZURITE_BLOB_HOST_PORT", "10000")
        return f"http://127.0.0.1:{host_port}/{account_name}"
    
    # Production (Azure) or any non-Azurite environment: Always use HTTPS
    # This ensures we never return HTTP URLs in production, even if is_azurite() is somehow True
    return f"https://{account_name}.blob.core.windows.net"


def make_sas(container: str, blob: str, minutes: int | None = None) -> str:
    service = bsc()
    account_name = service.account_name
    # Allow override via env, default to 5 minutes
    minutes = minutes or int(os.getenv("SAS_EXPIRY_MINUTES", "5"))
    expiry = datetime.now(timezone.utc) + timedelta(minutes=minutes)
    # dev only: account key. In prod, use User Delegation SAS (Managed Identity)
    sas = generate_blob_sas(
        account_name=account_name,
        container_name=container,
        blob_name=blob,
        account_key=(os.getenv("ACCOUNT_KEY") or _account_key_from_conn_str(os.getenv("AZURE_STORAGE_CONNECTION_STRING", ""))),
        permission=BlobSasPermissions(read=True),
        expiry=expiry
    )
    return f"{blob_base_url(account_name)}/{container}/{quote(blob)}?{sas}"


def ensure_container_exists(container_name: str):
    """Ensure the container exists; create it if missing."""
    svc = bsc()
    cc = svc.get_container_client(container_name)
    try:
        # Check if container exists (with reasonable timeout)
        cc.get_container_properties()
        # For Azurite local testing, make container public for easier access
        if is_azurite():
            try:
                cc.set_container_access_policy(public_access="blob")
            except Exception:
                pass  # Ignore if setting public access fails
    except Exception:
        try:
            # Create container if it doesn't exist
            cc.create_container()
            # Make container public for Azurite
            if is_azurite():
                try:
                    cc.set_container_access_policy(public_access="blob")
                except Exception:
                    pass
        except Exception:
            pass  # Container might already exist or creation failed
    return cc


def _run_with_timeout(seconds: int, func, *args, **kwargs):
    """Run func with a simple SIGALRM timeout (Linux-only). Raises TimeoutError on expiry."""
    # Increase timeout for container instances which may have slower startup
    def handler(signum, frame):
        raise TimeoutError("operation timed out")
    old = signal.signal(signal.SIGALRM, handler)
    signal.alarm(seconds)
    try:
        return func(*args, **kwargs)
    finally:
        signal.alarm(0)
        signal.signal(signal.SIGALRM, old)


@app.get("/")
def index():
    """Redirect root to API docs or return API info."""
    return jsonify({
        "message": "Azure Blob Metadata API",
        "version": "2.0",
        "endpoints": {
            "list_blobs": "GET /api/blobs",
            "get_blob": "GET /api/blobs/<name>",
            "upload_blob": "POST /api/blobs",
            "update_metadata": "PUT /api/blobs/<name>/metadata",
            "delete_blob": "DELETE /api/blobs/<name>",
            "get_blob_url": "GET /api/blobs/<name>/url",
            "view_blob": "GET /api/blobs/<name>/view"
        }
    })


@app.get("/api/blobs")
def api_list_blobs():
    """API endpoint to list all blobs."""
    try:
        service = bsc()
        container_name = os.getenv("BLOB_CONTAINER", os.getenv("AZURE_STORAGE_CONTAINER", "uploads"))
        container = ensure_container_exists(container_name)
        
        blobs = []
        include = ["metadata"] if is_azurite() else ["metadata", "tags"]
        for blob in container.list_blobs(include=include):
            md = blob.metadata or {}
            # Convert datetime to ISO format string
            last_modified = blob.last_modified.isoformat() if blob.last_modified else None
            
            # Get content settings from blob properties (list_blobs includes some properties)
            content_type = md.get("mime_type") or ""
            if hasattr(blob, "content_settings") and blob.content_settings:
                content_type = content_type or blob.content_settings.content_type or ""
                content_encoding = blob.content_settings.content_encoding or ""
                content_language = blob.content_settings.content_language or ""
                cache_control = blob.content_settings.cache_control or ""
            else:
                content_encoding = ""
                content_language = ""
                cache_control = ""
            
            # Get blob type (usually BlockBlob for most files)
            blob_type = getattr(blob, "blob_type", "BlockBlob") or "BlockBlob"
            
            # Get etag if available
            etag = getattr(blob, "etag", None) or None
            
            blob_item = {
                "id": blob.name,  # Use blob name as ID
                "name": blob.name.split("/")[-1],
                "size": blob.size or 0,
                "type": content_type,
                "lastModified": last_modified,
                "metadata": md,
                "blob_path": f"{container_name}/{blob.name}",
                # Additional metadata fields
                "etag": etag,
                "contentType": content_type,
                "contentEncoding": content_encoding,
                "contentLanguage": content_language,
                "cacheControl": cache_control,
                "blobType": blob_type,
            }
            blobs.append(blob_item)
        
        return jsonify({"blobs": blobs})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.get("/api/blobs/<path:blob_name>")
def api_get_blob(blob_name):
    """API endpoint to get a specific blob."""
    try:
        service = bsc()
        container_name = os.getenv("BLOB_CONTAINER", os.getenv("AZURE_STORAGE_CONTAINER", "uploads"))
        blob_client = service.get_blob_client(container=container_name, blob=blob_name)
        props = blob_client.get_blob_properties()
        content_settings = props.content_settings or {}
        
        md = props.metadata or {}
        last_modified = props.last_modified.isoformat() if props.last_modified else None
        
        blob_item = {
            "id": blob_name,
            "name": blob_name.split("/")[-1],
            "size": props.size or 0,
            "type": md.get("mime_type") or content_settings.get("content_type") or "",
            "lastModified": last_modified,
            "metadata": md,
            "blob_path": f"{container_name}/{blob_name}",
            # Additional metadata fields
            "etag": props.etag if props.etag else None,
            "contentType": content_settings.get("content_type") or md.get("mime_type") or "",
            "contentEncoding": content_settings.get("content_encoding") or "",
            "contentLanguage": content_settings.get("content_language") or "",
            "cacheControl": content_settings.get("cache_control") or "",
            "blobType": getattr(props, "blob_type", None) or "BlockBlob",
            "creationTime": props.creation_time.isoformat() if props.creation_time else None,
        }
        
        return jsonify(blob_item)
    except Exception as e:
        return jsonify({"error": str(e)}), 404


@app.post("/api/blobs")
def api_upload_blob():
    """API endpoint to upload a blob."""
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400
    
    f = request.files["file"]
    if not f.filename:
        return jsonify({"error": "Empty filename"}), 400
    
    try:
        service = bsc()
        container_name = os.getenv("BLOB_CONTAINER", os.getenv("AZURE_STORAGE_CONTAINER", "uploads"))
        ensure_container_exists(container_name)
        blob_client = service.get_blob_client(container=container_name, blob=f.filename)
        
        # Determine content type from file extension
        content_type, _ = mimetypes.guess_type(f.filename)
        if not content_type:
            content_type = f.content_type or "application/octet-stream"
        
        # Upload with content type settings
        content_settings = ContentSettings(content_type=content_type)
        blob_client.upload_blob(f, overwrite=True, content_settings=content_settings)
        
        return jsonify({"message": "Uploaded successfully", "filename": f.filename})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.put("/api/blobs/<path:blob_name>/metadata")
def api_update_metadata(blob_name):
    """API endpoint to update blob metadata."""
    try:
        metadata = request.json.get("metadata", {})
        if not isinstance(metadata, dict):
            return jsonify({"error": "Metadata must be a dictionary"}), 400
        
        service = bsc()
        container_name = os.getenv("BLOB_CONTAINER", os.getenv("AZURE_STORAGE_CONTAINER", "uploads"))
        blob_client = service.get_blob_client(container=container_name, blob=blob_name)
        
        # Convert all values to strings (Azure requires string metadata)
        string_metadata = {k: str(v) for k, v in metadata.items()}
        blob_client.set_blob_metadata(string_metadata)
        
        return jsonify({"message": "Metadata updated successfully"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.delete("/api/blobs/<path:blob_name>")
def api_delete_blob(blob_name):
    """API endpoint to delete a blob."""
    try:
        service = bsc()
        container_name = os.getenv("BLOB_CONTAINER", os.getenv("AZURE_STORAGE_CONTAINER", "uploads"))
        blob_client = service.get_blob_client(container=container_name, blob=blob_name)
        blob_client.delete_blob()
        
        return jsonify({"message": "Blob deleted successfully"})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.get("/api/blobs/<path:blob_name>/url")
def api_get_blob_url(blob_name):
    """API endpoint to get a view URL for a blob."""
    try:
        container_name = os.getenv("BLOB_CONTAINER", os.getenv("AZURE_STORAGE_CONTAINER", "uploads"))
        url = make_sas(container_name, blob_name)
        return jsonify({"url": url})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.get("/api/blobs/<path:blob_name>/view")
def api_view_blob(blob_name):
    """API endpoint to view a blob with proper Content-Type headers."""
    try:
        service = bsc()
        container_name = os.getenv("BLOB_CONTAINER", os.getenv("AZURE_STORAGE_CONTAINER", "uploads"))
        blob_client = service.get_blob_client(container=container_name, blob=blob_name)
        
        # Get blob properties to determine content type
        props = blob_client.get_blob_properties()
        md = props.metadata or {}
        
        # Determine content type from multiple sources
        # 1. Try metadata first
        content_type = md.get("mime_type")
        
        # 2. Try blob properties
        if not content_type:
            content_type = props.content_settings.content_type
        
        # 3. Try to guess from filename
        if not content_type:
            content_type, _ = mimetypes.guess_type(blob_name)
        
        # 4. Fallback to application/octet-stream
        if not content_type:
            content_type = "application/octet-stream"
        
        # Stream blob data for better performance (especially for large files)
        # Use download_blob() which returns a streamable object
        blob_download = blob_client.download_blob()
        
        # Create a generator function to stream the data
        def generate():
            for chunk in blob_download.chunks():
                yield chunk
        
        # Create response with proper headers
        # Use 'inline' to display in browser, not 'attachment' which forces download
        response = Response(
            generate(),
            mimetype=content_type
        )
        filename = blob_name.split("/")[-1]
        # Ensure filename is properly encoded
        response.headers["Content-Disposition"] = f'inline; filename="{filename}"; filename*=UTF-8\'\'{quote(filename)}'
        response.headers["Cache-Control"] = "public, max-age=3600"
        response.headers["X-Content-Type-Options"] = "nosniff"
        if props.size:
            response.headers["Content-Length"] = str(props.size)
        
        return response
    except Exception as e:
        return jsonify({"error": str(e)}), 404


@app.get("/health")
def health():
    return jsonify({"ok": True})


@app.get("/health/storage")
def health_storage():
    try:
        container_name = os.getenv("BLOB_CONTAINER", os.getenv("AZURE_STORAGE_CONTAINER", "uploads"))
        cc = ensure_container_exists(container_name)
        # a lightweight call to verify connectivity
        _run_with_timeout(3, cc.get_container_properties)
        return jsonify({"ok": True, "container": container_name})
    except Exception as ex:
        return jsonify({"ok": False, "error": str(ex)}), 503


def _account_key_from_conn_str(conn_str: str | None) -> str | None:
    if not conn_str:
        return None
    try:
        parts = dict(tuple(p.split("=", 1)) for p in conn_str.split(";") if "=" in p)
        return parts.get("AccountKey") or parts.get("accountkey")
    except Exception:
        return None


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)

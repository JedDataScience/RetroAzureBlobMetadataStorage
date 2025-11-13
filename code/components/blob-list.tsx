"use client"

import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Trash2, FileText, ImageIcon, Archive, File, Eye, Loader2 } from "lucide-react"
import type { BlobItem } from "@/components/blob-manager"

type BlobListProps = {
  blobs: BlobItem[]
  selectedBlob: BlobItem | null
  onBlobSelect: (blob: BlobItem) => void
  onBlobDelete: (blobId: string) => void
  loading?: boolean
}

// API URL is set in next.config.mjs and embedded at build time
// For production: https://retro-azure-metadata-api.wonderfulisland-bcb9cf0e.westus2.azurecontainerapps.io
// For local dev: http://localhost:5001 (set via NEXT_PUBLIC_API_URL env var)
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://retro-azure-metadata-api.wonderfulisland-bcb9cf0e.westus2.azurecontainerapps.io'

export function BlobList({ blobs, selectedBlob, onBlobSelect, onBlobDelete, loading }: BlobListProps) {
  const formatSize = (bytes: number) => {
    if (bytes < 1024) return bytes + " B"
    if (bytes < 1048576) return (bytes / 1024).toFixed(2) + " KB"
    return (bytes / 1048576).toFixed(2) + " MB"
  }

  const getFileIcon = (type: string) => {
    if (type.includes("pdf") || type.includes("document")) return <FileText className="h-5 w-5" />
    if (type.includes("image")) return <ImageIcon className="h-5 w-5" />
    if (type.includes("zip") || type.includes("archive")) return <Archive className="h-5 w-5" />
    return <File className="h-5 w-5" />
  }

  const handleView = async (blob: BlobItem) => {
    try {
      // Use the view endpoint which serves files with proper Content-Type headers
      const viewUrl = `${API_BASE_URL}/api/blobs/${encodeURIComponent(blob.id)}/view`
      window.open(viewUrl, "_blank")
    } catch (err) {
      console.error("Error opening blob:", err)
      alert("Failed to open blob")
    }
  }

  const formatDate = (dateString: string | null) => {
    if (!dateString) return "Unknown"
    try {
      const date = new Date(dateString)
      // Use explicit locale to avoid hydration mismatches
      // Format: MM/DD/YYYY (consistent across server and client)
      return date.toLocaleDateString("en-US", {
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
      })
    } catch {
      return dateString
    }
  }

  return (
    <Card className="border-2 border-primary bg-card p-4">
      <div className="mb-4 border-b-2 border-primary pb-2">
        <h2 className="text-lg font-bold text-primary terminal-text">
          {">"} STORAGE CONTENTS [{blobs.length} FILES]
        </h2>
      </div>
      {loading ? (
        <div className="text-center py-12 text-muted-foreground terminal-text flex items-center justify-center gap-2">
          <Loader2 className="h-4 w-4 animate-spin" />
          LOADING FILES...
        </div>
      ) : (
        <div className="space-y-2 max-h-[600px] overflow-y-auto">
          {blobs.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground terminal-text">NO FILES FOUND IN STORAGE</div>
          ) : (
            blobs.map((blob) => (
              <div
                key={blob.id}
                onClick={() => onBlobSelect(blob)}
                className={`border-2 p-3 cursor-pointer transition-colors terminal-text ${
                  selectedBlob?.id === blob.id
                    ? "border-secondary bg-secondary/10"
                    : "border-primary/30 hover:border-primary hover:bg-primary/5"
                }`}
              >
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-start gap-3 flex-1 min-w-0">
                    <div className="text-primary mt-1">{getFileIcon(blob.type)}</div>
                    <div className="flex-1 min-w-0">
                      <div className="font-bold text-foreground truncate">{blob.name}</div>
                      <div className="text-xs text-muted-foreground mt-1 space-y-0.5">
                        {/* Basic metadata in grid layout */}
                        <div className="grid grid-cols-2 gap-x-4 gap-y-0.5">
                          <div>SIZE: {formatSize(blob.size)}</div>
                          <div>TYPE: {blob.type || blob.contentType || "unknown"}</div>
                          <div>MODIFIED: {formatDate(blob.lastModified)}</div>
                          {blob.blobType && blob.blobType !== "BlockBlob" && (
                            <div>BLOB TYPE: {blob.blobType}</div>
                          )}
                          {blob.etag && (
                            <div className="text-xs">ETAG: {blob.etag.substring(0, 16)}...</div>
                          )}
                        </div>
                        {/* Display custom metadata if available */}
                        {Object.keys(blob.metadata || {}).length > 0 && (
                          <div className="mt-2 pt-2 border-t border-primary/20">
                            <div className="text-xs text-secondary font-bold mb-1">METADATA:</div>
                            <div className="space-y-0.5">
                              {Object.entries(blob.metadata || {}).slice(0, 5).map(([key, value]) => (
                                <div key={key} className="text-xs flex items-start gap-1">
                                  <span className="text-secondary font-semibold min-w-fit">{key}:</span>
                                  <span className="text-foreground break-words">
                                    {String(value).length > 50 ? String(value).substring(0, 50) + "..." : value}
                                  </span>
                                </div>
                              ))}
                              {Object.keys(blob.metadata || {}).length > 5 && (
                                <div className="text-xs text-muted-foreground italic">
                                  +{Object.keys(blob.metadata || {}).length - 5} more metadata fields...
                                </div>
                              )}
                            </div>
                          </div>
                        )}
                      </div>
                    </div>
                  </div>
                  <div className="flex gap-1">
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={(e) => {
                        e.stopPropagation()
                        handleView(blob)
                      }}
                      className="text-primary hover:text-primary hover:bg-primary/10 border-2 border-primary/30 hover:border-primary"
                    >
                      <Eye className="h-4 w-4" />
                    </Button>
                    <Button
                      variant="ghost"
                      size="icon"
                      onClick={(e) => {
                        e.stopPropagation()
                        onBlobDelete(blob.id)
                      }}
                      className="text-destructive hover:text-destructive hover:bg-destructive/10 border-2 border-destructive/30 hover:border-destructive"
                    >
                      <Trash2 className="h-4 w-4" />
                    </Button>
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      )}
    </Card>
  )
}

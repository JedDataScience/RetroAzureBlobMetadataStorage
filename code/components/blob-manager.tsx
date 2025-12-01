"use client"

import { useState, useEffect } from "react"
import { BlobList } from "@/components/blob-list"
import { BlobUpload } from "@/components/blob-upload"
import { MetadataEditor } from "@/components/metadata-editor"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"

export type BlobItem = {
  id: string
  name: string
  size: number
  type: string
  lastModified: string
  metadata: Record<string, string>
  blob_path?: string
  // Additional metadata fields
  etag?: string
  contentType?: string
  contentEncoding?: string
  contentLanguage?: string
  cacheControl?: string
  blobType?: string
  creationTime?: string
}

// API URL is set in next.config.mjs and embedded at build time
// For production: https://retro-azure-metadata-api.wonderfulisland-bcb9cf0e.westus2.azurecontainerapps.io
// For local dev: http://localhost:5001 (set via NEXT_PUBLIC_API_URL env var)
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://retro-azure-metadata-api.wonderfulisland-bcb9cf0e.westus2.azurecontainerapps.io'

export function BlobManager() {
  const [selectedBlob, setSelectedBlob] = useState<BlobItem | null>(null)
  const [blobs, setBlobs] = useState<BlobItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const loadBlobs = async () => {
    try {
      setLoading(true)
      setError(null)
      const response = await fetch(`${API_BASE_URL}/api/blobs`)
      if (!response.ok) throw new Error("Failed to fetch blobs")
      const data = await response.json()
      setBlobs(data.blobs || [])
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to load blobs")
      console.error("Error loading blobs:", err)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadBlobs()
    // Refresh every 30 seconds
    const interval = setInterval(loadBlobs, 30000)
    return () => clearInterval(interval)
  }, [])

  const handleBlobSelect = (blob: BlobItem) => {
    setSelectedBlob(blob)
  }

  const handleMetadataUpdate = async (blobId: string, metadata: Record<string, string>) => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/blobs/${encodeURIComponent(blobId)}/metadata`, {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ metadata }),
      })
      if (!response.ok) throw new Error("Failed to update metadata")
      
      // Update local state
      setBlobs(blobs.map((blob) => (blob.id === blobId ? { ...blob, metadata } : blob)))
      if (selectedBlob?.id === blobId) {
        setSelectedBlob({ ...selectedBlob, metadata })
      }
      await loadBlobs() // Refresh to get latest data
    } catch (err) {
      console.error("Error updating metadata:", err)
      alert("Failed to update metadata")
    }
  }

  const handleBlobDelete = async (blobId: string) => {
    if (!confirm("Are you sure you want to delete this blob?")) return
    
    try {
      const response = await fetch(`${API_BASE_URL}/api/blobs/${encodeURIComponent(blobId)}`, {
        method: "DELETE",
      })
      if (!response.ok) throw new Error("Failed to delete blob")
      
      setBlobs(blobs.filter((blob) => blob.id !== blobId))
      if (selectedBlob?.id === blobId) {
        setSelectedBlob(null)
      }
      await loadBlobs() // Refresh
    } catch (err) {
      console.error("Error deleting blob:", err)
      alert("Failed to delete blob")
    }
  }

  const handleUploadComplete = () => {
    loadBlobs() // Refresh list after upload
  }

  return (
    <div className="grid gap-6 lg:grid-cols-3">
      <div className="lg:col-span-2">
        <Tabs defaultValue="list" className="w-full">
          <TabsList className="grid w-full grid-cols-2 bg-card border-2 border-primary">
            <TabsTrigger
              value="list"
              className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground terminal-text"
            >
              {">"} BLOB LIST
            </TabsTrigger>
            <TabsTrigger
              value="upload"
              className="data-[state=active]:bg-primary data-[state=active]:text-primary-foreground terminal-text"
            >
              {">"} UPLOAD
            </TabsTrigger>
          </TabsList>
          <TabsContent value="list" className="mt-4">
            {error && (
              <div className="mb-4 p-3 border-2 border-destructive bg-destructive/10 text-destructive terminal-text">
                ERROR: {error}
              </div>
            )}
            <BlobList
              blobs={blobs}
              selectedBlob={selectedBlob}
              onBlobSelect={handleBlobSelect}
              onBlobDelete={handleBlobDelete}
              loading={loading}
            />
          </TabsContent>
          <TabsContent value="upload" className="mt-4">
            <BlobUpload onUploadComplete={handleUploadComplete} />
          </TabsContent>
        </Tabs>
      </div>
      <div>
        <MetadataEditor blob={selectedBlob} onMetadataUpdate={handleMetadataUpdate} />
      </div>
    </div>
  )
}

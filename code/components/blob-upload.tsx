"use client"

import { useState, useRef } from "react"
import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Upload, CheckCircle, Loader2 } from "lucide-react"

// API URL is set in next.config.mjs and embedded at build time
// For production: https://retro-azure-metadata-api.wonderfulisland-bcb9cf0e.westus2.azurecontainerapps.io
// For local dev: http://localhost:5001 (set via NEXT_PUBLIC_API_URL env var)
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'https://retro-azure-metadata-api.wonderfulisland-bcb9cf0e.westus2.azurecontainerapps.io'

type BlobUploadProps = {
  onUploadComplete?: () => void
}

export function BlobUpload({ onUploadComplete }: BlobUploadProps) {
  const [uploading, setUploading] = useState(false)
  const [uploaded, setUploaded] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const handleFileSelect = () => {
    fileInputRef.current?.click()
  }

  const handleUpload = async (file: File | null) => {
    if (!file) return

    setUploading(true)
    setError(null)
    setUploaded(false)

    try {
      const formData = new FormData()
      formData.append("file", file)

      const response = await fetch(`${API_BASE_URL}/api/blobs`, {
        method: "POST",
        body: formData,
      })

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({ error: "Upload failed" }))
        throw new Error(errorData.error || "Upload failed")
      }

      setUploaded(true)
      setTimeout(() => {
        setUploaded(false)
        if (fileInputRef.current) fileInputRef.current.value = ""
        onUploadComplete?.()
      }, 3000)
    } catch (err) {
      setError(err instanceof Error ? err.message : "Upload failed")
      console.error("Upload error:", err)
    } finally {
      setUploading(false)
    }
  }

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      handleUpload(file)
    }
  }

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault()
    const file = e.dataTransfer.files[0]
    if (file) {
      handleUpload(file)
    }
  }

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault()
  }

  return (
    <Card className="border-2 border-primary bg-card p-6">
      <div className="mb-4 border-b-2 border-primary pb-2">
        <h2 className="text-lg font-bold text-primary terminal-text">{">"} FILE UPLOAD INTERFACE</h2>
      </div>
      <div className="space-y-4">
        <div
          onDrop={handleDrop}
          onDragOver={handleDragOver}
          onClick={handleFileSelect}
          className="border-2 border-dashed border-primary/50 p-8 text-center terminal-text cursor-pointer hover:border-primary hover:bg-primary/5 transition-colors"
        >
          <Upload className="h-12 w-12 mx-auto mb-4 text-primary" />
          <p className="text-foreground mb-2">DROP FILES HERE</p>
          <p className="text-xs text-muted-foreground">OR CLICK TO SELECT</p>
          <input
            ref={fileInputRef}
            type="file"
            onChange={handleFileChange}
            className="hidden"
            disabled={uploading}
          />
        </div>

        {error && (
          <div className="border-2 border-destructive bg-destructive/10 text-destructive p-3 terminal-text text-sm">
            ERROR: {error}
          </div>
        )}

        <Button
          onClick={handleFileSelect}
          disabled={uploading || uploaded}
          className="w-full border-2 border-primary bg-primary text-primary-foreground hover:bg-primary/90 terminal-text"
        >
          {uploading && (
            <>
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              UPLOADING...
            </>
          )}
          {uploaded && (
            <>
              <CheckCircle className="h-4 w-4 mr-2" />
              UPLOAD COMPLETE
            </>
          )}
          {!uploading && !uploaded && "> SELECT FILE TO UPLOAD"}
        </Button>

        <div className="border-2 border-secondary/30 bg-secondary/5 p-3 text-xs terminal-text">
          <div className="text-secondary font-bold mb-1">SYSTEM STATUS:</div>
          <div className="text-muted-foreground space-y-0.5">
            <div>• MAX FILE SIZE: 100 MB</div>
            <div>• SUPPORTED FORMATS: ALL</div>
            <div>• CONNECTION: SECURE</div>
          </div>
        </div>
      </div>
    </Card>
  )
}

"use client"

import { useState, useEffect } from "react"
import { Card } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Plus, Save, X, Loader2 } from "lucide-react"
import type { BlobItem } from "@/components/blob-manager"

type MetadataEditorProps = {
  blob: BlobItem | null
  onMetadataUpdate: (blobId: string, metadata: Record<string, string>) => void
}

export function MetadataEditor({ blob, onMetadataUpdate }: MetadataEditorProps) {
  const [metadata, setMetadata] = useState<Record<string, string>>({})
  const [newKey, setNewKey] = useState("")
  const [newValue, setNewValue] = useState("")
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (blob) {
      setMetadata(blob.metadata || {})
    } else {
      setMetadata({})
    }
  }, [blob])

  const handleAddMetadata = () => {
    if (newKey && newValue) {
      setMetadata({ ...metadata, [newKey]: newValue })
      setNewKey("")
      setNewValue("")
    }
  }

  const handleRemoveMetadata = (key: string) => {
    const updated = { ...metadata }
    delete updated[key]
    setMetadata(updated)
  }

  const handleSave = async () => {
    if (!blob) return

    setSaving(true)
    try {
      await onMetadataUpdate(blob.id, metadata)
    } catch (err) {
      console.error("Error saving metadata:", err)
    } finally {
      setSaving(false)
    }
  }

  if (!blob) {
    return (
      <Card className="border-2 border-primary bg-card p-6">
        <div className="text-center py-12 terminal-text">
          <div className="text-muted-foreground mb-2">NO FILE SELECTED</div>
          <div className="text-xs text-muted-foreground">SELECT A FILE TO EDIT METADATA</div>
        </div>
      </Card>
    )
  }

  return (
    <Card className="border-2 border-primary bg-card p-4">
      <div className="mb-4 border-b-2 border-primary pb-2">
        <h2 className="text-lg font-bold text-primary terminal-text">{">"} METADATA EDITOR</h2>
        <p className="text-xs text-muted-foreground mt-1 terminal-text truncate">FILE: {blob.name}</p>
      </div>

      <div className="space-y-4">
        <div className="space-y-2 max-h-[300px] overflow-y-auto">
          {Object.entries(metadata).map(([key, value]) => (
            <div key={key} className="border-2 border-primary/30 p-2 terminal-text">
              <div className="flex items-start justify-between gap-2">
                <div className="flex-1 min-w-0">
                  <div className="text-xs text-secondary font-bold">{key}:</div>
                  <div className="text-sm text-foreground break-words">{value}</div>
                </div>
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => handleRemoveMetadata(key)}
                  className="h-6 w-6 text-destructive hover:text-destructive hover:bg-destructive/10 border border-destructive/30"
                >
                  <X className="h-3 w-3" />
                </Button>
              </div>
            </div>
          ))}
          {Object.keys(metadata).length === 0 && (
            <div className="text-center py-8 text-muted-foreground text-xs terminal-text">
              NO METADATA ENTRIES
            </div>
          )}
        </div>

        <div className="border-2 border-secondary/30 bg-secondary/5 p-3 space-y-2">
          <div className="text-xs text-secondary font-bold terminal-text">{">"} ADD NEW METADATA:</div>
          <Input
            placeholder="KEY"
            value={newKey}
            onChange={(e) => setNewKey(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && newKey && newValue) {
                handleAddMetadata()
              }
            }}
            className="border-2 border-primary bg-input text-foreground terminal-text text-sm"
          />
          <Input
            placeholder="VALUE"
            value={newValue}
            onChange={(e) => setNewValue(e.target.value)}
            onKeyDown={(e) => {
              if (e.key === "Enter" && newKey && newValue) {
                handleAddMetadata()
              }
            }}
            className="border-2 border-primary bg-input text-foreground terminal-text text-sm"
          />
          <Button
            onClick={handleAddMetadata}
            disabled={!newKey || !newValue}
            className="w-full border-2 border-secondary bg-secondary text-secondary-foreground hover:bg-secondary/90 terminal-text"
          >
            <Plus className="h-4 w-4 mr-2" />
            ADD ENTRY
          </Button>
        </div>

        <Button
          onClick={handleSave}
          disabled={saving}
          className="w-full border-2 border-primary bg-primary text-primary-foreground hover:bg-primary/90 terminal-text"
        >
          {saving ? (
            <>
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              SAVING...
            </>
          ) : (
            <>
              <Save className="h-4 w-4 mr-2" />
              SAVE METADATA
            </>
          )}
        </Button>
      </div>
    </Card>
  )
}

"use client"

import { useState, useEffect } from "react"

export function TerminalHeader() {
  // Initialize with null to avoid hydration mismatch
  // Only set date after component mounts (client-side)
  const [time, setTime] = useState<Date | null>(null)
  const [mounted, setMounted] = useState(false)

  useEffect(() => {
    // Set mounted flag and initial time only on client
    setMounted(true)
    setTime(new Date())
    const timer = setInterval(() => setTime(new Date()), 1000)
    return () => clearInterval(timer)
  }, [])

  return (
    <div className="border-2 border-primary bg-card p-4 terminal-text">
      <div className="flex items-start justify-between gap-4 flex-wrap">
        <div className="space-y-1">
          <h1 className="text-2xl md:text-3xl font-bold text-primary">{">"} AZURE BLOB METADATA MANAGER</h1>
          <p className="text-sm text-muted-foreground">SYSTEM v2.1.0 | TERMINAL INTERFACE | READY</p>
        </div>
        <div className="text-right text-sm space-y-1">
          {mounted && time ? (
            <>
              <div className="text-secondary font-bold">{time.toLocaleTimeString("en-US", { hour12: false })}</div>
              <div className="text-muted-foreground">
                {time.toLocaleDateString("en-US", {
                  year: "numeric",
                  month: "2-digit",
                  day: "2-digit",
                })}
              </div>
            </>
          ) : (
            <>
              <div className="text-secondary font-bold">--:--:--</div>
              <div className="text-muted-foreground">--/--/----</div>
            </>
          )}
        </div>
      </div>
      <div className="mt-4 flex gap-2 text-xs">
        <span className="text-primary">●</span>
        <span className="text-foreground">CONNECTED</span>
        <span className="text-muted-foreground">|</span>
        <span className="text-secondary">STORAGE ACTIVE</span>
      </div>
    </div>
  )
}

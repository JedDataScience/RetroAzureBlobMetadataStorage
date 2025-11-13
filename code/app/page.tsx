import { BlobManager } from "@/components/blob-manager"
import { TerminalHeader } from "@/components/terminal-header"

export default function Home() {
  return (
    <main className="min-h-screen bg-background p-4 md:p-8">
      <div className="mx-auto max-w-7xl space-y-6">
        <TerminalHeader />
        <BlobManager />
      </div>
    </main>
  )
}

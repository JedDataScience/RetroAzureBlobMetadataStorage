import type React from "react"
import type { Metadata } from "next"
import "./globals.css"

export const metadata: Metadata = {
  title: "Azure Blob Metadata Manager",
  description: "Retro terminal interface for Azure blob storage management",
  generator: "v0.app",
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en">
      <body className="font-mono antialiased crt-effect">
        {children}
        {/* Analytics disabled for static export - causes hydration issues */}
      </body>
    </html>
  )
}

import * as React from 'react'

const MOBILE_BREAKPOINT = 768

export function useIsMobile() {
  // Initialize with false to avoid hydration mismatch
  // Only check window size after component mounts (client-side)
  const [isMobile, setIsMobile] = React.useState<boolean>(false)
  const [mounted, setMounted] = React.useState(false)

  React.useEffect(() => {
    // Only run on client-side
    if (typeof window === 'undefined') return
    
    setMounted(true)
    const checkIsMobile = () => {
      setIsMobile(window.innerWidth < MOBILE_BREAKPOINT)
    }
    
    // Check immediately
    checkIsMobile()
    
    // Set up media query listener
    const mql = window.matchMedia(`(max-width: ${MOBILE_BREAKPOINT - 1}px)`)
    const onChange = () => {
      checkIsMobile()
    }
    
    // Use addEventListener for better browser support
    if (mql.addEventListener) {
      mql.addEventListener('change', onChange)
    } else {
      // Fallback for older browsers
      mql.addListener(onChange)
    }
    
    return () => {
      if (mql.removeEventListener) {
        mql.removeEventListener('change', onChange)
      } else {
        mql.removeListener(onChange)
      }
    }
  }, [])

  // Return false during SSR to avoid hydration mismatch
  return mounted ? isMobile : false
}

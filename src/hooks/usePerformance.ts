import { useCallback, useRef } from 'react'

export const usePerformance = () => {
  const renderCount = useRef(0)
  const lastRenderTime = useRef(Date.now())
  const warningIssued = useRef(false)

  const trackRender = useCallback((componentName: string) => {
    const now = Date.now()
    const timeSinceLastRender = now - lastRenderTime.current
    renderCount.current += 1
    lastRenderTime.current = now

    if (
      import.meta.env.DEV &&
      !warningIssued.current &&
      renderCount.current > 10 &&
      timeSinceLastRender < 100
    ) {
      warningIssued.current = true
      console.warn(`Possible performance issue in ${componentName}: rapid rendering detected`)
    }
  }, [])

  return { trackRender }
}

export default usePerformance

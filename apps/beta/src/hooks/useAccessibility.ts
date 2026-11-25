import { useCallback, useEffect, useRef, useState } from 'react'

interface AccessibilitySettings {
  reducedMotion: boolean
  keyboardNavigation: true
}

export const useKeyboardNavigation = (onEscape?: () => void) => {
  useEffect(() => {
    if (!onEscape) return

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') onEscape()
    }

    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [onEscape])
}

export const useAccessibility = () => {
  const [reducedMotion, setReducedMotion] = useState(() =>
    typeof window !== 'undefined' &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches
  )
  const announcementRef = useRef<HTMLDivElement | null>(null)
  const announcementTimer = useRef<number | undefined>(undefined)

  useEffect(() => {
    const preference = window.matchMedia('(prefers-reduced-motion: reduce)')
    const handleChange = (event: MediaQueryListEvent) => setReducedMotion(event.matches)

    preference.addEventListener('change', handleChange)
    return () => {
      preference.removeEventListener('change', handleChange)
      if (announcementTimer.current !== undefined) {
        window.clearTimeout(announcementTimer.current)
      }
      announcementRef.current?.remove()
      announcementRef.current = null
    }
  }, [])

  const announceToScreenReader = useCallback((message: string) => {
    if (!announcementRef.current) {
      const announcement = document.createElement('div')
      announcement.setAttribute('aria-live', 'polite')
      announcement.setAttribute('aria-atomic', 'true')
      announcement.className = 'sr-only'
      document.body.appendChild(announcement)
      announcementRef.current = announcement
    }

    announcementRef.current.textContent = ''
    window.requestAnimationFrame(() => {
      if (announcementRef.current) announcementRef.current.textContent = message
    })

    if (announcementTimer.current !== undefined) {
      window.clearTimeout(announcementTimer.current)
    }
    announcementTimer.current = window.setTimeout(() => {
      if (announcementRef.current) announcementRef.current.textContent = ''
      announcementTimer.current = undefined
    }, 1000)
  }, [])

  const focusElement = useCallback((selector: string) => {
    const element = document.querySelector<HTMLElement>(selector)
    if (!element) return false
    element.focus()
    element.scrollIntoView({ behavior: reducedMotion ? 'auto' : 'smooth', block: 'center' })
    return true
  }, [reducedMotion])

  const trapFocus = useCallback((container: HTMLElement) => {
    const focusableElements = Array.from(container.querySelectorAll<HTMLElement>(
      'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])'
    ))
    const previouslyFocused = document.activeElement instanceof HTMLElement
      ? document.activeElement
      : null
    const firstElement = focusableElements[0] ?? container
    const lastElement = focusableElements[focusableElements.length - 1] ?? container

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Tab' || focusableElements.length === 0) return

      if (event.shiftKey && document.activeElement === firstElement) {
        event.preventDefault()
        lastElement.focus()
      } else if (!event.shiftKey && document.activeElement === lastElement) {
        event.preventDefault()
        firstElement.focus()
      }
    }

    container.addEventListener('keydown', handleKeyDown)
    firstElement.focus()

    return () => {
      container.removeEventListener('keydown', handleKeyDown)
      if (previouslyFocused?.isConnected) previouslyFocused.focus()
    }
  }, [])

  const accessibilitySettings: AccessibilitySettings = {
    reducedMotion,
    keyboardNavigation: true
  }

  return {
    accessibilitySettings,
    announceToScreenReader,
    focusElement,
    trapFocus
  }
}

export default useAccessibility

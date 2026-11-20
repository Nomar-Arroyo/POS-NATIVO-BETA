import { useCallback, useEffect } from 'react'
import { useNotification } from './useNotification'

const getErrorMessage = (error: unknown): string =>
  error instanceof Error ? error.message : String(error || 'Error desconocido')

export const useGlobalError = () => {
  const { notifyError } = useNotification()

  useEffect(() => {
    const handleError = (event: ErrorEvent) => {
      console.error('Global error:', event.error)
      notifyError(`Error inesperado: ${getErrorMessage(event.error)}`)
    }

    const handleUnhandledRejection = (event: PromiseRejectionEvent) => {
      console.error('Unhandled promise rejection:', event.reason)
      notifyError(`Error en operación asíncrona: ${getErrorMessage(event.reason)}`)
    }

    window.addEventListener('error', handleError)
    window.addEventListener('unhandledrejection', handleUnhandledRejection)
    return () => {
      window.removeEventListener('error', handleError)
      window.removeEventListener('unhandledrejection', handleUnhandledRejection)
    }
  }, [notifyError])

  const reportError = useCallback((error: Error, context?: string) => {
    console.error(`Error in ${context || 'unknown context'}:`, error)
    notifyError(`Error${context ? ` en ${context}` : ''}: ${error.message}`)
  }, [notifyError])

  const handleApiError = useCallback((error: unknown, operation: string) => {
    let message = ''
    if (error && typeof error === 'object' && 'response' in error) {
      const response = error.response
      if (
        response && typeof response === 'object' &&
        'data' in response &&
        response.data && typeof response.data === 'object' &&
        'message' in response.data &&
        typeof response.data.message === 'string'
      ) {
        message = response.data.message
      }
    }
    if (!message) message = getErrorMessage(error) || `Error desconocido en ${operation}`
    notifyError(message)
  }, [notifyError])

  return { reportError, handleApiError }
}

export default useGlobalError

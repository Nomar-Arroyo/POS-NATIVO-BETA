import React, { Component, type ErrorInfo, type ReactNode, useCallback } from 'react'
import { useStore } from '../../store/store'
import Button from './Button'
import Icon from './Icon'

interface ErrorBoundaryProps {
  children: ReactNode
}

interface ErrorBoundaryClassProps extends ErrorBoundaryProps {
  onError: (error: Error, errorInfo: ErrorInfo) => void
}

interface ErrorBoundaryState {
  hasError: boolean
  error?: Error
}

class ErrorBoundaryClass extends Component<ErrorBoundaryClassProps, ErrorBoundaryState> {
  state: ErrorBoundaryState = { hasError: false }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Error boundary caught:', error, errorInfo)
    this.props.onError(error, errorInfo)
  }

  render() {
    if (!this.state.hasError) return this.props.children

    return (
      <main
        className="flex min-h-screen items-center justify-center bg-gray-900 p-4"
        role="alert"
      >
        <section className="w-full max-w-md rounded-lg border border-gray-700 bg-gray-800 p-6 text-center">
          <Icon name="alert" size={48} color="#159FA2" className="mx-auto mb-4" />
          <h1 className="mb-2 text-xl font-bold text-white">Algo salió mal</h1>
          <p className="mb-4 text-gray-300">
            La aplicación encontró un error inesperado. Recargue para continuar.
          </p>
          {this.state.error && (
            <p className="mb-4 break-words text-sm text-gray-400">
              {this.state.error.message}
            </p>
          )}
          <Button
            type="button"
            onClick={() => window.location.reload()}
            variant="primary"
          >
            Recargar aplicación
          </Button>
        </section>
      </main>
    )
  }
}

const ErrorBoundary: React.FC<ErrorBoundaryProps> = ({ children }) => {
  const addNotification = useStore(state => state.addNotification)
  const handleError = useCallback((error: Error) => {
    addNotification({
      type: 'error',
      message: `Error inesperado en la interfaz: ${error.message}`
    })
  }, [addNotification])

  return (
    <ErrorBoundaryClass onError={handleError}>
      {children}
    </ErrorBoundaryClass>
  )
}

export default ErrorBoundary

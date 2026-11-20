import React from 'react'
import { useStore } from '../../store/store'
import LoadingSpinner from './LoadingSpinner'

interface GlobalLoadingProps {
  forceVisible?: boolean
}

const GlobalLoading: React.FC<GlobalLoadingProps> = ({ forceVisible = false }) => {
  const loading = useStore(state => state.loading)
  if (!forceVisible && !loading) return null

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      role="status"
      aria-live="polite"
    >
      <div className="w-full max-w-sm rounded-lg bg-gray-800 p-6 text-center shadow-xl">
        <LoadingSpinner size="lg" color="turquoise" />
        <p className="mt-4 font-medium text-white">Procesando...</p>
        <p className="mt-2 text-sm text-gray-400">
          Espere mientras se completa la operación
        </p>
      </div>
    </div>
  )
}

export default GlobalLoading

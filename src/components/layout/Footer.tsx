import React from 'react'

const Footer: React.FC = () => {
  return (
    <footer className="border-t border-gray-700 bg-gray-800 px-3 py-2 text-gray-400 sm:px-4 lg:px-6 lg:py-3">
      <div className="flex flex-col gap-1 text-xs sm:flex-row sm:items-center sm:justify-between sm:text-sm">
        <div>
          POS Nativo Beta v1.0.0 - Café Analítica C.A.
        </div>
        <div>
          Desarrollado para demostración comercial
        </div>
      </div>
    </footer>
  )
}

export default Footer
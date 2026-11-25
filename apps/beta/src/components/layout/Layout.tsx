import React, { useEffect, useState } from 'react'
import Sidebar from './Sidebar'
import Header from './Header'
import Footer from './Footer'
import NotificationContainer from '../common/NotificationContainer'
import ConfigStatus from '../common/ConfigStatus'
import { useDataVerification } from '../../hooks/useDataVerification'

interface LayoutProps {
  children: React.ReactNode;
}

const Layout: React.FC<LayoutProps> = ({ children }) => {
  const [isSidebarOpen, setIsSidebarOpen] = useState(false)

  useDataVerification()

  useEffect(() => {
    if (!isSidebarOpen) return

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setIsSidebarOpen(false)
    }

    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [isSidebarOpen])

  return (
    <div className="flex h-screen min-h-0 overflow-hidden bg-gray-900 text-white [@supports(height:100dvh)]:h-[100dvh]">
      <Sidebar
        isOpen={isSidebarOpen}
        onClose={() => setIsSidebarOpen(false)}
      />
      <div className="flex min-w-0 flex-1 flex-col overflow-hidden">
        <Header
          onOpenMenu={() => setIsSidebarOpen(true)}
          isMenuOpen={isSidebarOpen}
        />
        
        <div className="border-b border-gray-700 bg-gray-800 px-3 py-1 sm:px-4 lg:px-6">
          <div className="flex flex-wrap items-center justify-between gap-x-3 gap-y-1 text-xs">
            <ConfigStatus />
            <div className="hidden items-center gap-3 text-gray-400 md:flex">
              <span>Aplicación: POS Nativo Beta</span>
              <span>•</span>
              <span>Versión: 1.0.0-beta</span>
              <span>•</span>
              <span>Modo: Local</span>
            </div>
          </div>
        </div>

        <main className="min-h-0 min-w-0 flex-1 overflow-x-hidden overflow-y-auto bg-gray-900 p-3 sm:p-4 lg:p-6">
          {children}
        </main>
        
        <Footer />
      </div>
      
      <NotificationContainer />
    </div>
  )
}

export default Layout
import React, { lazy, Suspense, useEffect } from 'react'
import Layout from './components/layout/Layout'
import { useStore } from './store/store'
import { usePerformance } from './hooks/usePerformance'
import { useGlobalError } from './hooks/useGlobalError'
import { useAccessibility } from './hooks/useAccessibility'
import initializeService from './services/data/initializeData'
import GlobalLoading from './components/common/GlobalLoading'
import SystemDiagnostic from './components/common/SystemDiagnostic'
import ErrorBoundary from './components/common/ErrorBoundary'

const Dashboard = lazy(() => import('./modules/dashboard/Dashboard'))
const Salon = lazy(() => import('./modules/salon/Salon'))
const Pos = lazy(() => import('./modules/pos/Pos'))
const Orders = lazy(() => import('./modules/orders/Orders'))
const Inventory = lazy(() => import('./modules/inventory/Inventory'))
const Cash = lazy(() => import('./modules/cash/Cash'))
const Reports = lazy(() => import('./modules/reports/Reports'))
const Audit = lazy(() => import('./modules/audit/Audit'))
const Settings = lazy(() => import('./modules/settings/Settings'))
const Products = lazy(() => import('./modules/products/Products'))

const App: React.FC = () => {
  const { activeModule, loadState } = useStore()
  const { trackRender } = usePerformance()
  useGlobalError()
  useAccessibility()

  useEffect(() => {
    trackRender('App')
  })

  useEffect(() => {
    loadState()
    
    // Inicializar datos de demostración si están vacíos
    if (!initializeService.hasData()) {
      initializeService.initializeDemoData()
    }
  }, [loadState])

  const renderModule = () => {
    switch (activeModule) {
      case 'dashboard':
        return <Dashboard />
      case 'salon':
        return <Salon />
      case 'pos':
        return <Pos />
      case 'orders':
        return <Orders />
      case 'inventory':
        return <Inventory />
      case 'cash':
        return <Cash />
      case 'reports':
        return <Reports />
      case 'audit':
        return <Audit />
      case 'settings':
        return <Settings />
      case 'products':
        return <Products />
      default:
        return <Dashboard />
    }
  }

  return (
    <ErrorBoundary>
      <Layout>
        <Suspense fallback={<GlobalLoading forceVisible />}>
          {renderModule()}
        </Suspense>
      </Layout>
      {import.meta.env.DEV && <SystemDiagnostic />}
    </ErrorBoundary>
  )
}

export default App
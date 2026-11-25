import React from 'react'
import Layout from '../components/layout/Layout'
import Dashboard from '../modules/dashboard/Dashboard'
import Salon from '../modules/salon/Salon'
import Pos from '../modules/pos/Pos'
import Orders from '../modules/orders/Orders'
import Inventory from '../modules/inventory/Inventory'
import Cash from '../modules/cash/Cash'
import Reports from '../modules/reports/Reports'
import Audit from '../modules/audit/Audit'
import Settings from '../modules/settings/Settings'
import { useStore } from '../store/store'

const App: React.FC = () => {
  const { activeModule } = useStore()

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
      default:
        return <Dashboard />
    }
  }

  return (
    <Layout>
      {renderModule()}
    </Layout>
  )
}

export default App
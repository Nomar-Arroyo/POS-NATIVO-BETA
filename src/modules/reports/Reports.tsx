import React, { useState } from 'react'
import { useStore } from '../../store/store'
import Button from '../../components/common/Button'
import Select from '../../components/common/Select'
import SalesReport from './SalesReport'
import CashReport from './CashReport'

const Reports: React.FC = () => {
  const { facturas, cashSessions } = useStore()
  const [reportType, setReportType] = useState<'sales' | 'cash'>('sales')
  const [dateRange, setDateRange] = useState<'today' | 'week' | 'month'>('today')

  const reportOptions = [
    { value: 'sales', label: 'Ventas' },
    { value: 'cash', label: 'Caja' },
  ]

  const dateOptions = [
    { value: 'today', label: 'Hoy' },
    { value: 'week', label: 'Última Semana' },
    { value: 'month', label: 'Último Mes' }
  ]

  const renderReport = () => {
    switch (reportType) {
      case 'sales':
        return <SalesReport facturas={facturas} />
      case 'cash':
        return cashSessions[0] ? (
          <CashReport session={cashSessions[0]} onPrint={() => window.print()} />
        ) : (
          <div className="text-gray-400">No hay sesiones de caja disponibles</div>
        )
      default:
        return <SalesReport facturas={facturas} />
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="text-2xl font-bold text-white">Reportes</h2>
        <div className="flex items-center space-x-4">
          <Select
            options={reportOptions}
            value={reportType}
            onChange={(e) => setReportType(e.target.value as any)}
          />
          <Select
            options={dateOptions}
            value={dateRange}
            onChange={(e) => setDateRange(e.target.value as any)}
          />
          <Button variant="primary">
            Exportar
          </Button>
        </div>
      </div>

      {renderReport()}
    </div>
  )
}

export default Reports
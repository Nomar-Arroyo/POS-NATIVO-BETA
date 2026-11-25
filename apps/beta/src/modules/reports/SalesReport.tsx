import React from 'react'
import { Factura } from '../../types'
import Table from '../../components/common/Table'
import Card from '../../components/common/Card'

interface SalesReportProps {
  facturas: Factura[]
}

const SalesReport: React.FC<SalesReportProps> = ({ facturas }) => {
  const columns = [
    {
      key: 'number' as keyof Factura,
      header: 'Factura'
    },
    {
      key: 'createdAt' as keyof Factura,
      header: 'Fecha',
      render: (date: Date) => new Date(date).toLocaleDateString()
    },
    {
      key: 'customerName' as keyof Factura,
      header: 'Cliente',
      render: (name?: string) => name || 'Consumidor Final'
    },
    {
      key: 'total' as keyof Factura,
      header: 'Total',
      render: (total: number) => `$${total.toFixed(2)}`
    },
    {
      key: 'payments' as keyof Factura,
      header: 'Métodos de Pago',
      render: (payments: any[]) => payments.map(p => p.method).join(', ')
    }
  ]

  const totalSales = facturas.reduce((sum, f) => sum + f.total, 0)

  return (
    <Card title="Reporte de Ventas">
      <div className="mb-4 flex justify-between items-center">
        <p className="text-gray-400">Total de Ventas:</p>
        <p className="text-xl font-bold text-green-400">${totalSales.toFixed(2)}</p>
      </div>
      
      <Table
        data={facturas}
        columns={columns}
        emptyMessage="No hay ventas registradas"
      />
    </Card>
  )
}

export default SalesReport
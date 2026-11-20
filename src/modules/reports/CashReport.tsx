import React from 'react'
import { CashSession } from '../../types'
import Table from '../../components/common/Table'
import Button from '../../components/common/Button'

interface CashReportProps {
  session: CashSession
  onPrint: () => void
}

const CashReport: React.FC<CashReportProps> = ({ session, onPrint }) => {
  const columns = [
    {
      key: 'timestamp' as any,
      header: 'Fecha/Hora',
      render: (value: Date) => new Date(value).toLocaleString()
    },
    {
      key: 'description' as any,
      header: 'Descripción'
    },
    {
      key: 'amount' as any,
      header: 'Monto',
      render: (amount: number, movement: any) => (
        <span className={movement.type === 'INGRESO' ? 'text-green-400' : 'text-red-400'}>
          {movement.type === 'INGRESO' ? '+' : '-'}
          {movement.currency === 'USD' ? '$' : 'Bs.'} {amount.toFixed(2)}
        </span>
      )
    }
  ]

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h3 className="text-lg font-medium text-white">Reporte de Caja</h3>
        <Button variant="primary" onClick={onPrint}>
          Imprimir Reporte
        </Button>
      </div>

      <Table
        data={session.movements}
        columns={columns}
        emptyMessage="No hay movimientos en este turno"
      />
    </div>
  )
}

export default CashReport
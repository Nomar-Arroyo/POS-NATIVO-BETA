import React from 'react'
import { useStore } from '../../store/store'
import { useCalculation } from '../../hooks/useCalculation'
import type { CashReport } from '../../types/cash'
import Card from '../common/Card'
import Button from '../common/Button'
import { ArrowDownTrayIcon, PrinterIcon } from '@/components/common/Icon'

interface CashReportComponentProps {
  report: CashReport
  onPrint?: (report: CashReport) => void
  onDownload?: (report: CashReport) => void
}

const CashReportComponent: React.FC<CashReportComponentProps> = ({
  report,
  onPrint,
  onDownload
}) => {
  const { config } = useStore()
  const { formatCurrency } = useCalculation()

  const formatMethod = (method: string): string => {
    const labels: Record<string, string> = {
      'EFECTIVO USD': 'Efectivo USD',
      'EFECTIVO Bs': 'Efectivo Bs',
      'PUNTO DE VENTA': 'Punto de Venta',
      'PAGO MÓVIL': 'Pago Móvil',
      ZELLE: 'Zelle',
      OTRO: 'Otro'
    }
    return labels[method] || method
  }

  return (
    <div className="space-y-4">
      <header className="border-b border-gray-700 pb-4 text-center">
        <h2 className="text-xl font-bold text-white">{config.establishmentName}</h2>
        <p className="text-sm text-gray-400">Reporte {report.type} - Caja</p>
        <p className="text-xs text-gray-500">
          {new Date(report.generatedAt).toLocaleString('es-ES')}
        </p>
      </header>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        <Card title="Ventas de la sesión">
          <div className="space-y-2">
            <div className="flex justify-between">
              <span className="text-gray-400">Total USD</span>
              <span className="font-bold text-green-400">
                {formatCurrency(report.totalSalesUSD, 'USD')}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Total Bs</span>
              <span className="font-bold text-green-400">
                {formatCurrency(report.totalSalesBs, 'Bs')}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Facturas</span>
              <span className="text-white">{report.totalInvoices}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-400">Anulaciones</span>
              <span className="text-white">{report.totalCancellations}</span>
            </div>
          </div>
        </Card>

        <Card title="Balance de efectivo">
          <div className="space-y-2">
            <BalanceRow
              label="Apertura USD"
              amount={report.openingBalanceUSD}
              currency="USD"
              formatCurrency={formatCurrency}
            />
            <BalanceRow
              label="Esperado USD"
              amount={report.expectedBalanceUSD}
              currency="USD"
              formatCurrency={formatCurrency}
            />
            {report.actualBalanceUSD !== undefined && (
              <>
                <BalanceRow
                  label="Real USD"
                  amount={report.actualBalanceUSD}
                  currency="USD"
                  formatCurrency={formatCurrency}
                />
                <BalanceRow
                  label="Diferencia USD"
                  amount={report.differenceUSD || 0}
                  currency="USD"
                  formatCurrency={formatCurrency}
                  emphasize
                />
              </>
            )}
            <BalanceRow
              label="Apertura Bs"
              amount={report.openingBalanceBs}
              currency="Bs"
              formatCurrency={formatCurrency}
            />
            <BalanceRow
              label="Esperado Bs"
              amount={report.expectedBalanceBs}
              currency="Bs"
              formatCurrency={formatCurrency}
            />
            {report.actualBalanceBs !== undefined && (
              <>
                <BalanceRow
                  label="Real Bs"
                  amount={report.actualBalanceBs}
                  currency="Bs"
                  formatCurrency={formatCurrency}
                />
                <BalanceRow
                  label="Diferencia Bs"
                  amount={report.differenceBs || 0}
                  currency="Bs"
                  formatCurrency={formatCurrency}
                  emphasize
                />
              </>
            )}
          </div>
        </Card>
      </div>

      <Card title="Ventas por método de pago">
        <div className="overflow-x-auto">
          <table className="w-full border border-gray-700">
            <thead className="bg-gray-700">
              <tr>
                <th className="p-3 text-left">Método</th>
                <th className="p-3 text-right">USD</th>
                <th className="p-3 text-right">Bs</th>
                <th className="p-3 text-right">Equivalente USD</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(report.totalSalesByMethod).map(([method, amounts]) => (
                <tr key={method} className="border-t border-gray-700">
                  <td className="p-3">{formatMethod(method)}</td>
                  <td className="p-3 text-right">
                    {formatCurrency(amounts.USD, 'USD')}
                  </td>
                  <td className="p-3 text-right">
                    {formatCurrency(amounts.Bs, 'Bs')}
                  </td>
                  <td className="p-3 text-right font-bold">
                    {formatCurrency(
                      amounts.USD + amounts.Bs / config.exchangeRate,
                      'USD'
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <Card title="Movimientos de caja">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <MovementSummary
            title="Ingresos"
            usd={report.totalIngresosUSD}
            bs={report.totalIngresosBs}
            currencyFormatter={formatCurrency}
            color="text-green-400"
          />
          <MovementSummary
            title="Egresos"
            usd={report.totalEgresosUSD}
            bs={report.totalEgresosBs}
            currencyFormatter={formatCurrency}
            color="text-red-400"
          />
        </div>
      </Card>

      {(onPrint || onDownload) && (
        <div className="flex justify-end space-x-3 border-t border-gray-700 pt-4">
          {onDownload && (
            <Button variant="secondary" onClick={() => onDownload(report)}>
              <ArrowDownTrayIcon className="mr-2 h-5 w-5" />
              Descargar
            </Button>
          )}
          {onPrint && (
            <Button variant="primary" onClick={() => onPrint(report)}>
              <PrinterIcon className="mr-2 h-5 w-5" />
              Imprimir
            </Button>
          )}
        </div>
      )}
    </div>
  )
}

interface BalanceRowProps {
  label: string
  amount: number
  currency: 'USD' | 'Bs'
  formatCurrency: (amount: number, currency: 'USD' | 'Bs') => string
  emphasize?: boolean
}

const BalanceRow: React.FC<BalanceRowProps> = ({
  label,
  amount,
  currency,
  formatCurrency,
  emphasize = false
}) => (
  <div className="flex justify-between">
    <span className="text-gray-400">{label}</span>
    <span className={emphasize
      ? amount >= 0 ? 'font-bold text-green-400' : 'font-bold text-red-400'
      : 'text-white'
    }>
      {formatCurrency(amount, currency)}
    </span>
  </div>
)

interface MovementSummaryProps {
  title: string
  usd: number
  bs: number
  currencyFormatter: (amount: number, currency: 'USD' | 'Bs') => string
  color: string
}

const MovementSummary: React.FC<MovementSummaryProps> = ({
  title,
  usd,
  bs,
  currencyFormatter,
  color
}) => (
  <div>
    <h4 className={`mb-2 font-medium ${color}`}>{title}</h4>
    <div className="space-y-1 text-sm">
      <div className="flex justify-between">
        <span className="text-gray-400">USD</span>
        <span className={color}>{currencyFormatter(usd, 'USD')}</span>
      </div>
      <div className="flex justify-between">
        <span className="text-gray-400">Bs</span>
        <span className={color}>{currencyFormatter(bs, 'Bs')}</span>
      </div>
    </div>
  </div>
)

export default CashReportComponent

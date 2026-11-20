import React, { useState } from 'react'
import { useCash } from '../../hooks/useCash'
import { useStore } from '../../store/store'
import type { CashCount, CashMovement, CashReport, CashSession } from '../../types/cash'
import OpenCashModal from '../../components/cash/OpenCashModal'
import CashCountModal from '../../components/cash/CashCountModal'
import CashReportComponent from '../../components/cash/CashReportComponent'
import Card from '../../components/common/Card'
import Button from '../../components/common/Button'
import Badge from '../../components/common/Badge'
import Modal from '../../components/common/Modal'
import Table, { type Column } from '../../components/common/Table'
import {
  BanknotesIcon,
  CalculatorIcon,
  ClockIcon,
  PlusIcon
} from '@/components/common/Icon'

const Cash: React.FC = () => {
  const {
    cashSessions,
    closeCash,
    addMovement,
    generateReport,
    getExpectedBalance
  } = useCash()
  const { currentUser, addNotification } = useStore()
  const [showOpenModal, setShowOpenModal] = useState(false)
  const [showCountModal, setShowCountModal] = useState(false)
  const [closeAfterCount, setCloseAfterCount] = useState(false)
  const [selectedReport, setSelectedReport] = useState<CashReport | null>(null)

  const activeSession = cashSessions.find(session => session.status === 'OPEN')
  const expectedBalance = activeSession
    ? getExpectedBalance(activeSession.id)
    : undefined

  const handleGenerateReport = () => {
    if (!activeSession) return
    const result = generateReport(activeSession.id, 'X')
    if (result.success && result.report) setSelectedReport(result.report)
  }

  const handleCountComplete = (count: CashCount) => {
    if (closeAfterCount && activeSession) {
      const result = closeCash(
        activeSession.id,
        count.USD.total,
        count.Bs.total,
        'Arqueo de cierre'
      )
      if (result.success && result.report) setSelectedReport(result.report)
    } else {
      addNotification({
        type: 'success',
        message: `Arqueo realizado: $${count.USD.total.toFixed(2)} y Bs. ${count.Bs.total.toFixed(2)}`
      })
    }
    setCloseAfterCount(false)
    setShowCountModal(false)
  }

  const handleAddMovement = () => {
    if (!activeSession) return

    const amountValue = window.prompt('Monto del movimiento:')
    if (amountValue === null) return
    const amount = Number.parseFloat(amountValue)
    if (!Number.isFinite(amount) || amount <= 0) {
      addNotification({ type: 'error', message: 'Ingrese un monto mayor a 0' })
      return
    }

    const description = window.prompt('Descripción del movimiento:')
    if (!description?.trim()) return

    const typeValue = window.prompt('Tipo de movimiento (INGRESO/EGRESO):')
    if (typeValue === null) return
    const type = typeValue.toUpperCase()
    if (type !== 'INGRESO' && type !== 'EGRESO') {
      addNotification({ type: 'error', message: 'El tipo debe ser INGRESO o EGRESO' })
      return
    }

    const currencyValue = window.prompt('Moneda (USD/Bs):')
    if (currencyValue === null) return
    const currency = currencyValue.toUpperCase()
    if (currency !== 'USD' && currency !== 'BS') {
      addNotification({ type: 'error', message: 'La moneda debe ser USD o Bs' })
      return
    }

    addMovement(activeSession.id, {
      type,
      category: type === 'INGRESO' ? 'AJUSTE_MANUAL' : 'GASTO',
      amount,
      currency: currency === 'USD' ? 'USD' : 'Bs',
      method: 'OTRO',
      description: description.trim(),
      userId: currentUser?.id || activeSession.userId,
      userName: currentUser?.name || activeSession.userName
    })
  }

  const handleDownloadReport = (report: CashReport) => {
    const file = new Blob([JSON.stringify(report, null, 2)], {
      type: 'application/json'
    })
    const url = URL.createObjectURL(file)
    const anchor = document.createElement('a')
    anchor.href = url
    anchor.download = `reporte-caja-${report.type}-${report.sessionId}.json`
    anchor.click()
    URL.revokeObjectURL(url)
  }

  const columns: Column<CashMovement>[] = [
    {
      key: 'timestamp',
      header: 'Fecha/Hora',
      render: timestamp => new Date(timestamp as Date).toLocaleString('es-ES')
    },
    { key: 'description', header: 'Descripción' },
    {
      key: 'amount',
      header: 'Monto',
      render: (amount, movement) => {
        const row = movement as CashMovement
        const sign = row.type === 'INGRESO' ? '+' : row.type === 'EGRESO' ? '-' : ''
        return (
          <span className={row.type === 'EGRESO' ? 'text-red-400' : 'text-green-400'}>
            {sign}{row.currency === 'USD' ? '$' : 'Bs. '}{Number(amount).toFixed(2)}
          </span>
        )
      }
    },
    { key: 'userName', header: 'Usuario' }
  ]

  const handleCashOpened = (_session: CashSession) => {
    setShowOpenModal(false)
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white">Gestión de Caja</h2>
          <p className="text-gray-400">Control de efectivo y turnos</p>
        </div>
        {activeSession ? (
          <Badge variant="success" size="sm">Caja abierta</Badge>
        ) : (
          <Badge variant="error" size="sm">Caja cerrada</Badge>
        )}
      </div>

      {activeSession ? (
        <>
          <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
            <Card title="Estado de caja">
              <div className="space-y-3">
                <InfoRow
                  label="Apertura"
                  value={new Date(activeSession.openedAt).toLocaleString('es-ES')}
                />
                <InfoRow label="Usuario" value={activeSession.userName} />
                <InfoRow
                  label="Saldo inicial USD"
                  value={`$${activeSession.openingBalanceUSD.toFixed(2)}`}
                />
                <InfoRow
                  label="Saldo inicial Bs"
                  value={`Bs. ${activeSession.openingBalanceBs.toFixed(2)}`}
                />
                <InfoRow
                  label="Esperado USD"
                  value={`$${(expectedBalance?.expectedBalanceUSD || 0).toFixed(2)}`}
                />
                <InfoRow
                  label="Esperado Bs"
                  value={`Bs. ${(expectedBalance?.expectedBalanceBs || 0).toFixed(2)}`}
                />
              </div>
            </Card>

            <Card title="Acciones rápidas">
              <div className="space-y-3">
                <Button
                  variant="primary"
                  className="w-full"
                  onClick={handleAddMovement}
                >
                  <PlusIcon className="mr-2 h-5 w-5" />
                  Agregar movimiento
                </Button>
                <Button
                  variant="secondary"
                  className="w-full"
                  onClick={() => {
                    setCloseAfterCount(false)
                    setShowCountModal(true)
                  }}
                >
                  <CalculatorIcon className="mr-2 h-5 w-5" />
                  Arqueo de efectivo
                </Button>
                <Button
                  variant="secondary"
                  className="w-full"
                  onClick={handleGenerateReport}
                >
                  <ClockIcon className="mr-2 h-5 w-5" />
                  Reporte X
                </Button>
              </div>
            </Card>

            <Card title="Cierre de caja">
              <div className="space-y-3">
                <p className="text-sm text-gray-400">
                  Realice el arqueo físico para generar el Reporte Z y cerrar la sesión.
                </p>
                <Button
                  variant="danger"
                  className="w-full"
                  onClick={() => {
                    setCloseAfterCount(true)
                    setShowCountModal(true)
                  }}
                >
                  <BanknotesIcon className="mr-2 h-5 w-5" />
                  Arqueo y cierre (Reporte Z)
                </Button>
              </div>
            </Card>
          </div>

          <Card title="Movimientos de la sesión">
            <Table
              data={activeSession.movements}
              columns={columns}
              emptyMessage="No hay movimientos en esta sesión"
            />
          </Card>
        </>
      ) : (
        <Card>
          <div className="py-8 text-center">
            <BanknotesIcon className="mx-auto mb-4 h-16 w-16 text-gray-500" />
            <h3 className="mb-2 text-lg font-medium text-gray-400">Caja cerrada</h3>
            <p className="mb-6 text-gray-500">
              Abra una caja para iniciar el control de efectivo del turno.
            </p>
            <Button variant="primary" onClick={() => setShowOpenModal(true)}>
              <BanknotesIcon className="mr-2 h-5 w-5" />
              Abrir caja
            </Button>
          </div>
        </Card>
      )}

      {cashSessions.some(session => session.status === 'CLOSED') && (
        <Card title="Historial de sesiones cerradas">
          <Table
            data={cashSessions
              .filter(session => session.status === 'CLOSED')
              .sort((a, b) =>
                new Date(b.openedAt).getTime() - new Date(a.openedAt).getTime()
              )}
            columns={[
              {
                key: 'openedAt',
                header: 'Apertura',
                render: value => new Date(value as Date).toLocaleString('es-ES')
              },
              { key: 'userName', header: 'Usuario' },
              {
                key: 'closingBalanceUSD',
                header: 'Cierre USD',
                render: value => `$${Number(value || 0).toFixed(2)}`
              },
              {
                key: 'differenceUSD',
                header: 'Diferencia USD',
                render: (value, session) => {
                  const difference = Number(value || 0)
                  return (
                    <span className={difference >= 0 ? 'text-green-400' : 'text-red-400'}>
                      {difference >= 0 ? '+' : ''}${difference.toFixed(2)}
                    </span>
                  )
                }
              }
            ]}
            emptyMessage="No hay sesiones cerradas"
          />
        </Card>
      )}

      <OpenCashModal
        isOpen={showOpenModal}
        onClose={() => setShowOpenModal(false)}
        onCashOpened={handleCashOpened}
      />
      {activeSession && expectedBalance && (
        <CashCountModal
          isOpen={showCountModal}
          onClose={() => {
            setShowCountModal(false)
            setCloseAfterCount(false)
          }}
          expectedUSD={expectedBalance.expectedBalanceUSD}
          expectedBs={expectedBalance.expectedBalanceBs}
          onCountComplete={handleCountComplete}
        />
      )}
      <Modal
        isOpen={selectedReport !== null}
        onClose={() => setSelectedReport(null)}
        title={`Reporte ${selectedReport?.type || ''} de Caja`}
        size="xl"
      >
        {selectedReport && (
          <CashReportComponent
            report={selectedReport}
            onPrint={() => window.print()}
            onDownload={handleDownloadReport}
          />
        )}
      </Modal>
    </div>
  )
}

interface InfoRowProps {
  label: string
  value: string
}

const InfoRow: React.FC<InfoRowProps> = ({ label, value }) => (
  <div className="flex justify-between gap-3">
    <span className="text-gray-400">{label}</span>
    <span className="text-right text-white">{value}</span>
  </div>
)

export default Cash

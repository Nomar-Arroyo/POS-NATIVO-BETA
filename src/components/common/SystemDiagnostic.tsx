import React, { useEffect, useState } from 'react'
import { useStore } from '../../store/store'
import OptimizedCard from './OptimizedCard'
import Button from './Button'
import Table, { type Column } from './Table'
import Badge from './Badge'
import Icon from './Icon'

type DiagnosticStatus = 'success' | 'warning' | 'error' | 'info'

interface DiagnosticRow {
  metric: string
  value: string
  status: DiagnosticStatus
}

interface SystemInfo {
  memoryUsageMB: number | null
  storageSizeBytes: number | null
}

const formatSize = (bytes: number | null): string =>
  bytes === null ? 'No disponible' : `${(bytes / 1024).toFixed(2)} KB`

const SystemDiagnostic: React.FC = () => {
  const productsCount = useStore(state => state.products.length)
  const invoicesCount = useStore(state => state.facturas.length)
  const ordersCount = useStore(state => state.orders.length)
  const cashSessions = useStore(state => state.cashSessions)
  const [isOpen, setIsOpen] = useState(false)
  const [systemInfo, setSystemInfo] = useState<SystemInfo>({
    memoryUsageMB: null,
    storageSizeBytes: null
  })

  useEffect(() => {
    const performanceWithMemory = performance as Performance & {
      memory?: { usedJSHeapSize: number }
    }
    const memoryUsageMB = performanceWithMemory.memory
      ? performanceWithMemory.memory.usedJSHeapSize / 1048576
      : null
    let storageSizeBytes: number | null = null

    try {
      storageSizeBytes = new Blob([
        localStorage.getItem('pos_nativo_beta_v2') || ''
      ]).size
    } catch (error) {
      console.error('No se pudo medir el almacenamiento local:', error)
    }

    setSystemInfo({ memoryUsageMB, storageSizeBytes })
  }, [])

  const rows: DiagnosticRow[] = [
    { metric: 'Estado de la aplicación', value: 'Activa', status: 'success' },
    {
      metric: 'Memoria usada',
      value: systemInfo.memoryUsageMB === null
        ? 'No disponible'
        : `${systemInfo.memoryUsageMB.toFixed(2)} MB`,
      status: systemInfo.memoryUsageMB !== null && systemInfo.memoryUsageMB > 100
        ? 'warning'
        : 'info'
    },
    {
      metric: 'Almacenamiento',
      value: formatSize(systemInfo.storageSizeBytes),
      status: systemInfo.storageSizeBytes === null ? 'warning' : 'info'
    },
    {
      metric: 'Datos cargados',
      value: `${productsCount} productos, ${invoicesCount} facturas, ${ordersCount} órdenes`,
      status: 'info'
    },
    {
      metric: 'Sesiones de caja',
      value: `${cashSessions.length} sesiones`,
      status: cashSessions.some(session => session.status === 'OPEN')
        ? 'success'
        : 'info'
    }
  ]

  const columns: Column<DiagnosticRow>[] = [
    { key: 'metric', header: 'Métrica' },
    { key: 'value', header: 'Valor' },
    {
      key: 'status',
      header: 'Estado',
      render: (_value, row) => (
        <Badge variant={row.status} size="sm">
          {row.status.toUpperCase()}
        </Badge>
      )
    }
  ]

  return (
    <div className="fixed bottom-4 right-4 z-40 hidden sm:block">
      {isOpen ? (
        <OptimizedCard
          title="Diagnóstico del sistema"
          className="max-h-[85vh] w-[min(90vw,42rem)] overflow-y-auto shadow-xl"
          actions={(
            <Button
              type="button"
              size="sm"
              variant="secondary"
              onClick={() => window.location.reload()}
              aria-label="Reiniciar aplicación"
            >
              <Icon name="refresh" size={16} className="mr-1" />
              Reiniciar
            </Button>
          )}
        >
          <div className="space-y-4">
            <Table
              data={rows}
              columns={columns}
              emptyMessage="No hay datos de diagnóstico"
            />
            <div className="grid grid-cols-3 gap-3 text-center">
              <div className="rounded-lg bg-gray-700 p-3">
                <Icon name="chart" size={28} color="#159FA2" className="mx-auto mb-2" />
                <div className="text-sm text-gray-300">Rendimiento</div>
                <div className="font-medium text-white">
                  {systemInfo.memoryUsageMB !== null && systemInfo.memoryUsageMB > 100
                    ? 'Revisar'
                    : 'Normal'}
                </div>
              </div>
              <div className="rounded-lg bg-gray-700 p-3">
                <Icon name="backup" size={28} color="#159FA2" className="mx-auto mb-2" />
                <div className="text-sm text-gray-300">Persistencia</div>
                <div className="font-medium text-white">
                  {systemInfo.storageSizeBytes === null ? 'No disponible' : 'Activa'}
                </div>
              </div>
              <div className="rounded-lg bg-gray-700 p-3">
                <Icon name="check" size={28} color="#159FA2" className="mx-auto mb-2" />
                <div className="text-sm text-gray-300">Operación</div>
                <div className="font-medium text-white">Normal</div>
              </div>
            </div>
          </div>
          <div className="mt-4 flex justify-end">
            <Button
              type="button"
              size="sm"
              variant="secondary"
              onClick={() => setIsOpen(false)}
            >
              Cerrar diagnóstico
            </Button>
          </div>
        </OptimizedCard>
      ) : (
        <Button
          type="button"
          variant="secondary"
          size="sm"
          onClick={() => setIsOpen(true)}
          className="max-sm:h-10 max-sm:w-10 max-sm:justify-center max-sm:rounded-full max-sm:p-0"
          aria-expanded={isOpen}
          aria-label="Abrir diagnóstico del sistema"
          title="Diagnóstico del sistema"
        >
          <Icon name="info" size={16} className="sm:mr-2" />
          <span className="hidden sm:inline">Diagnóstico</span>
        </Button>
      )}
    </div>
  )
}

export default SystemDiagnostic

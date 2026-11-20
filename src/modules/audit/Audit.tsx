import React, { useState, useMemo } from 'react'
import { useStore } from '../../store/store'
import auditService from '../../services/audit/auditService'
import AuditLogItem from '../../components/audit/AuditLogItem'
import AuditFilters from '../../components/audit/AuditFilters'
import Card from '../../components/common/Card'
import Button from '../../components/common/Button'
import Badge from '../../components/common/Badge'
import { 
  ArrowDownTrayIcon,
  CalendarIcon
} from '@/components/common/Icon'

const Audit: React.FC = () => {
  const { auditLogs } = useStore()
  const [filters, setFilters] = useState({
    search: '',
    category: 'TODAS',
    severity: 'TODOS',
    user: '',
    startDate: '',
    endDate: ''
  })

  // Filtrar logs
  const filteredLogs = useMemo(() => {
    let result = auditLogs

    if (filters.search) {
      const searchLower = filters.search.toLowerCase()
      result = result.filter(log =>
        log.action.toLowerCase().includes(searchLower) ||
        log.user.toLowerCase().includes(searchLower) ||
        JSON.stringify(log.details).toLowerCase().includes(searchLower)
      )
    }

    if (filters.category !== 'TODAS') {
      result = result.filter(log => log.category === filters.category)
    }

    if (filters.severity !== 'TODOS') {
      result = result.filter(log => log.severity === filters.severity)
    }

    if (filters.startDate) {
      const startDate = new Date(filters.startDate)
      result = result.filter(log => new Date(log.timestamp) >= startDate)
    }

    if (filters.endDate) {
      const endDate = new Date(filters.endDate)
      endDate.setHours(23, 59, 59, 999)
      result = result.filter(log => new Date(log.timestamp) <= endDate)
    }

    // Ordenar por timestamp descendente
    return result.sort((a, b) => 
      new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime()
    )
  }, [auditLogs, filters])

  const stats = auditService.getAuditStats(7)

  const handleClearFilters = () => {
    setFilters({
      search: '',
      category: 'TODAS',
      severity: 'TODOS',
      user: '',
      startDate: '',
      endDate: ''
    })
  }

  const handleExport = () => {
    const dataStr = auditService.exportLogs()
    const dataBlob = new Blob([dataStr], { type: 'application/json' })
    const url = URL.createObjectURL(dataBlob)
    
    const link = document.createElement('a')
    link.href = url
    link.download = `audit-logs-${new Date().toISOString().split('T')[0]}.json`
    link.click()
    
    URL.revokeObjectURL(url)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-white">Auditoría del Sistema</h2>
          <p className="text-gray-400">Registro de todas las actividades del sistema</p>
        </div>

        <div className="flex items-center space-x-3">
          <Button variant="secondary" onClick={handleExport}>
            <ArrowDownTrayIcon className="h-5 w-5 mr-2" />
            Exportar
          </Button>
        </div>
      </div>

      {/* Estadísticas rápidas */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Card>
          <div className="text-center">
            <div className="text-2xl font-bold text-amalfi-turquoise">
              {stats.totalLogs}
            </div>
            <div className="text-xs text-gray-400">Total Registros (7 días)</div>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <div className="text-2xl font-bold text-yellow-400">
              {stats.bySeverity.WARNING || 0}
            </div>
            <div className="text-xs text-gray-400">Advertencias</div>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <div className="text-2xl font-bold text-red-400">
              {stats.bySeverity.ERROR || 0}
            </div>
            <div className="text-xs text-gray-400">Errores</div>
          </div>
        </Card>
        <Card>
          <div className="text-center">
            <div className="text-2xl font-bold text-amalfi-turquoise">
              {Object.keys(stats.byUser).length}
            </div>
            <div className="text-xs text-gray-400"> Usuarios Activos</div>
          </div>
        </Card>
      </div>

      {/* Filtros */}
      <AuditFilters
        filters={filters}
        onFiltersChange={setFilters}
        onClear={handleClearFilters}
      />

      {/* Lista de logs */}
      <Card title="Registro de Auditoría" actions={
        <Badge variant="info" size="sm">
          {filteredLogs.length} registros
        </Badge>
      }>
        {filteredLogs.length > 0 ? (
          <div className="space-y-3 max-h-[600px] overflow-y-auto">
            {filteredLogs.map((log) => (
              <AuditLogItem key={log.id} log={log} />
            ))}
          </div>
        ) : (
          <div className="text-center py-8">
            <CalendarIcon className="h-12 w-12 text-gray-500 mx-auto mb-2" />
            <p className="text-gray-400">No hay registros de auditoría</p>
            <p className="text-sm text-gray-500 mt-1">
              Prueba a cambiar los filtros o realizar alguna acción en el sistema
            </p>
          </div>
        )}
      </Card>

      {/* Estadísticas detalladas */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <Card title="Por Categoría">
          <div className="space-y-3">
            {Object.entries(stats.byCategory).map(([category, count]) => (
              <div key={category} className="flex items-center justify-between">
                <span className="text-gray-300">{category}</span>
                <div className="flex items-center space-x-2">
                  <div className="w-32 bg-gray-700 rounded-full h-2">
                    <div 
                      className="h-2 bg-amalfi-turquoise rounded-full"
                      style={{ 
                        width: `${(count / stats.totalLogs) * 100}%` 
                      }}
                    ></div>
                  </div>
                  <span className="text-sm font-medium text-white w-8">
                    {count}
                  </span>
                </div>
              </div>
            ))}
          </div>
        </Card>

        <Card title=" Acciones Más Comunes">
          <div className="space-y-2">
            {stats.topActions.slice(0, 5).map((action, index) => (
              <div key={action.action} className="flex items-center justify-between">
                <span className="text-gray-300 text-sm">
                  {index + 1}. {action.action}
                </span>
                <Badge variant="info" size="sm">
                  {action.count}
                </Badge>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  )
}

export default Audit
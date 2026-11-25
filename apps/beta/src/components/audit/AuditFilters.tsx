import React from 'react'
import { AUDIT_CATEGORIES, AUDIT_SEVERITY } from '../../types'
import Input from '../common/Input'
import Select from '../common/Select'
import Button from '../common/Button'
import Card from '../common/Card'

interface AuditFiltersProps {
  filters: {
    search: string
    category: string
    severity: string
    user: string
    startDate: string
    endDate: string
  }
  onFiltersChange: (filters: any) => void
  onClear: () => void
}

const AuditFilters: React.FC<AuditFiltersProps> = ({ 
  filters, 
  onFiltersChange, 
  onClear 
}) => {
  const categoryOptions = [
    { value: 'TODAS', label: 'Todas las categorías' },
    ...Object.entries(AUDIT_CATEGORIES).map(([key, value]) => ({
      value,
      label: value
    }))
  ]

  const severityOptions = [
    { value: 'TODOS', label: 'Todos los niveles' },
    ...Object.entries(AUDIT_SEVERITY).map(([key, value]) => ({
      value,
      label: value
    }))
  ]

  const handleFilterChange = (field: string, value: string) => {
    onFiltersChange({ ...filters, [field]: value })
  }

  return (
    <Card title="Filtros de Auditoría">
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Input
          placeholder="Buscar en descripción..."
          value={filters.search}
          onChange={(e) => handleFilterChange('search', e.target.value)}
        />

        <Select
          options={categoryOptions}
          value={filters.category}
          onChange={(e) => handleFilterChange('category', e.target.value)}
        />

        <Select
          options={severityOptions}
          value={filters.severity}
          onChange={(e) => handleFilterChange('severity', e.target.value)}
        />
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
        <Input
          type="date"
          label="Fecha inicio"
          value={filters.startDate}
          onChange={(e) => handleFilterChange('startDate', e.target.value)}
        />

        <Input
          type="date"
          label="Fecha fin"
          value={filters.endDate}
          onChange={(e) => handleFilterChange('endDate', e.target.value)}
        />

        <div className="flex items-end">
          <Button variant="secondary" onClick={onClear} className="w-full">
            Limpiar Filtros
          </Button>
        </div>
      </div>
    </Card>
  )
}

export default AuditFilters
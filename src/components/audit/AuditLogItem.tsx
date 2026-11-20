import React from 'react'
import { AuditLog } from '../../types'
import Badge from '../common/Badge'
import {
  ClockIcon,
  CheckCircleIcon,
  ExclamationTriangleIcon,
  XCircleIcon
} from '@/components/common/Icon'

interface AuditLogItemProps {
  log: AuditLog
  onInspect?: (log: AuditLog) => void
}

const categoryVariants: Record<
  AuditLog['category'],
  'info' | 'success' | 'warning' | 'default'
> = {
  PRODUCT: 'info',
  TABLE: 'success',
  ORDER: 'warning',
  PAYMENT: 'default',
  CASH: 'default',
  SYSTEM: 'default',
  USER: 'default'
}

const AuditLogItem: React.FC<AuditLogItemProps> = ({ log, onInspect }) => {
  const getSeverityIcon = (severity: AuditLog['severity']) => {
    switch (severity) {
      case 'INFO':
        return <ClockIcon className="h-5 w-5 text-amalfi-turquoise" />
      case 'WARNING':
        return <ExclamationTriangleIcon className="h-5 w-5 text-yellow-400" />
      case 'ERROR':
        return <XCircleIcon className="h-5 w-5 text-red-400" />
      default:
        return <CheckCircleIcon className="h-5 w-5 text-gray-400" />
    }
  }

  const getSeverityBadge = (severity: AuditLog['severity']) => {
    switch (severity) {
      case 'INFO':
        return <Badge variant="info" size="sm">INFO</Badge>
      case 'WARNING':
        return <Badge variant="warning" size="sm">ADVERTENCIA</Badge>
      case 'ERROR':
        return <Badge variant="error" size="sm">ERROR</Badge>
      default:
        return <Badge variant="default" size="sm">{severity}</Badge>
    }
  }

  const formatTimestamp = (date: Date) => new Date(date).toLocaleString('es-ES', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  })

  const details = typeof log.details === 'string'
    ? log.details
    : JSON.stringify(log.details, null, 2)

  return (
    <div
      role={onInspect ? 'button' : undefined}
      tabIndex={onInspect ? 0 : undefined}
      className={`
        p-3 rounded-lg border border-gray-700 hover:bg-gray-700 transition-colors
        ${onInspect ? 'cursor-pointer focus:outline-none focus:ring-2 focus:ring-amalfi-turquoise' : ''}
        ${log.severity === 'ERROR' ? 'bg-red-900 bg-opacity-10' : ''}
        ${log.severity === 'WARNING' ? 'bg-yellow-900 bg-opacity-10' : ''}
      `}
      onClick={() => onInspect?.(log)}
      onKeyDown={event => {
        if (onInspect && (event.key === 'Enter' || event.key === ' ')) {
          event.preventDefault()
          onInspect(log)
        }
      }}
    >
      <div className="flex items-start space-x-3">
        <div className="flex-shrink-0">
          {getSeverityIcon(log.severity)}
        </div>

        <div className="flex-1 min-w-0">
          <div className="flex items-center space-x-2 mb-1">
            <p className="text-sm font-medium text-white truncate">
              {log.action}
            </p>
            {getSeverityBadge(log.severity)}
            <Badge variant={categoryVariants[log.category]} size="sm">
              {log.category}
            </Badge>
          </div>

          <p className="text-sm text-gray-300 mb-2 whitespace-pre-wrap break-words">
            {details}
          </p>

          <div className="flex items-center justify-between text-xs text-gray-400">
            <div className="flex items-center space-x-4">
              <span>Usuario: {log.user}</span>
              {log.tableId && <span>Mesa: {log.tableId}</span>}
              {log.orderId && <span>Orden: {log.orderId}</span>}
            </div>
            <span>{formatTimestamp(log.timestamp)}</span>
          </div>
        </div>
      </div>
    </div>
  )
}

export default AuditLogItem

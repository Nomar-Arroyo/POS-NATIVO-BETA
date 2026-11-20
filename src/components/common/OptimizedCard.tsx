import React, { memo } from 'react'
import Button from './Button'
import Icon from './Icon'

interface OptimizedCardProps {
  children: React.ReactNode
  title?: string
  actions?: React.ReactNode
  className?: string
  padding?: 'none' | 'sm' | 'md' | 'lg'
  loading?: boolean
  error?: string
  onRetry?: () => void
}

const paddings = {
  none: '',
  sm: 'p-3',
  md: 'p-4',
  lg: 'p-6'
}

const OptimizedCard: React.FC<OptimizedCardProps> = memo(({
  children,
  title,
  actions,
  className = '',
  padding = 'md',
  loading = false,
  error,
  onRetry
}) => {
  const shellClassName = `rounded-lg border border-gray-700 bg-gray-800 ${className}`

  if (error) {
    return (
      <section className={shellClassName} role="alert">
        <div className="p-4 text-center">
          <div className="mb-2 flex justify-center text-red-400">
            <Icon name="alert" size={24} />
          </div>
          <p className="mb-3 text-sm text-gray-300">{error}</p>
          {onRetry && (
            <Button size="sm" variant="secondary" onClick={onRetry}>
              Reintentar
            </Button>
          )}
        </div>
      </section>
    )
  }

  if (loading) {
    return (
      <section className={`${shellClassName} p-4`} aria-busy="true" aria-label="Cargando">
        <div className="animate-pulse space-y-3">
          <div className="h-4 w-1/4 rounded bg-gray-700" />
          <div className="space-y-2">
            <div className="h-4 w-full rounded bg-gray-700" />
            <div className="h-4 w-3/4 rounded bg-gray-700" />
          </div>
        </div>
      </section>
    )
  }

  return (
    <section className={shellClassName}>
      {(title || actions) && (
        <div className="flex items-center justify-between border-b border-gray-700 p-4">
          {title && <h3 className="text-lg font-semibold text-white">{title}</h3>}
          {actions && <div className="flex items-center gap-2">{actions}</div>}
        </div>
      )}
      <div className={paddings[padding]}>{children}</div>
    </section>
  )
})

OptimizedCard.displayName = 'OptimizedCard'

export default OptimizedCard

import React from 'react'

interface CardProps {
  children: React.ReactNode
  title?: string
  actions?: React.ReactNode
  className?: string
  padding?: 'none' | 'sm' | 'md' | 'lg'
}

const Card: React.FC<CardProps> = ({ 
  children, 
  title, 
  actions,
  className = '',
  padding = 'md' 
}) => {
  const paddings = {
    none: '',
    sm: 'p-3',
    md: 'p-4',
    lg: 'p-6'
  }

  return (
    <div className={`bg-gray-800 rounded-lg border border-gray-700 ${className}`}>
      {(title || actions) && (
        <div className="flex items-center justify-between p-4 border-b border-gray-700">
          {title && <h3 className="text-lg font-semibold text-white">{title}</h3>}
          {actions && <div className="flex space-x-2">{actions}</div>}
        </div>
      )}
      <div className={paddings[padding]}>{children}</div>
    </div>
  )
}

export default Card
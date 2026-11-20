import React from 'react'

interface EmptyStateProps {
  title: string
  description: string
  icon?: React.ReactNode
  action?: React.ReactNode
}

const EmptyState: React.FC<EmptyStateProps> = ({ 
  title, 
  description, 
  icon,
  action 
}) => {
  return (
    <div className="flex flex-col items-center justify-center py-12 px-4 text-center">
      {icon && (
        <div className="flex-shrink-0 w-16 h-16 bg-gray-700 rounded-full flex items-center justify-center mb-4">
          <div className="text-gray-400">{icon}</div>
        </div>
      )}
      <h3 className="text-lg font-medium text-white mb-2">{title}</h3>
      <p className="text-gray-400 mb-6 max-w-sm">{description}</p>
      {action}
    </div>
  )
}

export default EmptyState
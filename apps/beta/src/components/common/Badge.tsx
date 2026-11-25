import React from 'react'

interface BadgeProps {
  children: React.ReactNode
  variant?: 'success' | 'warning' | 'error' | 'info' | 'default'
  size?: 'sm' | 'md' | 'lg'
  className?: string
}

const Badge: React.FC<BadgeProps> = ({ 
  children, 
  variant = 'default', 
  size = 'md',
  className = '' 
}) => {
  const variants = {
    success: 'bg-green-900 text-green-300 border-green-700',
    warning: 'bg-yellow-900 text-yellow-300 border-yellow-700',
    error: 'bg-red-900 text-red-300 border-red-700',
    info: 'bg-amalfi-deep text-white border-amalfi-turquoise',
    default: 'bg-gray-700 text-gray-300 border-gray-600'
  }
  
  const sizes = {
    sm: 'px-2 py-0.5 text-xs',
    md: 'px-2.5 py-1 text-sm',
    lg: 'px-3 py-1.5 text-base'
  }

  return (
    <span className={`
      inline-flex items-center font-medium rounded-full border
      ${variants[variant]} ${sizes[size]} ${className}
    `}>
      {children}
    </span>
  )
}

export default Badge
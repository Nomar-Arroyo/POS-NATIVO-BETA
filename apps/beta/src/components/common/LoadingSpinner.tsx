import React from 'react'

interface LoadingSpinnerProps {
  size?: 'sm' | 'md' | 'lg'
  color?: 'white' | 'turquoise'
  text?: string
  className?: string
}

const LoadingSpinner: React.FC<LoadingSpinnerProps> = ({ 
  size = 'md',
  color = 'white',
  text,
  className = ''
}) => {
  const sizes = {
    sm: 'h-4 w-4',
    md: 'h-8 w-8',
    lg: 'h-12 w-12'
  }
  
  const colors = {
    white: 'text-white',
    turquoise: 'text-amalfi-turquoise'
  }

  return (
    <div className={`flex flex-col items-center justify-center ${className}`}>
      <div className={`
        animate-spin rounded-full border-2 border-transparent
        ${sizes[size]} ${colors[color]}
      `} style={{
        borderColor: 'transparent',
       borderTopColor: 'currentColor',
        borderRightColor: 'currentColor'
      }}></div>
      {text && <p className="mt-2 text-sm text-gray-400">{text}</p>}
    </div>
  )
}

export default LoadingSpinner
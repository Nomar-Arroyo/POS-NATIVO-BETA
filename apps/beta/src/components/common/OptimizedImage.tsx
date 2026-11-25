import React, { useEffect, useState } from 'react'

interface OptimizedImageProps {
  src: string
  alt: string
  className?: string
  placeholder?: string
  width?: number
  height?: number
  lazy?: boolean
  onLoadError?: (error: string) => void
}

const OptimizedImage: React.FC<OptimizedImageProps> = ({
  src,
  alt,
  className = '',
  placeholder,
  width,
  height,
  lazy = true,
  onLoadError
}) => {
  const [hasError, setHasError] = useState(false)

  useEffect(() => {
    setHasError(false)
  }, [src])

  const handleError = () => {
    setHasError(true)
    onLoadError?.(`No se pudo cargar la imagen: ${src}`)
  }

  if (hasError) {
    if (placeholder) {
      return (
        <div
          className={className}
          role="img"
          aria-label={alt}
          style={{
            width,
            height,
            backgroundImage: `url("${placeholder}")`,
            backgroundSize: 'cover',
            backgroundPosition: 'center'
          }}
        />
      )
    }

    return (
      <div
        className={`flex items-center justify-center bg-gray-800 text-sm text-gray-400 ${className}`}
        role="img"
        aria-label={alt}
        style={{ width, height }}
      >
        Imagen no disponible
      </div>
    )
  }

  return (
    <img
      src={src}
      alt={alt}
      width={width}
      height={height}
      className={className}
      loading={lazy ? 'lazy' : 'eager'}
      decoding="async"
      onError={handleError}
    />
  )
}

export default OptimizedImage

import { useMemo } from 'react'
import { useProducts } from './useProducts'

export const useQuickProducts = () => {
  const { getActiveProducts, getProductsByStation } = useProducts()

  const quickProducts = useMemo(() => {
    const active = getActiveProducts()
    
    return {
      // Productos más vendidos (simulado - en una app real vendría de órdenes)
      popular: active
        .sort((a, b) => (b.stock || 0) - (a.stock || 0))
        .slice(0, 8),

      // Por estación
      kitchen: getProductsByStation('COCINA'),
      bar: getProductsByStation('BARRA'),

      // Búsqueda rápida por inicial
      getByInitial: (initial: string) => {
        return active.filter(p => 
          p.name.toLowerCase().startsWith(initial.toLowerCase())
        ).slice(0, 5)
      },

      // Productos bajos de stock (alertas)
      lowStock: active.filter(p => 
        (p.stock || 0) > 0 && (p.stock || 0) < 10
      )
    }
  }, [getActiveProducts, getProductsByStation])

  return quickProducts
}

export default useQuickProducts
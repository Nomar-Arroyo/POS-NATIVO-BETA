import storageService from '../storage/storageService'
import { demoProducts, demoCategories } from './demoProducts'

class InitializeService {
  // Inicializar datos de demostración
  initializeDemoData(): boolean {
    try {
      const existingProducts = storageService.getProducts()
      
      if (existingProducts.length === 0) {
        // Cargar productos de demostración
        storageService.setProducts(demoProducts)
        
        // Cargar categorías
        storageService.setCategories(demoCategories)
        
        console.log('Datos de demostración inicializados correctamente')
        return true
      }
      
      return false // Ya existen datos
    } catch (error) {
      console.error('Error inicializando datos:', error)
      return false
    }
  }

  // Verificar si hay datos
  hasData(): boolean {
    return storageService.getProducts().length > 0
  }

  // Resetear todos los datos
  resetAllData(): boolean {
    if (confirm('¿Está seguro de eliminar TODOS los datos? Esta acción no se puede deshacer.')) {
      storageService.resetDemoData()
      return true
    }
    return false
  }
}

export default new InitializeService()
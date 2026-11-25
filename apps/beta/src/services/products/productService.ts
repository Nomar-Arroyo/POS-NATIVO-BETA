import storageService from '../storage/storageService'
import { Product, Category } from '../../types'
import auditService from '../audit/auditService'

class ProductService {
  // Obtener todos los productos
  getProducts(): Product[] {
    return storageService.getProducts()
  }

  // Obtener producto por ID
  getProduct(id: string): Product | undefined {
    return storageService.getProduct(id)
  }

  // Obtener productos por categoría
  getProductsByCategory(categoryId: string): Product[] {
    return this.getProducts().filter(p => p.category === categoryId)
  }

  // Obtener productos activos y disponibles
  getActiveProducts(): Product[] {
    return this.getProducts().filter(p => p.active && p.available)
  }

  // Obt productos por estación
  getProductsByStation(station: 'COCINA' | 'BARRA'): Product[] {
    return this.getActiveProducts().filter(p => p.station === station)
  }

  // Buscar productos
  searchProducts(query: string): Product[] {
    const searchTerm = query.toLowerCase().trim()
    if (!searchTerm) return this.getActiveProducts()

    return this.getActiveProducts().filter(product =>
      product.name.toLowerCase().includes(searchTerm) ||
      product.description.toLowerCase().includes(searchTerm) ||
      product.category.toLowerCase().includes(searchTerm)
    )
  }

  // Agregar producto
  addProduct(productData: Omit<Product, 'id'>): Product {
    // Validaciones
    this.validateProduct(productData)

    const newProduct: Product = {
      ...productData,
      id: `prod-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`
    }

    storageService.addProduct(newProduct)
    
    auditService.logProductAction('CREAR', newProduct.id, {
      productName: newProduct.name,
      price: newProduct.price,
      category: newProduct.category
    })

    return newProduct
  }

  // Actualizar producto
  updateProduct(id: string, updates: Partial<Product>): Product | null {
    const existingProduct = this.getProduct(id)
    if (!existingProduct) {
      throw new Error(`Producto no encontrado: ${id}`)
    }

    // Validar datos actualizados
    const updatedData = { ...existingProduct, ...updates }
    this.validateProduct(updatedData)

    storageService.updateProduct(id, updates)

    auditService.logProductAction('ACTUALIZAR', id, {
      productName: updatedData.name,
      changes: updates
    })

    return updatedData
  }

  // Eliminar producto
  deleteProduct(id: string): boolean {
    const product = this.getProduct(id)
    if (!product) {
      throw new Error(`Producto no encontrado: ${id}`)
    }

    // Soft delete: marcar como inACTIVO
    this.updateProduct(id, { active: false, available: false })

    auditService.logProductAction('ELIMINAR', id, {
      productName: product.name
    })

    return true
  }

  // Actualizar stock
  updateStock(id: string, newStock: number): Product | null {
    if (newStock < 0) {
      throw new Error('El stock no puede ser negativo')
    }

    const product = this.getProduct(id)
    if (!product) {
      throw new Error(`Producto no encontrado: ${id}`)
    }

    const updates: Partial<Product> = { 
      stock: newStock,
      available: newStock > 0 
    }

    return this.updateProduct(id, updates)
  }

  // Reducir stock (cuando se vende un producto)
  reduceStock(id: string, quantity: number): Product | null {
    const product = this.getProduct(id)
    if (!product) {
      throw new Error(`Producto no encontrado: ${id}`)
    }

    const currentStock = product.stock || 0
    const newStock = Math.max(0, currentStock - quantity)
    
    return this.updateStock(id, newStock)
  }

  // Validar producto
  private validateProduct(product: Partial<Product>): void {
    const errors: string[] = []

    if (!product.name || product.name.trim().length < 2) {
      errors.push('El nombre debe tener al menos 2 caracteres')
    }

    if (!product.description || product.description.trim().length < 5) {
      errors.push('La descripción debe tener al menos 5 caracteres')
    }

    if (product.price === undefined || product.price <= 0) {
      errors.push('El precio debe ser mayor a 0')
    }

    if (!product.category) {
      errors.push('La categoría es obligatoria')
    }

    if (!product.station) {
      errors.push('La estación es obligatoria')
    }

    if (errors.length > 0) {
      throw new Error(`Error de validación: ${errors.join(', ')}`)
    }
  }

  // Obtener categorías
  getCategories(): Category[] {
    return storageService.getCategories() || []
  }

  // Agregar categoría
  addCategory(category: Omit<Category, 'id'>): Category {
    const newCategory: Category = {
      ...category,
      id: `cat-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`
    }
    
    // Guardar en storage (las categorías se guardan con los productos)
    // Nota: Las categorías se guardan separadamente en storageService
    // Por ahora las mantenemos en el storage
    
    return newCategory
  }

  // Estadísticas del catálogo
  getCatalogStats(): {
    totalProducts: number;
    activeProducts: number;
    outOfStock: number;
    categories: number;
    productsByCategory: Record<string, number>;
    productsByStation: Record<string, number>;
  } {
    const products = this.getProducts()
    const categories = this.getCategories()

    const productsByCategory: Record<string, number> = {}
    const productsByStation: Record<string, number> = {}

    products.forEach(product => {
      // Por categoría
      productsByCategory[product.category] = (productsByCategory[product.category] || 0) + 1
      
      // Por estación
      productsByStation[product.station] = (productsByStation[product.station] || 0) + 1
    })

    return {
      totalProducts: products.length,
      activeProducts: products.filter(p => p.active).length,
      outOfStock: products.filter(p => p.stock !== undefined && p.stock <= 0).length,
      categories: categories.length,
      productsByCategory,
      productsByStation
    }
  }
}

export default new ProductService()
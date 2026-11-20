import { useMemo } from 'react'
import { useStore } from '../store/store'
import productService from '../services/products/productService'
import { Product, Category } from '../types'

export const useProducts = () => {
  const { 
    products, 
    categories,
    addProduct, 
    updateProduct, 
    deleteProduct,
    setProducts,
    setCategories
  } = useStore()

  const actions = useMemo(() => ({
    // Obtener productos activos
    getActiveProducts: () => {
      return products.filter(p => p.active && p.available)
    },

    getProductsByStation: (station: Product['station']) =>
      products.filter(p => p.active && p.available && p.station === station),

    // Buscar productos
    searchProducts: (query: string) => {
      return productService.searchProducts(query)
    },

    // Agregar producto
    addProduct: (productData: Omit<Product, 'id'>) => {
      try {
        const newProduct = productService.addProduct(productData)
        addProduct(newProduct)
        return { success: true, product: newProduct }
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Actualizar producto
    updateProduct: (id: string, updates: Partial<Product>) => {
      try {
        const updatedProduct = productService.updateProduct(id, updates)
        if (updatedProduct) {
          updateProduct(id, updates)
          return { success: true, product: updatedProduct }
        }
        throw new Error('Producto no encontrado')
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Eliminar producto
    deleteProduct: (id: string) => {
      try {
        productService.deleteProduct(id)
        deleteProduct(id)
        return { success: true }
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Actualizar stock
    updateStock: (id: string, newStock: number) => {
      try {
        const updatedProduct = productService.updateStock(id, newStock)
        if (updatedProduct) {
          updateProduct(id, { stock: newStock, available: newStock > 0 })
          return { success: true, product: updatedProduct }
        }
        throw new Error('Producto no encontrado')
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Reducir stock
    reduceStock: (id: string, quantity: number) => {
      try {
        const updatedProduct = productService.reduceStock(id, quantity)
        if (updatedProduct) {
          updateProduct(id, { 
            stock: updatedProduct.stock,
            available: updatedProduct.available
          })
          return { success: true, product: updatedProduct }
        }
        throw new Error('Producto no encontrado')
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Obtener categorías
    getCategories: () => categories,

    // Agregar categoría
    addCategory: (categoryData: Omit<Category, 'id'>) => {
      const newCategory: Category = {
        ...categoryData,
        id: `cat-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`
      }
      
      const newCategories = [...categories, newCategory]
      setCategories(newCategories)
      return newCategory
    },

    // Estadísticas
    getStats: () => productService.getCatalogStats()
  }), [products, categories, addProduct, updateProduct, deleteProduct, setProducts, setCategories])

  return {
    products,
    categories,
    ...actions
  }
}

export default useProducts
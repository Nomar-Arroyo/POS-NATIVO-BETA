import { useMemo } from 'react'
import { useStore } from '../store/store'
import tableService from '../services/tables/tableService'
import { Table } from '../types'

export const useTables = () => {
  const { 
    tables, 
    selectedTable,
    updateTable, 
    setSelectedTable
  } = useStore()

  const actions = useMemo(() => ({
    // Obtener todas las mesas
    getAll: () => tables,

    // Obtener mesa por ID
    getTable: (id: string) => tables.find(t => t.id === id),

    // Obtener mesas por estado
    getByStatus: (status: string) => 
      tables.filter(t => t.status === status),

    // Obtener mesas libres
    getFree: () => tables.filter(t => t.status === 'LIBRE'),

    // Obtener mesas ocupadas  
    getOccupied: () => tables.filter(t => t.status === 'OCUPADA'),

    // Obtener mesas con precuenta
    getPreCuenta: () => tables.filter(t => t.status === 'PRECUENTA EMITIDA'),

    // Abrir mesa
    openTable: (tableId: string) => {
      try {
        const session = tableService.openTable(tableId, '1') // Usar usuario actual
        const table = tables.find(t => t.id === tableId)
        if (table) {
          updateTable(tableId, {
            status: 'OCUPADA',
            currentSession: session
          })
        }
        return { success: true, session }
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Cerrar mesa
    closeTable: (tableId: string) => {
      try {
        tableService.closeTable(tableId)
        updateTable(tableId, {
          status: 'LIBRE',
          currentSession: undefined
        })
        return { success: true }
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Agregar artículo a mesa
    addItem: (tableId: string, productId: string, quantity: number = 1, notes?: string) => {
      try {
        const item = tableService.addItemToTable(tableId, productId, quantity, notes)
        // Actualizar en store
        const table = tables.find(t => t.id === tableId)
        if (table?.currentSession) {
          const updatedItems = [...table.currentSession.items, item]
          const updatedSession = {
            ...table.currentSession,
            items: updatedItems,
            updatedAt: new Date()
          }
          updateTable(tableId, { currentSession: updatedSession })
        }
        return { success: true, item }
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Actualizar cantidad
    updateQuantity: (tableId: string, itemId: string, newQuantity: number) => {
      try {
        const item = tableService.updateItemQuantity(tableId, itemId, newQuantity)
        // Actualizar en store
        const table = tables.find(t => t.id === tableId)
        if (table?.currentSession) {
          const updatedItems = table.currentSession.items.map(i =>
            i.id === itemId ? { ...i, quantity: newQuantity } : i
          )
          const updatedSession = {
            ...table.currentSession,
            items: updatedItems,
            updatedAt: new Date()
          }
          updateTable(tableId, { currentSession: updatedSession })
        }
        return { success: true, item }
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Eliminar artículo
    removeItem: (tableId: string, itemId: string) => {
      try {
        tableService.removeItemFromTable(tableId, itemId)
        // Actualizar en store
        const table = tables.find(t => t.id === tableId)
        if (table?.currentSession) {
          const updatedItems = table.currentSession.items.filter(i => i.id !== itemId)
          const updatedSession = {
            ...table.currentSession,
            items: updatedItems,
            updatedAt: new Date()
          }
          updateTable(tableId, { currentSession: updatedSession })
        }
        return { success: true }
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Enviar comanda
    sendOrder: (tableId: string) => {
      try {
        const itemIds = tableService.sendOrder(tableId)
        // Actualizar en store
        const table = tables.find(t => t.id === tableId)
        if (table?.currentSession) {
          const updatedItems = table.currentSession.items.map(i =>
            itemIds.includes(i.id) ? { ...i, sent: true } : i
          )
          const updatedSession = {
            ...table.currentSession,
            items: updatedItems,
            updatedAt: new Date()
          }
          updateTable(tableId, { currentSession: updatedSession })
        }
        return { success: true, itemIds }
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Generar precuenta
    generatePreCuenta: (tableId: string) => {
      try {
        const result = tableService.generatePreCuenta(tableId)
        // Actualizar en store
        const table = tables.find(t => t.id === tableId)
        if (table?.currentSession) {
          updateTable(tableId, {
            status: 'PRECUENTA EMITIDA',
            currentSession: {
              ...table.currentSession,
              precuentaGenerated: true,
              updatedAt: new Date()
            }
          })
        }
        return { success: true, ...result }
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    },

    // Buscar mesas
    search: (query: string) => tableService.searchTables(query),

    // Estadísticas
    getStats: () => tableService.getTableStats(),

    // Cambiar estado
    changeStatus: (tableId: string, status: Table['status']) => {
      try {
        tableService.changeTableStatus(tableId, status)
        updateTable(tableId, { status })
        return { success: true }
      } catch (error) {
        return { success: false, message: (error as Error).message }
      }
    }
  }), [tables, updateTable])

  // Acciones que requieren selectedTable
  const selectedTableData = useMemo(() => {
    if (!selectedTable) return null
    return tables.find(t => t.id === selectedTable) || null
  }, [tables, selectedTable])

  // Funciones para la mesa seleccionada
  const selectedActions = useMemo(() => ({
    // Agregar producto
    addItem: (productId: string, quantity: number = 1, notes?: string) => {
      if (!selectedTable) {
        return { success: false, message: 'No hay mesa seleccionada' }
      }
      return actions.addItem(selectedTable, productId, quantity, notes)
    },

    // Actualizar cantidad
    updateQuantity: (itemId: string, newQuantity: number) => {
      if (!selectedTable) {
        return { success: false, message: 'No hay mesa seleccionada' }
      }
      return actions.updateQuantity(selectedTable, itemId, newQuantity)
    },

    // Eliminar artículo
    removeItem: (itemId: string) => {
      if (!selectedTable) {
        return { success: false, message: 'No hay mesa seleccionada' }
      }
      return actions.removeItem(selectedTable, itemId)
    },

    // Enviar comanda
    sendOrder: () => {
      if (!selectedTable) {
        return { success: false, message: 'No hay mesa seleccionada' }
      }
      return actions.sendOrder(selectedTable)
    },

    // Generar precuenta
    generatePreCuenta: () => {
      if (!selectedTable) {
        return { success: false, message: 'No hay mesa seleccionada' }
      }
      return actions.generatePreCuenta(selectedTable)
    },

    // Cerrar mesa
    close: () => {
      if (!selectedTable) {
        return { success: false, message: 'No hay mesa seleccionada' }
      }
      return actions.closeTable(selectedTable)
    }
  }), [selectedTable, actions])

  return {
    tables,
    selectedTable,
    selectedTableData,
    setSelectedTable,
    ...actions,
    selectedActions
  }
}

export default useTables
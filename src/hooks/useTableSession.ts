import { useState, useCallback } from 'react'
import { useStore } from '../store/store'
import { TableSession, AccountItem, Product } from '../types'

export const useTableSession = () => {
  const { tables, updateTable } = useStore()
  const [currentSession, setCurrentSession] = useState<TableSession | null>(null)

  const openTableSession = useCallback((tableId: string) => {
    const table = tables.find(t => t.id === tableId)
    if (!table) return null

    if (table.status === 'LIBRE') {
      const newSession: TableSession = {
        sessionId: Math.random().toString(36).substr(2, 9),
        tableId,
        items: [],
        precuentaGenerated: false,
        totalUSD: 0,
        totalBs: 0,
        createdAt: new Date(),
        updatedAt: new Date()
      }

      updateTable(tableId, {
        status: 'OCUPADA',
        currentSession: newSession
      })
      setCurrentSession(newSession)
      return newSession
    } else {
      setCurrentSession(table.currentSession || null)
      return table.currentSession || null
    }
  }, [tables, updateTable])

  const addItem = useCallback((product: Product, quantity: number = 1, notes?: string) => {
    if (!currentSession) return

    const newItem: AccountItem = {
      id: Math.random().toString(36).substr(2, 9),
      productId: product.id,
      quantity,
      unitPrice: product.price,
      notes,
      sent: false,
      cancelled: false
    }

    const updatedItems = [...currentSession.items, newItem]
    const totalUSD = updatedItems.reduce((sum, item) => sum + (item.quantity * item.unitPrice), 0)
    
    const updatedSession: TableSession = {
      ...currentSession,
      items: updatedItems,
      totalUSD,
      totalBs: totalUSD * 20, // Usar tasa actual
      updatedAt: new Date()
    }

    updateTable(currentSession.tableId, {
      currentSession: updatedSession
    })
    setCurrentSession(updatedSession)
  }, [currentSession, updateTable])

  const updateItem = useCallback((itemId: string, updates: Partial<AccountItem>) => {
    if (!currentSession) return

    const updatedItems = currentSession.items.map(item =>
      item.id === itemId ? { ...item, ...updates } : item
    )

    const totalUSD = updatedItems.reduce((sum, item) => sum + (item.quantity * item.unitPrice), 0)
    
    const updatedSession: TableSession = {
      ...currentSession,
      items: updatedItems,
      totalUSD,
      totalBs: totalUSD * 20,
      updatedAt: new Date()
    }

    updateTable(currentSession.tableId, {
      currentSession: updatedSession
    })
    setCurrentSession(updatedSession)
  }, [currentSession, updateTable])

  const removeItem = useCallback((itemId: string) => {
    if (!currentSession) return

    const updatedItems = currentSession.items.filter(item => item.id !== itemId)
    const totalUSD = updatedItems.reduce((sum, item) => sum + (item.quantity * item.unitPrice), 0)
    
    const updatedSession: TableSession = {
      ...currentSession,
      items: updatedItems,
      totalUSD,
      totalBs: totalUSD * 20,
      updatedAt: new Date()
    }

    updateTable(currentSession.tableId, {
      currentSession: updatedSession
    })
    setCurrentSession(updatedSession)
  }, [currentSession, updateTable])

  const closeSession = useCallback(() => {
    if (!currentSession) return

    updateTable(currentSession.tableId, {
      status: 'LIBRE',
      currentSession: undefined
    })
    setCurrentSession(null)
  }, [currentSession, updateTable])

  return {
    currentSession,
    openTableSession,
    addItem,
    updateItem,
    removeItem,
    closeSession
  }
}

export default useTableSession
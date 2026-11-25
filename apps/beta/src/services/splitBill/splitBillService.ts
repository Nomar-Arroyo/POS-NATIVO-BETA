import storageService from '../storage/storageService'
import calculationService from '../calculations/calculationService'
import auditService from '../audit/auditService'
import type { AccountItem, Table } from '../../types'
import {
  SPLIT_MODES,
  type Split,
  type SplitBill,
  type SplitOptions,
  type SplitPayment
} from '../../types/splitBill'

class SplitBillService {
  createSplitBill(tableId: string, options: SplitOptions): SplitBill {
    const table = storageService.getTable(tableId)
    if (!table?.currentSession) {
      throw new Error(`Mesa ${tableId} no tiene una sesión activa`)
    }

    const { currentSession } = table
    const activeItems = currentSession.items.filter(item => !item.cancelled)
    if (activeItems.length === 0) {
      throw new Error('No hay artículos para dividir')
    }
    if (!Number.isInteger(options.splitCount) || options.splitCount < 2) {
      throw new Error('La división requiere al menos 2 partes')
    }
    if (
      activeItems.some(item =>
        !Number.isFinite(item.quantity) ||
        item.quantity <= 0 ||
        !Number.isFinite(item.unitPrice) ||
        item.unitPrice < 0
      )
    ) {
      throw new Error('La cuenta contiene artículos con cantidades o precios inválidos')
    }

    const activeBillId = currentSession.splitBillId
    if (
      activeBillId &&
      storageService.getSplitBill(activeBillId)?.status === 'ACTIVE'
    ) {
      throw new Error('La cuenta de esta mesa ya está dividida')
    }
    if (storageService.getSplitBills().some(splitBill =>
      splitBill.tableId === tableId &&
      splitBill.originalSessionId === currentSession.sessionId &&
      splitBill.status === 'ACTIVE'
    )) {
      throw new Error('La cuenta de esta mesa ya está dividida')
    }

    const exchangeRate = storageService.getConfig().exchangeRate
    this.validateExchangeRate(exchangeRate)

    const splits = this.createSplits(activeItems, options, exchangeRate)
    const totalUSD = calculationService.calculateSubtotal(activeItems)
    this.reconcileSplitTotals(splits, totalUSD)
    splits.forEach(split => {
      split.subtotalBs = calculationService.convertUSDToBs(
        split.subtotalUSD,
        exchangeRate
      )
    })

    const totalBs = calculationService.convertUSDToBs(totalUSD, exchangeRate)
    const now = new Date()
    const splitBill: SplitBill = {
      id: `split-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      tableId,
      originalSessionId: currentSession.sessionId,
      splits,
      createdAt: now,
      updatedAt: now,
      status: 'ACTIVE',
      totalUSD,
      totalBs
    }

    storageService.addSplitBill(splitBill)
    this.updateTableWithSplit(table, splitBill.id)

    void auditService.logTableAction('DIVISION', tableId, {
      splitBillId: splitBill.id,
      splitsCount: splits.length,
      totalUSD,
      totalBs
    }).catch((error: unknown) => {
      console.error('Error registrando auditoría de división de cuenta:', error)
    })

    return splitBill
  }

  private createSplits(
    items: AccountItem[],
    options: SplitOptions,
    exchangeRate: number
  ): Split[] {
    const splits: Split[] = Array.from({ length: options.splitCount }, (_, index) => {
      const id = `split-${index + 1}`
      const name = options.names?.[id]?.trim() || `Cuenta ${index + 1}`
      return {
        id,
        name,
        items: [],
        subtotalUSD: 0,
        subtotalBs: 0,
        paid: false,
        payments: []
      }
    })

    switch (options.mode) {
      case SPLIT_MODES.BY_ITEM:
        this.assignItemsByItem(splits, items, options.assignItems)
        break
      case SPLIT_MODES.BY_PERCENTAGE:
        this.assignProportionally(
          splits,
          items,
          this.getPercentageWeights(splits, options.percentages)
        )
        break
      case SPLIT_MODES.BY_AMOUNT:
        this.assignProportionally(
          splits,
          items,
          this.getAmountWeights(
            splits,
            options.amounts,
            calculationService.calculateSubtotal(items)
          )
        )
        break
      case SPLIT_MODES.EQUAL:
        this.assignProportionally(
          splits,
          items,
          splits.map(() => 1 / splits.length)
        )
        break
      default:
        throw new Error('Modo de división no válido')
    }

    for (const split of splits) {
      if (split.items.length === 0) {
        throw new Error(`${split.name} no tiene artículos asignados`)
      }
      split.subtotalUSD = calculationService.calculateSubtotal(split.items)
      split.subtotalBs = calculationService.convertUSDToBs(
        split.subtotalUSD,
        exchangeRate
      )
    }

    return splits
  }

  private assignItemsByItem(
    splits: Split[],
    items: AccountItem[],
    assignments: Record<string, string[]>
  ): void {
    const itemsById = new Map(items.map(item => [item.id, item]))
    const assignedIds = new Set<string>()
    const splitsById = new Map(splits.map(split => [split.id, split]))

    for (const [splitId, itemIds] of Object.entries(assignments || {})) {
      const split = splitsById.get(splitId)
      if (!split) {
        throw new Error(`Cuenta de división no válida: ${splitId}`)
      }
      if (!Array.isArray(itemIds)) {
        throw new Error(`La asignación de artículos para ${splitId} no es válida`)
      }

      for (const itemId of itemIds) {
        const item = itemsById.get(itemId)
        if (!item) {
          throw new Error(`Artículo no válido para dividir: ${itemId}`)
        }
        if (assignedIds.has(itemId)) {
          throw new Error(`El artículo ${itemId} fue asignado más de una vez`)
        }

        assignedIds.add(itemId)
        split.items.push({ ...item })
      }
    }

    const unassignedItem = items.find(item => !assignedIds.has(item.id))
    if (unassignedItem) {
      throw new Error(`El artículo ${unassignedItem.id} no fue asignado a una cuenta`)
    }
  }

  private assignProportionally(
    splits: Split[],
    items: AccountItem[],
    weights: number[]
  ): void {
    for (const item of items) {
      let allocatedQuantity = 0
      splits.forEach((split, index) => {
        const quantity = index === splits.length - 1
          ? Math.max(0, item.quantity - allocatedQuantity)
          : item.quantity * weights[index]
        allocatedQuantity += quantity

        if (quantity > 0) {
          split.items.push({ ...item, quantity })
        }
      })
    }
  }

  private getPercentageWeights(
    splits: Split[],
    percentages?: Record<string, number>
  ): number[] {
    if (!percentages) {
      throw new Error('Debe indicar el porcentaje de cada cuenta')
    }

    const values = splits.map(split => percentages[split.id])
    if (values.some(value => !Number.isFinite(value) || value <= 0)) {
      throw new Error('Cada porcentaje debe ser mayor a 0')
    }
    const total = values.reduce((sum, value) => sum + value, 0)
    if (Math.abs(total - 100) > 0.01) {
      throw new Error('Los porcentajes de división deben sumar 100%')
    }

    return values.map(value => value / total)
  }

  private getAmountWeights(
    splits: Split[],
    amounts: Record<string, number> | undefined,
    totalUSD: number
  ): number[] {
    if (!amounts) {
      throw new Error('Debe indicar el monto de cada cuenta')
    }

    const values = splits.map(split => amounts[split.id])
    if (values.some(value => !Number.isFinite(value) || value <= 0)) {
      throw new Error('El monto de cada cuenta debe ser mayor a 0')
    }
    const totalAmount = values.reduce((sum, value) => sum + value, 0)
    if (Math.abs(totalAmount - totalUSD) > 0.01) {
      throw new Error('Los montos de división deben coincidir con el total de la cuenta')
    }

    return values.map(value => value / totalAmount)
  }

  private reconcileSplitTotals(splits: Split[], totalUSD: number): void {
    const splitTotal = () =>
      splits.reduce((sum, split) => sum + split.subtotalUSD, 0)
    const difference = Math.round((totalUSD - splitTotal()) * 100) / 100
    if (difference === 0) return

    const adjustment = [...splits].reverse()
      .flatMap(split => [...split.items].reverse().map(item => ({ split, item })))
      .find(({ item }) =>
        item.unitPrice > 0 &&
        item.quantity + difference / item.unitPrice > 0
      )
    if (!adjustment) {
      throw new Error('No se pudo ajustar el redondeo de las cuentas')
    }

    adjustment.item.quantity += difference / adjustment.item.unitPrice
    adjustment.split.subtotalUSD = calculationService.calculateSubtotal(
      adjustment.split.items
    )
    if (Math.round(totalUSD * 100) !== Math.round(splitTotal() * 100)) {
      throw new Error('Las cuentas divididas no coinciden con el total original')
    }
  }

  private updateTableWithSplit(table: Table, splitBillId: string): void {
    if (!table.currentSession) {
      throw new Error(`Mesa ${table.id} no tiene una sesión activa`)
    }

    storageService.updateTable(table.id, {
      currentSession: {
        ...table.currentSession,
        splitBillId,
        updatedAt: new Date()
      }
    })
  }

  getSplitBill(id: string): SplitBill | undefined {
    const splitBill = storageService.getSplitBill(id)
    return splitBill ? this.hydrateSplitBill(splitBill) : undefined
  }

  addPaymentToSplit(
    splitBillId: string,
    splitId: string,
    payment: Omit<SplitPayment, 'id' | 'timestamp'>
  ): SplitBill {
    const splitBill = this.getSplitBill(splitBillId)
    if (!splitBill) {
      throw new Error(`División no encontrada: ${splitBillId}`)
    }
    if (splitBill.status !== 'ACTIVE') {
      throw new Error('La división ya no está activa')
    }

    const split = splitBill.splits.find(candidate => candidate.id === splitId)
    if (!split) {
      throw new Error(`Cuenta de división no encontrada: ${splitId}`)
    }
    if (split.paid) {
      throw new Error(`${split.name} ya está pagada`)
    }
    if (
      !payment.method.trim() ||
      !Number.isFinite(payment.amount) ||
      payment.amount <= 0
    ) {
      throw new Error('El método y el monto del pago son obligatorios')
    }

    const exchangeRate = storageService.getConfig().exchangeRate
    this.validateExchangeRate(exchangeRate)
    const paymentUSD = this.roundMoney(
      payment.currency === 'USD'
        ? payment.amount
        : calculationService.convertBsToUSD(payment.amount, exchangeRate)
    )
    if (paymentUSD <= 0) {
      throw new Error('El monto del pago es demasiado pequeño')
    }

    const paidBefore = this.roundMoney(split.payments.reduce(
      (sum, previousPayment) => sum + this.paymentInUSD(previousPayment, exchangeRate),
      0
    ))
    const paidAfter = this.roundMoney(paidBefore + paymentUSD)
    if (paidAfter > split.subtotalUSD) {
      throw new Error('El pago supera el saldo de esta cuenta')
    }

    split.payments.push({
      ...payment,
      exchangeRate,
      id: `pay-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`,
      timestamp: new Date()
    })
    if (paidAfter >= split.subtotalUSD) {
      split.paid = true
      split.paidAt = new Date()
    }

    splitBill.updatedAt = new Date()
    const allPaid = splitBill.splits.every(candidate => candidate.paid)
    if (allPaid) {
      splitBill.status = 'COMPLETED'
    }

    storageService.updateSplitBill(splitBill)
    if (allPaid) {
      const table = storageService.getTable(splitBill.tableId)
      if (
        table?.currentSession?.sessionId === splitBill.originalSessionId
      ) {
        storageService.updateTable(splitBill.tableId, {
          status: 'LIBRE',
          currentSession: undefined
        })
      }
    }

    void auditService.logPaymentAction(
      'PAGO',
      splitBillId,
      splitBill.tableId,
      {
        splitId,
        paymentMethod: payment.method,
        amount: payment.amount,
        currency: payment.currency,
        paid: split.paid,
        splitBillStatus: splitBill.status
      }
    ).catch((error: unknown) => {
      console.error('Error registrando auditoría del pago dividido:', error)
    })

    return splitBill
  }

  canReleaseTable(tableId: string): boolean {
    const table = storageService.getTable(tableId)
    if (table?.currentSession) {
      const activeBillId = table.currentSession.splitBillId
      if (!activeBillId) return false

      const activeSplitBill = this.getSplitBill(activeBillId)
      return Boolean(
        activeSplitBill &&
        activeSplitBill.status === 'COMPLETED' &&
        activeSplitBill.splits.every(split => split.paid)
      )
    }

    const splitBill = this.getSplitBillByTable(tableId)
    return Boolean(
      splitBill &&
      splitBill.status === 'COMPLETED' &&
      splitBill.splits.every(split => split.paid)
    )
  }

  getSplitBillByTable(tableId: string): SplitBill | undefined {
    const table = storageService.getTable(tableId)
    const activeSplitBillId = table?.currentSession?.splitBillId
    if (activeSplitBillId) {
      return this.getSplitBill(activeSplitBillId)
    }

    const splitBill = storageService.getSplitBills()
      .filter(candidate => candidate.tableId === tableId)
      .sort((a, b) =>
        new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
      )[0]
    return splitBill ? this.hydrateSplitBill(splitBill) : undefined
  }

  cancelSplitBill(splitBillId: string): void {
    const splitBill = this.getSplitBill(splitBillId)
    if (!splitBill) {
      throw new Error(`División no encontrada: ${splitBillId}`)
    }
    if (splitBill.status !== 'ACTIVE') {
      throw new Error('Solo se puede cancelar una división activa')
    }
    if (splitBill.splits.some(split =>
      split.paid || split.payments.length > 0
    )) {
      throw new Error('No se puede cancelar una división que ya tiene pagos')
    }

    splitBill.status = 'CANCELLED'
    splitBill.updatedAt = new Date()
    storageService.updateSplitBill(splitBill)

    const table = storageService.getTable(splitBill.tableId)
    if (table?.currentSession?.sessionId === splitBill.originalSessionId) {
      storageService.updateTable(splitBill.tableId, {
        status: table.currentSession.precuentaGenerated
          ? 'PRECUENTA EMITIDA'
          : 'OCUPADA',
        currentSession: {
          ...table.currentSession,
          splitBillId: undefined,
          updatedAt: new Date()
        }
      })
    }

    void auditService.logAction('DIVISION_CANCELADA', {
      splitBillId,
      tableId: splitBill.tableId
    }, {
      tableId: splitBill.tableId,
      category: 'TABLE',
      severity: 'WARNING'
    }).catch((error: unknown) => {
      console.error('Error registrando auditoría de cancelación de división:', error)
    })
  }

  getSplitStats(): {
    totalSplits: number
    activeSplits: number
    completedSplits: number
    averageSplitsPerBill: number
  } {
    const splitBills = storageService.getSplitBills()
    const completedSplits = splitBills.filter(
      splitBill => splitBill.status === 'COMPLETED'
    ).length
    const activeSplits = splitBills.filter(
      splitBill => splitBill.status === 'ACTIVE'
    ).length

    return {
      totalSplits: splitBills.length,
      activeSplits,
      completedSplits,
      averageSplitsPerBill: splitBills.length > 0
        ? splitBills.reduce((sum, splitBill) => sum + splitBill.splits.length, 0) /
          splitBills.length
        : 0
    }
  }

  private paymentInUSD(payment: SplitPayment, exchangeRate: number): number {
    return payment.currency === 'USD'
      ? payment.amount
      : calculationService.convertBsToUSD(
        payment.amount,
        payment.exchangeRate ?? exchangeRate
      )
  }

  private roundMoney(value: number): number {
    return Math.round(value * 100) / 100
  }

  private validateExchangeRate(exchangeRate: number): void {
    if (!Number.isFinite(exchangeRate) || exchangeRate <= 0) {
      throw new Error('La tasa de cambio debe ser mayor a 0')
    }
  }

  private hydrateSplitBill(splitBill: SplitBill): SplitBill {
    return {
      ...splitBill,
      createdAt: new Date(splitBill.createdAt),
      updatedAt: new Date(splitBill.updatedAt),
      splits: splitBill.splits.map(split => ({
        ...split,
        paidAt: split.paidAt ? new Date(split.paidAt) : undefined,
        items: split.items.map(item => ({ ...item })),
        payments: split.payments.map(payment => ({
          ...payment,
          timestamp: new Date(payment.timestamp)
        }))
      }))
    }
  }
}

export default new SplitBillService()

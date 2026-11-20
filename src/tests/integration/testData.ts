import type { Config, Table } from '../../types'
import { demoCategories } from '../../services/data/demoCategories'
import { demoProducts } from '../../services/data/demoProducts'
import storageService from '../../services/storage/storageService'

const testConfig: Config = {
  establishmentName: 'Café Amalfi Test',
  taxId: 'J-TEST-12345678-9',
  currency: 'USD',
  exchangeRate: 20,
  ivaRate: 0.16,
  igtfRate: 0.03,
  fiscalSimulation: true,
  printWidth: 58
}

const testTables: Table[] = [{
  id: 'table-1',
  name: 'Mesa de prueba',
  capacity: 4,
  status: 'LIBRE',
  position: { x: 0, y: 0 }
}]

export function setupIntegrationData(): void {
  storageService.setConfig(testConfig)
  storageService.setProducts(demoProducts.map(product => ({ ...product })))
  storageService.setCategories(demoCategories.map(category => ({ ...category })))
  storageService.setTables(testTables.map(table => ({ ...table })))
  storageService.setOrders([])
  storageService.setSplitBills([])
  storageService.setPrecuentas([])
  storageService.setFacturas([])
  storageService.setAuditLogs([])
  storageService.setCashSessions([])
  storageService.setCashMovements([])
}

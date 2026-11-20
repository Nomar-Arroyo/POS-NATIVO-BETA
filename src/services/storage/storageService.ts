import { 
  User, Config, Product, Table, Order, Precuenta, Pago, Factura, 
  AuditLog, CashSession, CashMovement, Category 
} from '../../types';
import type { SplitBill } from '../../types/splitBill';

const STORAGE_VERSION = 4;
const STORAGE_KEY = 'pos_nativo_beta_v2';

interface StorageData {
  version: number;
  users: User[];
  config: Config;
  products: Product[];
  categories: Category[];
  tables: Table[];
  orders: Order[];
  splitBills: SplitBill[];
  precuentas: Precuenta[];
  pagos: Pago[];
  facturas: Factura[];
  auditLogs: AuditLog[];
  cashSessions: CashSession[];
  cashMovements: CashMovement[];
  lastBackup?: string;
}

class StorageService {
  private data: StorageData;
  private listeners: Array<() => void> = [];

  constructor() {
    this.data = this.load();
    this.migrate();
    this.setupAutoBackup();
  }

  // Suscribirse a cambios
  subscribe(listener: () => void) {
    this.listeners.push(listener);
  }

  private notifyListeners() {
    this.listeners.forEach(listener => listener());
  }

  private toDate(value: unknown): Date {
    const date = value instanceof Date ? value : new Date(String(value ?? ''));
    return Number.isNaN(date.getTime()) ? new Date() : date;
  }

  private toFiniteNumber(value: unknown): number {
    const number = Number(value);
    return Number.isFinite(number) ? number : 0;
  }

  private normalizeCashMovement(
    movement: any,
    sessionId = '',
    userId = '1',
    userName = 'Administrador'
  ): CashMovement {
    movement = movement && typeof movement === 'object' ? movement : {};
    const types: Record<string, CashMovement['type']> = {
      INGRESO: 'INGRESO',
      EGRESO: 'EGRESO',
      APERTURA: 'APERTURA',
      CIERRE: 'CIERRE',
      AJUSTE: 'AJUSTE'
    };
    const type = types[String(movement.type || '').toUpperCase()] || 'AJUSTE';
    const categories: Record<string, CashMovement['category']> = {
      VENTA: 'VENTA',
      ANULACION: 'ANULACION',
      AJUSTE_MANUAL: 'AJUSTE_MANUAL',
      GASTO: 'GASTO',
      APERTURA_INICIAL: 'APERTURA_INICIAL',
      CIERRE_FINAL: 'CIERRE_FINAL'
    };
    const defaultCategory: CashMovement['category'] =
      type === 'APERTURA'
        ? 'APERTURA_INICIAL'
        : type === 'CIERRE'
          ? 'CIERRE_FINAL'
          : type === 'EGRESO'
            ? 'GASTO'
            : type === 'INGRESO'
              ? 'VENTA'
              : 'AJUSTE_MANUAL';
    const methods = new Set([
      'EFECTIVO USD',
      'EFECTIVO Bs',
      'PUNTO DE VENTA',
      'PAGO MÓVIL',
      'ZELLE',
      'OTRO'
    ]);

    return {
      id: String(
        movement.id ||
        `mov-migrated-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`
      ),
      type,
      category: categories[String(movement.category || '').toUpperCase()] || defaultCategory,
      amount: this.toFiniteNumber(movement.amount),
      currency: movement.currency === 'Bs' ? 'Bs' : 'USD',
      method: methods.has(movement.method) ? movement.method : undefined,
      description: String(movement.description || ''),
      reference: movement.reference,
      timestamp: this.toDate(movement.timestamp),
      userId: String(movement.userId || userId),
      userName: String(movement.userName || movement.user || userName),
      sessionId: String(movement.sessionId || sessionId),
      factId: movement.factId,
      tableId: movement.tableId
    };
  }

  private normalizeCashSession(session: any): CashSession {
    session = session && typeof session === 'object' ? session : {};
    const id = String(
      session.id ||
      `cash-migrated-${Date.now()}-${Math.random().toString(36).substr(2, 5)}`
    );
    const userId = String(session.userId || '1');
    const userName = String(session.userName || session.user || userId);
    const status = ['CLOSED', 'CERRADA'].includes(
      String(session.status || '').toUpperCase()
    ) ? 'CLOSED' : 'OPEN';

    return {
      id,
      userId,
      userName,
      openedAt: this.toDate(session.openedAt),
      closedAt: session.closedAt ? this.toDate(session.closedAt) : undefined,
      openingBalanceUSD: this.toFiniteNumber(session.openingBalanceUSD),
      openingBalanceBs: this.toFiniteNumber(session.openingBalanceBs),
      closingBalanceUSD: session.closingBalanceUSD === undefined
        ? undefined
        : this.toFiniteNumber(session.closingBalanceUSD),
      closingBalanceBs: session.closingBalanceBs === undefined
        ? undefined
        : this.toFiniteNumber(session.closingBalanceBs),
      expectedBalanceUSD: session.expectedBalanceUSD === undefined
        ? undefined
        : this.toFiniteNumber(session.expectedBalanceUSD),
      expectedBalanceBs: session.expectedBalanceBs === undefined
        ? undefined
        : this.toFiniteNumber(session.expectedBalanceBs),
      differenceUSD: session.differenceUSD === undefined
        ? undefined
        : this.toFiniteNumber(session.differenceUSD),
      differenceBs: session.differenceBs === undefined
        ? undefined
        : this.toFiniteNumber(session.differenceBs),
      status,
      movements: Array.isArray(session.movements)
        ? session.movements.map((movement: any) =>
          this.normalizeCashMovement(movement, id, userId, userName)
        )
        : [],
      reportX: session.reportX,
      reportZ: session.reportZ
    };
  }

  private load(): StorageData {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        const parsed = JSON.parse(stored);
        return this.validateAndFill(parsed);
      }
    } catch (error) {
      console.error('Error loading storage:', error);
      this.showStorageError('Error cargando datos, usando valores por defecto');
    }
    
    return this.getDefaultData();
  }

  private validateAndFill(parsed: any): StorageData {
    const defaultData = this.getDefaultData();
    const cashSessions = Array.isArray(parsed.cashSessions)
      ? parsed.cashSessions.map((session: any) => this.normalizeCashSession(session))
      : defaultData.cashSessions;
    const cashMovements = Array.isArray(parsed.cashMovements)
      ? parsed.cashMovements.map((movement: any) =>
        this.normalizeCashMovement(movement)
      )
      : defaultData.cashMovements;
    
    return {
      version: parsed.version || STORAGE_VERSION,
      users: Array.isArray(parsed.users) ? parsed.users : defaultData.users,
      config: { ...defaultData.config, ...parsed.config },
      products: Array.isArray(parsed.products) ? parsed.products : defaultData.products,
      categories: Array.isArray(parsed.categories) ? parsed.categories : defaultData.categories,
      tables: Array.isArray(parsed.tables) ? parsed.tables : defaultData.tables,
      orders: Array.isArray(parsed.orders) ? parsed.orders : defaultData.orders,
      splitBills: Array.isArray(parsed.splitBills) ? parsed.splitBills : defaultData.splitBills,
      precuentas: Array.isArray(parsed.precuentas) ? parsed.precuentas : defaultData.precuentas,
      pagos: Array.isArray(parsed.pagos) ? parsed.pagos : defaultData.pagos,
      facturas: Array.isArray(parsed.facturas) ? parsed.facturas : defaultData.facturas,
      auditLogs: Array.isArray(parsed.auditLogs) ? parsed.auditLogs : defaultData.auditLogs,
      cashSessions,
      cashMovements,
      lastBackup: parsed.lastBackup
    };
  }

  private getDefaultData(): StorageData {
    return {
      version: STORAGE_VERSION,
      users: [
        { id: '1', name: 'Administrador', role: 'admin', active: true },
        { id: '2', name: 'Juan Pérez', role: 'cashier', active: true },
        { id: '3', name: 'María González', role: 'waiter', active: true },
        { id: '4', name: 'Carlos Chef', role: 'chef', active: true }
      ],
      config: {
        establishmentName: 'CAFÉ ANALÍTICA C.A.',
        taxId: 'J-12345678-9',
        currency: 'USD',
        exchangeRate: 20.0,
        exchangeRateSource: 'BCV',
        ivaRate: 0.16,
        igtfRate: 0.03,
        fiscalSimulation: true,
        printWidth: 58
      },
      products: [],
      categories: [
        { id: 'cat-1', name: 'Bebidas', order: 1 },
        { id: 'cat-2', name: 'Paninis', order: 2 },
        { id: 'cat-3', name: 'Jugos', order: 3 },
        { id: 'cat-4', name: 'Aguas', order: 4 },
        { id: 'cat-5', name: 'Comida', order: 5 },
        { id: 'cat-6', name: 'Desayunos', order: 6 },
        { id: 'cat-7', name: 'Postres', order: 7 },
        { id: 'cat-8', name: 'Extras', order: 8 }
      ],
      tables: this.getDefaultTables(),
      orders: [],
      splitBills: [],
      precuentas: [],
      pagos: [],
      facturas: [],
      auditLogs: [],
      cashSessions: [],
      cashMovements: []
    };
  }

  private getDefaultTables(): Table[] {
    const tables: Table[] = [];
    
    // Mesas normales (1-12)
    for (let i = 1; i <= 12; i++) {
      tables.push({
        id: `table-${i}`,
        name: `Mesa ${i}`,
        capacity: i <= 4 ? 2 : i <= 8 ? 4 : 6,
        status: 'LIBRE',
        position: { x: (i % 4) * 120, y: Math.floor((i - 1) / 4) * 100 }
      });
    }
    
    // Áreas especiales
    tables.push({
      id: 'bar',
      name: 'Barra',
      capacity: 3,
      status: 'LIBRE',
      position: { x: 500, y: 0 }
    });
    
    tables.push({
      id: 'takeaway',
      name: 'Para llevar',
      capacity: 0,
      status: 'LIBRE',
      position: { x: 500, y: 100 }
    });
    
    tables.push({
      id: 'delivery',
      name: 'Delivery',
      capacity: 0,
      status: 'LIBRE',
      position: { x: 500, y: 200 }
    });

    return tables;
  }

  private migrate() {
    if (this.data.version < STORAGE_VERSION) {
      console.log(`Migrando de versión ${this.data.version} a ${STORAGE_VERSION}`);
      
      // Migraciones específicas
      if (this.data.version === 1) {
        // Ejemplo: Agregar nuevas propiedades
        this.data.categories = this.getDefaultData().categories;
      }
      
      this.data.version = STORAGE_VERSION;
      this.save();
    }
  }

  private setupAutoBackup() {
    // Backup automático cada hora
    setInterval(() => {
      this.createBackup();
    }, 60 * 60 * 1000);
  }

  private showStorageError(message: string) {
    // En una app real, mostrar notificación
    console.warn(message);
  }

  private save() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.data));
      this.notifyListeners();
    } catch (error) {
      console.error('Error saving storage:', error);
      this.showStorageError('Error guardando datos');
    }
  }

  // ===== MÉTODOS DE ACCESO A DATOS =====

  // Configuración
  getConfig(): Config { return this.data.config; }
  setConfig(config: Config) {
    this.data.config = config;
    this.save();
  }

  // Usuarios
  getUsers(): User[] { return this.data.users; }
  getUser(id: string): User | undefined { return this.data.users.find(u => u.id === id); }
  setUsers(users: User[]) {
    this.data.users = users;
    this.save();
  }
  addUser(user: User) {
    this.data.users.push(user);
    this.save();
  }
  updateUser(id: string, updates: Partial<User>) {
    const index = this.data.users.findIndex(u => u.id === id);
    if (index !== -1) {
      this.data.users[index] = { ...this.data.users[index], ...updates };
      this.save();
    }
  }

  // Categorías
  getCategories(): Category[] { return this.data.categories; }
  getCategory(id: string): Category | undefined { return this.data.categories.find(c => c.id === id); }
  setCategories(categories: Category[]) {
    this.data.categories = categories;
    this.save();
  }
  addCategory(category: Category) {
    this.data.categories.push(category);
    this.save();
  }

  // Productos
  getProducts(): Product[] { return this.data.products; }
  getProduct(id: string): Product | undefined { return this.data.products.find(p => p.id === id); }
  setProducts(products: Product[]) {
    this.data.products = products;
    this.save();
  }
  addProduct(product: Product) {
    this.data.products.push(product);
    this.save();
  }
  updateProduct(id: string, updates: Partial<Product>) {
    const index = this.data.products.findIndex(p => p.id === id);
    if (index !== -1) {
      this.data.products[index] = { ...this.data.products[index], ...updates };
      this.save();
    }
  }
  deleteProduct(id: string) {
    this.data.products = this.data.products.filter(p => p.id !== id);
    this.save();
  }

  // Mesas
  getTables(): Table[] { return this.data.tables; }
  getTable(id: string): Table | undefined { return this.data.tables.find(t => t.id === id); }
  setTables(tables: Table[]) {
    this.data.tables = tables;
    this.save();
  }
  updateTable(id: string, updates: Partial<Table>) {
    const index = this.data.tables.findIndex(t => t.id === id);
    if (index !== -1) {
      this.data.tables[index] = { ...this.data.tables[index], ...updates };
      this.save();
    }
  }

  // Divisiones de cuenta
  getSplitBills(): SplitBill[] { return this.data.splitBills; }
  setSplitBills(splitBills: SplitBill[]) {
    this.data.splitBills = splitBills;
    this.save();
  }
  getSplitBill(id: string): SplitBill | undefined {
    return this.data.splitBills.find(splitBill => splitBill.id === id);
  }
  addSplitBill(splitBill: SplitBill) {
    if (this.data.splitBills.some(existing => existing.id === splitBill.id)) {
      throw new Error(`La división ya existe: ${splitBill.id}`);
    }
    this.data.splitBills.push(splitBill);
    this.save();
  }
  updateSplitBill(splitBill: SplitBill) {
    const index = this.data.splitBills.findIndex(
      existing => existing.id === splitBill.id
    );
    if (index === -1) {
      throw new Error(`División no encontrada: ${splitBill.id}`);
    }
    this.data.splitBills[index] = splitBill;
    this.save();
  }

  // Órdenes
  getOrders(): Order[] { return this.data.orders; }
  setOrders(orders: Order[]) {
    this.data.orders = orders;
    this.save();
  }
  addOrder(order: Order) {
    this.data.orders.push(order);
    this.save();
  }
  updateOrder(id: string, updates: Partial<Order>) {
    const index = this.data.orders.findIndex(o => o.id === id);
    if (index !== -1) {
      this.data.orders[index] = { ...this.data.orders[index], ...updates };
      this.save();
    }
  }

  // Precuentas
  getPrecuentas(): Precuenta[] { return this.data.precuentas; }
  setPrecuentas(precuentas: Precuenta[]) {
    this.data.precuentas = precuentas;
    this.save();
  }
  addPrecuenta(precuenta: Precuenta) {
    this.data.precuentas.push(precuenta);
    this.save();
  }

  // Pagos
  getPagos(): Pago[] { return this.data.pagos; }
  addPago(pago: Pago) {
    this.data.pagos.push(pago);
    this.save();
  }

  // Facturas
  getFacturas(): Factura[] { return this.data.facturas; }
  setFacturas(facturas: Factura[]) {
    this.data.facturas = facturas;
    this.save();
  }
  addFactura(factura: Factura) {
    this.data.facturas.push(factura);
    this.save();
  }

  // Auditoría
  getAuditLogs(): AuditLog[] { return this.data.auditLogs; }
  setAuditLogs(logs: AuditLog[]) {
    this.data.auditLogs = logs;
    this.save();
  }
  addAuditLog(log: AuditLog) {
    this.data.auditLogs.push(log);
    this.save();
  }

  // Caja
  getCashSessions(): CashSession[] { return this.data.cashSessions; }
  setCashSessions(sessions: CashSession[]) {
    this.data.cashSessions = sessions;
    this.save();
  }
  addCashSession(session: CashSession) {
    this.data.cashSessions.push(session);
    this.save();
  }
  updateCashSession(id: string, updates: Partial<CashSession>) {
    const index = this.data.cashSessions.findIndex(s => s.id === id);
    if (index !== -1) {
      this.data.cashSessions[index] = { ...this.data.cashSessions[index], ...updates };
      this.save();
    }
  }

  getCashMovements(): CashMovement[] { return this.data.cashMovements; }
  setCashMovements(movements: CashMovement[]) {
    this.data.cashMovements = movements;
    this.save();
  }
  addCashMovement(movement: CashMovement) {
    this.data.cashMovements.push(movement);
    this.save();
  }

  // ===== OPERACIONES CRÍTICAS =====

  // Reinicio de demostración
  resetDemoData() {
    if (confirm('¿Está seguro de reiniciar los datos de demostración? Se perderán todos los datos de prueba.')) {
      this.data = this.getDefaultData();
      this.save();
      return true;
    }
    return false;
  }

  // Backup y restauración
  createBackup(): string {
    const backup = {
      ...this.data,
      backupDate: new Date().toISOString(),
      version: STORAGE_VERSION
    };
    
    const backupStr = JSON.stringify(backup, null, 2);
    
    // Guardar backup en localStorage secundario
    localStorage.setItem(`${STORAGE_KEY}_backup`, backupStr);
    this.data.lastBackup = new Date().toISOString();
    this.save();
    
    return backupStr;
  }

  restoreBackup(backupStr: string): boolean {
    try {
      const backup = JSON.parse(backupStr);
      this.data = this.validateAndFill(backup);
      this.save();
      return true;
    } catch (error) {
      console.error('Error restoring backup:', error);
      return false;
    }
  }

  getBackupList(): Array<{ date: string; size: number }> {
    const backups: Array<{ date: string; size: number }> = [];
    
    // Buscar backups en localStorage
    for (let i = 0; i < localStorage.length; i++) {
      const key = localStorage.key(i);
      if (key?.startsWith(`${STORAGE_KEY}_backup_`)) {
        const backup = localStorage.getItem(key);
        if (backup) {
          backups.push({
            date: key.replace(`${STORAGE_KEY}_backup_`, ''),
            size: new Blob([backup]).size
          });
        }
      }
    }
    
    return backups.sort((a, b) => b.date.localeCompare(a.date));
  }

  // Exportar datos
  exportData(): string {
    return JSON.stringify(this.data, null, 2);
  }

  // Importar datos
  importData(json: string): boolean {
    try {
      const parsed = JSON.parse(json);
      this.data = this.validateAndFill(parsed);
      this.save();
      return true;
    } catch (error) {
      console.error('Error importing data:', error);
      return false;
    }
  }

  // Limpieza de datos antiguos
  cleanupOldLogs(daysToKeep: number = 30) {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);
    
    this.data.auditLogs = this.data.auditLogs.filter(
      log => new Date(log.timestamp) > cutoffDate
    );
    
    this.save();
  }
}

export default new StorageService();
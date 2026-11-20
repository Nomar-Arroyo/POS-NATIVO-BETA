import { create } from 'zustand'
import { devtools } from 'zustand/middleware'
import storageService from '../services/storage/storageService'
import auditService from '../services/audit/auditService'
import cancellationService from '../services/cancellations/cancellationService'
import tableService from '../services/tables/tableService'
import orderService from '../services/orders/orderService'
import precuentaService from '../services/precuentas/precuentaService'
import { isBcvRateEffective } from '../services/exchangeRate/bcvExchangeRateService'
import { 
  User, Config, Product, Table, TableSession, Order, Factura, CashSession, 
  AuditLog, CashMovement, Precuenta, Pago, Category, Cancellation
} from '../types'


interface PosState {
  // Estado de usuario
  currentUser: User | null;
  users: User[];
  
  // Configuración
  config: Config;
  
  // Datos maestros
  products: Product[];
  categories: Category[];
  tables: Table[];
  
  // Datos operativos
  orders: Order[];
  precuentas: Precuenta[];
  pagos: Pago[];
  facturas: Factura[];
  auditLogs: AuditLog[];
  cashSessions: CashSession[];
  cashMovements: CashMovement[];
  
  // Estado de UI
  activeModule: string;
  selectedTable: string | null;
  loading: boolean;
  notifications: Array<{ 
    id: string; 
    type: 'success' | 'error' | 'warning' | 'info'; 
    message: string 
  }>;
  
  // Acciones de usuario
  setCurrentUser: (user: User | null) => void;
  setUsers: (users: User[]) => void;
  switchUser: (userId: string) => void;
  updateUser: (id: string, updates: Partial<User>) => void;
  
  // Acciones de configuración
  setConfig: (config: Config) => void;
  updateExchangeRate: (
    rate: number,
    source?: 'BCV' | 'MANUAL',
    updatedAt?: string
  ) => void;
  setBcvExchangeRate: (rate: number, rateDate: string, checkedAt: string) => void;
  applyBcvExchangeRate: () => void;
  
  // Acciones de categorías
  setCategories: (categories: Category[]) => void;
  addCategory: (category: Category) => void;
  updateCategory: (id: string, updates: Partial<Category>) => void;
  deleteCategory: (id: string) => boolean;
  
  // Acciones de productos
  setProducts: (products: Product[]) => void;
  addProduct: (product: Product) => void;
  updateProduct: (id: string, updates: Partial<Product>) => void;
  deleteProduct: (id: string) => void;
  
  // Acciones de mesas
  setTables: (tables: Table[]) => void;
  updateTable: (id: string, updates: Partial<Table>) => void;
  openTable: (tableId: string) =>
    | { success: true; session: TableSession }
    | { success: false; message: string };
  closeTable: (tableId: string) =>
    | { success: true }
    | { success: false; message: string };
  
  // Acciones de órdenes
  setOrders: (orders: Order[]) => void;
  addOrder: (order: Order) => void;
  updateOrder: (id: string, updates: Partial<Order>) => void;
  sendOrderFromTable: (
    tableId: string,
    userId: string,
    itemIds?: string[]
  ) => { success: true; orders: Order[] } | { success: false; message: string };
  updateOrderStatus: (
    orderId: string,
    status: Order['status']
  ) => { success: true; order: Order } | { success: false; message: string };
  
  // Acciones de precuentas
  setPrecuentas: (precuentas: Precuenta[]) => void;
  addPrecuenta: (precuenta: Precuenta) => void;
  generatePrecuenta: (
    tableId: string
  ) =>
    | { success: true; precuenta: Precuenta }
    | { success: false; message: string };
  
  // Acciones de pagos
  setPagos: (pagos: Pago[]) => void;
  addPago: (pago: Pago) => void;
  
  // Acciones de facturas
  setFacturas: (facturas: Factura[]) => void;
  addFactura: (factura: Factura) => void;
  
  // Acciones de auditoría
  setAuditLogs: (logs: AuditLog[]) => void;
  addAuditLog: (log: AuditLog) => void;
  cleanupAuditLogs: (daysToKeep?: number) => number;
  createCancellation: (
    type: Cancellation['type'],
    itemId: string,
    reason: string,
    customReason?: string,
    tableId?: string,
    orderId?: string
  ) => Promise<
    | { success: true; cancellation: Cancellation }
    | { success: false; message: string }
  >;
  
  // Acciones de caja
  setCashSessions: (sessions: CashSession[]) => void;
  addCashSession: (session: CashSession) => void;
  updateCashSession: (id: string, updates: Partial<CashSession>) => void;
  setCashMovements: (movements: CashMovement[]) => void;
  addCashMovement: (movement: CashMovement) => void;
  
  // Acciones de UI
  setActiveModule: (module: string) => void;
  setSelectedTable: (tableId: string | null) => void;
  setLoading: (loading: boolean) => void;
  addNotification: (notification: { 
    type: 'success' | 'error' | 'warning' | 'info'; 
    message: string 
  }) => void;
  removeNotification: (id: string) => void;
  
  // Persistencia
  saveState: () => void;
  loadState: () => void;
  
  // Operaciones críticas
  resetDemo: () => boolean;
  createBackup: () => string;
  restoreBackup: (backupStr: string) => boolean;
}

export const useStore = create<PosState>()(
  devtools((set, get) => ({
    // Estado inicial
    currentUser: storageService.getUser('1') || null,
    users: storageService.getUsers(),
    config: storageService.getConfig(),
    products: storageService.getProducts(),
    categories: storageService.getCategories(),
    tables: storageService.getTables(),
    orders: storageService.getOrders(),
    precuentas: storageService.getPrecuentas(),
    pagos: storageService.getPagos(),
    facturas: storageService.getFacturas(),
    auditLogs: storageService.getAuditLogs(),
    cashSessions: storageService.getCashSessions(),
    cashMovements: storageService.getCashMovements(),
    
    activeModule: 'dashboard',
    selectedTable: null,
    loading: false,
    notifications: [],

    // Acciones de usuario
    setCurrentUser: (user) => {
      set({ currentUser: user }, false, 'setCurrentUser')
      auditService.setCurrentUser(user?.id ?? null)
    },
    setUsers: (users) => {
      set({ users }, false, 'setUsers')
      storageService.setUsers(users)
    },
    switchUser: (userId) => {
      const user = get().users.find(candidate => candidate.id === userId)
      if (!user) {
        get().addNotification({
          type: 'error',
          message: 'No se encontró el usuario seleccionado'
        })
        return
      }

      set({ currentUser: user }, false, 'switchUser')
      auditService.setCurrentUser(user.id)
      get().addNotification({
        type: 'info',
        message: `Usuario cambiado a: ${user.name}`
      })
    },
    updateUser: (id, updates) => {
      const { users, currentUser } = get()
      if (!users.some(user => user.id === id)) {
        get().addNotification({
          type: 'error',
          message: 'No se encontró el usuario que se intentó actualizar'
        })
        return
      }

      const newUsers = users.map(user =>
        user.id === id ? { ...user, ...updates } : user
      )
      storageService.updateUser(id, updates)
      set({
        users: newUsers,
        ...(currentUser?.id === id
          ? { currentUser: { ...currentUser, ...updates } }
          : {})
      }, false, 'updateUser')
    },
    
    // Acciones de configuración
    setConfig: (config) => {
      set({ config }, false, 'setConfig');
      storageService.setConfig(config);
    },
    
    updateExchangeRate: (
      rate,
      source = 'MANUAL',
      updatedAt = new Date().toISOString()
    ) => {
      if (!Number.isFinite(rate) || rate <= 0) {
        throw new RangeError('La tasa de cambio debe ser mayor a 0')
      }

      const { config, tables } = get();
      const newConfig = {
        ...config,
        exchangeRate: rate,
        exchangeRateSource: source,
        exchangeRateUpdatedAt: updatedAt
      };
      set({
        config: newConfig,
        tables: tables.map(table => {
          if (!table.currentSession) return table

          const totalUSD = table.currentSession.items.reduce(
            (sum, item) => sum + item.quantity * item.unitPrice,
            0
          )
          return {
            ...table,
            currentSession: {
              ...table.currentSession,
              totalUSD,
              totalBs: Math.round(totalUSD * rate * 100) / 100
            }
          }
        })
      }, false, 'updateExchangeRate');
      storageService.setConfig(newConfig);
      storageService.setTables(get().tables);
    },

    setBcvExchangeRate: (rate, rateDate, checkedAt) => {
      if (!Number.isFinite(rate) || rate <= 0) {
        throw new RangeError('La tasa BCV recibida no es válida')
      }

      const { config } = get()
      const updatedConfig = {
        ...config,
        bcvRate: rate,
        bcvRateDate: rateDate,
        bcvLastCheckedAt: checkedAt
      }

      if (
        config.exchangeRateSource !== 'MANUAL' &&
        isBcvRateEffective(rateDate)
      ) {
        get().updateExchangeRate(rate, 'BCV', checkedAt)
        const latestConfig = get().config
        const configWithBcvData = {
          ...latestConfig,
          bcvRate: rate,
          bcvRateDate: rateDate,
          bcvLastCheckedAt: checkedAt
        }
        set({ config: configWithBcvData }, false, 'setBcvExchangeRate')
        storageService.setConfig(configWithBcvData)
        return
      }

      set({ config: updatedConfig }, false, 'setBcvExchangeRate')
      storageService.setConfig(updatedConfig)
    },

    applyBcvExchangeRate: () => {
      const { config } = get()
      if (!Number.isFinite(config.bcvRate) || !config.bcvRate || config.bcvRate <= 0) {
        throw new Error('Todavía no hay una tasa BCV disponible')
      }
      if (!config.bcvRateDate || !isBcvRateEffective(config.bcvRateDate)) {
        throw new Error(
          `La tasa BCV todavía no está vigente. Se aplicará desde ${config.bcvRateDate ?? 'la fecha indicada por el BCV'}`
        )
      }

      get().updateExchangeRate(
        config.bcvRate,
        'BCV',
        config.bcvLastCheckedAt ?? new Date().toISOString()
      )
    },

    // Acciones de categorías
    setCategories: (categories) => {
      set({ categories }, false, 'setCategories');
      storageService.setCategories(categories);
    },
    
    addCategory: (category) => {
      const { categories } = get();
      const newCategories = [...categories, category];
      set({ categories: newCategories }, false, 'addCategory');
      storageService.setCategories(newCategories);
    },

    updateCategory: (id, updates) => {
      const { categories } = get();
      const newCategories = categories.map(category =>
        category.id === id ? { ...category, ...updates } : category
      );
      set({ categories: newCategories }, false, 'updateCategory');
      storageService.setCategories(newCategories);
    },

    deleteCategory: (id) => {
      const { categories, products } = get();
      const category = categories.find(item => item.id === id);

      if (!category) return false;

      const productsInCategory = products.filter(
        product => product.category === category.name
      );
      if (productsInCategory.length > 0) {
        throw new Error(
          `No se puede eliminar la categoría "${category.name}" porque tiene ${productsInCategory.length} producto(s) asociado(s)`
        );
      }

      const newCategories = categories.filter(item => item.id !== id);
      set({ categories: newCategories }, false, 'deleteCategory');
      storageService.setCategories(newCategories);
      return true;
    },

    // Acciones de productos
    setProducts: (products) => {
      set({ products }, false, 'setProducts');
      storageService.setProducts(products);
    },
    
    addProduct: (product) => {
      const { products } = get();
      const newProducts = [...products, product];
      set({ products: newProducts }, false, 'addProduct');
      storageService.setProducts(newProducts);
      void auditService.logProductAction('CREAR', product.id, {
        productName: product.name,
        price: product.price
      }).then(() => {
        set({ auditLogs: storageService.getAuditLogs() }, false, 'refreshAuditLogs')
      }).catch((error: unknown) => {
        console.error('Error registrando auditoría de creación de producto:', error)
        get().addNotification({
          type: 'error',
          message: 'No se pudo registrar la auditoría del producto'
        })
      })
    },
    
    updateProduct: (id, updates) => {
      const { products } = get();
      const newProducts = products.map(p => p.id === id ? { ...p, ...updates } : p);
      set({ products: newProducts }, false, 'updateProduct');
      storageService.setProducts(newProducts);
      void auditService.logProductAction('ACTUALIZAR', id, updates).then(() => {
        set({ auditLogs: storageService.getAuditLogs() }, false, 'refreshAuditLogs')
      }).catch((error: unknown) => {
        console.error('Error registrando auditoría de actualización de producto:', error)
        get().addNotification({
          type: 'error',
          message: 'No se pudo registrar la auditoría del producto'
        })
      })
    },
    
    deleteProduct: (id) => {
      const { products } = get();
      const product = products.find(p => p.id === id);
      const newProducts = products.filter(p => p.id !== id);
      set({ products: newProducts }, false, 'deleteProduct');
      storageService.setProducts(newProducts);
      if (product) {
        void auditService.logProductAction('ELIMINAR', id, {
          productName: product.name
        }).then(() => {
          set({ auditLogs: storageService.getAuditLogs() }, false, 'refreshAuditLogs')
        }).catch((error: unknown) => {
          console.error('Error registrando auditoría de eliminación de producto:', error)
          get().addNotification({
            type: 'error',
            message: 'No se pudo registrar la auditoría del producto'
          })
        })
      }
    },

    // Acciones de mesas
    setTables: (tables) => {
      set({ tables }, false, 'setTables');
      storageService.setTables(tables);
    },
    
    updateTable: (id, updates) => {
      const { tables } = get();
      const newTables = tables.map(t => t.id === id ? { ...t, ...updates } : t);
      set({ tables: newTables }, false, 'updateTable');
      storageService.setTables(newTables);
    },

    openTable: (tableId) => {
      const { tables, currentUser } = get();
      const table = tables.find(t => t.id === tableId);

      if (!table) {
        return { success: false, message: 'Mesa no encontrada' };
      }
      if (table.status !== 'LIBRE') {
        return { success: false, message: 'La mesa no está libre' };
      }

      const session = tableService.openTable(tableId, currentUser?.id ?? '1');
      set({ tables: storageService.getTables() }, false, 'openTable');
      return { success: true, session };
    },

    closeTable: (tableId) => {
      if (!get().tables.some(table => table.id === tableId)) {
        return { success: false, message: 'Mesa no encontrada' };
      }

      tableService.closeTable(tableId);
      set({ tables: storageService.getTables() }, false, 'closeTable');
      return { success: true };
    },

    // Acciones de órdenes
    setOrders: (orders) => {
      set({ orders }, false, 'setOrders');
      storageService.setOrders(orders);
    },
    
    addOrder: (order) => {
      const { orders } = get();
      const newOrders = [...orders, order];
      set({ orders: newOrders }, false, 'addOrder');
      storageService.setOrders(newOrders);
    },
    
    updateOrder: (id, updates) => {
      const { orders } = get();
      const newOrders = orders.map(o => o.id === id ? { ...o, ...updates } : o);
      set({ orders: newOrders }, false, 'updateOrder');
      storageService.setOrders(newOrders);
    },

    sendOrderFromTable: (tableId, userId, itemIds) => {
      try {
        const newOrders = orderService.sendOrderFromTable(tableId, userId, itemIds);
        set({ orders: orderService.getOrders() }, false, 'sendOrderFromTable');
        return { success: true, orders: newOrders };
      } catch (error) {
        return {
          success: false,
          message: error instanceof Error ? error.message : 'No se pudo enviar la orden'
        };
      }
    },

    updateOrderStatus: (orderId, status) => {
      try {
        const order = orderService.updateOrderStatus(orderId, status);
        set({ orders: orderService.getOrders() }, false, 'updateOrderStatus');
        return { success: true, order };
      } catch (error) {
        return {
          success: false,
          message: error instanceof Error ? error.message : 'No se pudo actualizar la orden'
        };
      }
    },

    // Acciones de precuentas
    setPrecuentas: (precuentas) => {
      set({ precuentas }, false, 'setPrecuentas');
      storageService.setPrecuentas(precuentas);
    },
    
    addPrecuenta: (precuenta) => {
      const { precuentas } = get();
      const newPrecuentas = [...precuentas, precuenta];
      set({ precuentas: newPrecuentas }, false, 'addPrecuenta');
      storageService.setPrecuentas(newPrecuentas);
    },

    generatePrecuenta: (tableId) => {
      try {
        const precuenta = precuentaService.generatePrecuenta(tableId);
        set({
          precuentas: storageService.getPrecuentas(),
          tables: storageService.getTables()
        }, false, 'generatePrecuenta');
        return { success: true, precuenta };
      } catch (error) {
        return {
          success: false,
          message: error instanceof Error
            ? error.message
            : 'No se pudo generar la precuenta'
        };
      }
    },

    // Acciones de pagos
    setPagos: (pagos) => {
      set({ pagos }, false, 'setPagos');
    },
    
    addPago: (pago) => {
      const { pagos } = get();
      const newPagos = [...pagos, pago];
      set({ pagos: newPagos }, false, 'addPago');
    },

    // Acciones de facturas
    setFacturas: (facturas) => {
      set({ facturas }, false, 'setFacturas');
      storageService.setFacturas(facturas);
    },
    
    addFactura: (factura) => {
      const { facturas } = get();
      const newFacturas = [...facturas, factura];
      set({ facturas: newFacturas }, false, 'addFactura');
      storageService.setFacturas(newFacturas);
    },

    // Acciones de auditoría
    setAuditLogs: (logs) => {
      set({ auditLogs: logs }, false, 'setAuditLogs');
    },
    
    addAuditLog: (log) => {
      const { auditLogs } = get();
      const newLogs = [...auditLogs, log];
      set({ auditLogs: newLogs }, false, 'addAuditLog');
      storageService.addAuditLog(log);
    },

    cleanupAuditLogs: (daysToKeep = 90) => {
      const removed = auditService.cleanupOldLogs(daysToKeep);
      set(
        { auditLogs: auditService.getAuditLogs() },
        false,
        'cleanupAuditLogs'
      );
      return removed;
    },

    createCancellation: async (
      type,
      itemId,
      reason,
      customReason,
      tableId,
      orderId
    ) => {
      try {
        const cancellation = await cancellationService.createCancellationRequest(
          type,
          itemId,
          reason,
          customReason,
          tableId,
          orderId
        );
        set(
          { auditLogs: auditService.getAuditLogs() },
          false,
          'createCancellation'
        );
        return { success: true, cancellation };
      } catch (error) {
        return {
          success: false,
          message: error instanceof Error
            ? error.message
            : 'No se pudo crear la solicitud de anulación'
        };
      }
    },

    // Acciones de caja
    setCashSessions: (sessions) => {
      set({ cashSessions: sessions }, false, 'setCashSessions');
      storageService.setCashSessions(sessions);
    },
    
    addCashSession: (session) => {
      const { cashSessions } = get();
      const newSessions = [...cashSessions, session];
      set({ cashSessions: newSessions }, false, 'addCashSession');
      storageService.addCashSession(session);
    },
    
    updateCashSession: (id, updates) => {
      const { cashSessions } = get();
      const newSessions = cashSessions.map(s => 
        s.id === id ? { ...s, ...updates } : s
      );
      set({ cashSessions: newSessions }, false, 'updateCashSession');
      storageService.updateCashSession(id, updates);
    },
    
    setCashMovements: (movements) => {
      set({ cashMovements: movements }, false, 'setCashMovements');
      storageService.setCashMovements(movements);
    },
    
    addCashMovement: (movement) => {
      const { cashMovements } = get();
      const newMovements = [...cashMovements, movement];
      set({ cashMovements: newMovements }, false, 'addCashMovement');
      storageService.addCashMovement(movement);
    },

    // Acciones de UI
    setActiveModule: (module) => set({ activeModule: module }, false, 'setActiveModule'),
    setSelectedTable: (tableId) => set({ selectedTable: tableId }, false, 'setSelectedTable'),
    setLoading: (loading) => set({ loading }, false, 'setLoading'),
    
    addNotification: (notification) => {
      const { notifications } = get();
      const id = Math.random().toString(36).substr(2, 9);
      const newNotification = { ...notification, id };
      set({ notifications: [...notifications, newNotification] }, false, 'addNotification');
      
      // Auto-remove after 5 seconds
      setTimeout(() => {
        get().removeNotification(id);
      }, 5000);
    },
    
    removeNotification: (id) => {
      const { notifications } = get();
      set({ 
        notifications: notifications.filter(n => n.id !== id) 
      }, false, 'removeNotification');
    },

    // Persistencia
    saveState: () => {
      const state = get();
      storageService.setUsers(state.users);
      storageService.setConfig(state.config);
      storageService.setProducts(state.products);
      storageService.setCategories(state.categories);
      storageService.setTables(state.tables);
      storageService.setOrders(state.orders);
      storageService.setFacturas(state.facturas);
      storageService.setPrecuentas(state.precuentas);
    },

    loadState: () => {
      const users = storageService.getUsers();
      const config = storageService.getConfig();
      const products = storageService.getProducts();
      const categories = storageService.getCategories();
      const tables = storageService.getTables();
      const orders = storageService.getOrders();
      const precuentas = storageService.getPrecuentas();
      const facturas = storageService.getFacturas();
      
      set({ 
        users, config, products, categories, tables, orders, precuentas, facturas
      }, false, 'loadState');
    },

    // Operaciones críticas
    resetDemo: () => {
      return storageService.resetDemoData();
    },
    
    createBackup: () => {
      return storageService.createBackup();
    },
    
    restoreBackup: (backupStr: string) => {
      return storageService.restoreBackup(backupStr);
    }
  }))
);

export default useStore;
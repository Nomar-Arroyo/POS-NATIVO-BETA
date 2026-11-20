import storageService from '../storage/storageService'
import {
  AUDIT_CATEGORIES,
  AUDIT_SEVERITY,
  AuditLog,
  Cancellation,
  User
} from '../../types'

class AuditService {
  private currentUserId: string | null = null;

  setCurrentUser(userId: string | null) {
    this.currentUserId = userId;
  }

  // ===== MÉTODOS PRINCIPALES DE REGISTRO =====

  async logAction(
    action: string,
    details: any,
    options: {
      tableId?: string;
      orderId?: string;
      productId?: string;
      factId?: string;
      category?: keyof typeof AUDIT_CATEGORIES;
      severity?: keyof typeof AUDIT_SEVERITY;
    } = {}
  ): Promise<AuditLog> {
    const user = this.getUser();
    
    const log: AuditLog = {
      id: `audit-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: new Date(),
      user: user?.name || 'Sistema',
      action,
      details,
      tableId: options.tableId,
      orderId: options.orderId,
      productId: options.productId,
      factId: options.factId,
      category: options.category || 'SYSTEM',
      severity: options.severity || 'INFO'
    };

    storageService.addAuditLog(log);
    return log;
  }

  // ===== REGISTROS ESPECÍFICOS POR MÓDULO =====

  // PRODUCTOS
  async logProductAction(
    action: 'CREAR' | 'ACTUALIZAR' | 'ELIMINAR' | 'AJUSTAR_STOCK',
    productId: string,
    details: any,
    severity: keyof typeof AUDIT_SEVERITY = 'INFO'
  ) {
    return this.logAction(`PRODUCT_${action}`, details, {
      productId,
      category: 'PRODUCT',
      severity
    });
  }

  // MESAS
  async logTableAction(
    action: 'ABRIR' | 'CERRAR' | 'PRECUENTA' | 'PAGO' | 'DIVISION' | 'CAMBIO_ESTADO' | 'AGREGAR' | 'ACTUALIZAR' | 'ELIMINAR' | 'ESTADO' | 'ANULACION',
    tableId: string,
    details: any,
    severity: keyof typeof AUDIT_SEVERITY = 'INFO'
  ) {
    return this.logAction(`TABLE_${action}`, details, {
      tableId,
      category: 'TABLE',
      severity
    });
  }

  // ÓRDENES
  async logOrderAction(
    action: 'ENVIAR' | 'ENTREGAR' | 'CANCELAR' | 'ESTADO' | 'ACTUALIZAR_ESTADO',
    orderId: string,
    tableId: string,
    details: any,
    severity: keyof typeof AUDIT_SEVERITY = 'INFO'
  ) {
    return this.logAction(`ORDER_${action}`, details, {
      orderId,
      tableId,
      category: 'ORDER',
      severity
    });
  }

  // PAGOS
  async logPaymentAction(
    action: 'PAGO' | 'DIVISION' | 'REEMBOLSO' | 'ANULACION',
    factId: string,
    tableId: string,
    details: any,
    severity: keyof typeof AUDIT_SEVERITY = 'INFO'
  ) {
    return this.logAction(`PAYMENT_${action}`, details, {
      tableId,
      factId,
      category: 'PAYMENT',
      severity
    });
  }

  // CAJA
  async logCashAction(
    action: 'APERTURA' | 'CIERRE' | 'AJUSTE' | 'MOVIMIENTO',
    details: any,
    severity: keyof typeof AUDIT_SEVERITY = 'INFO'
  ) {
    return this.logAction(`CASH_${action}`, details, {
      category: 'CASH',
      severity
    });
  }

  // SISTEMA
  async logSystemAction(
    action: 'INICIO SESIÓN' | 'CAMBIO_USUARIO' | 'REINICIO' | 'BACKUP' | 'RESTAURAR',
    details: any,
    severity: keyof typeof AUDIT_SEVERITY = 'INFO'
  ) {
    return this.logAction(`SYSTEM_${action}`, details, {
      category: 'SYSTEM',
      severity
    });
  }

  // ANULACIONES
  async logCancellation(
    cancellation: Cancellation,
    severity: keyof typeof AUDIT_SEVERITY = 'WARNING'
  ) {
    return this.logAction('ANULACION', cancellation, {
      tableId: cancellation.tableId,
      orderId: cancellation.orderId,
      category: 'ORDER',
      severity
    });
  }

  // ===== CONSULTAS DE AUDITORÍA =====

  getAuditLogs(): AuditLog[] {
    return storageService.getAuditLogs();
  }

  getAuditLogsByTable(tableId: string): AuditLog[] {
    return this.getAuditLogs().filter(log => log.tableId === tableId);
  }

  getAuditLogsByOrder(orderId: string): AuditLog[] {
    return this.getAuditLogs().filter(log => log.orderId === orderId);
  }

  getAuditLogsByProduct(productId: string): AuditLog[] {
    return this.getAuditLogs().filter(log => log.productId === productId);
  }

  getAuditLogsByCategory(category: keyof typeof AUDIT_CATEGORIES): AuditLog[] {
    return this.getAuditLogs().filter(log => log.category === category);
  }

  getAuditLogsBySeverity(severity: keyof typeof AUDIT_SEVERITY): AuditLog[] {
    return this.getAuditLogs().filter(log => log.severity === severity);
  }

  getAuditLogsByDateRange(startDate: Date, endDate: Date): AuditLog[] {
    return this.getAuditLogs().filter(log => {
      const logDate = new Date(log.timestamp);
      return logDate >= startDate && logDate <= endDate;
    });
  }

  getAuditLogsByUser(user: string): AuditLog[] {
    return this.getAuditLogs().filter(log => log.user === user);
  }

  // ===== ESTADÍSTICAS DE AUDITORÍA =====

  getAuditStats(days: number = 7): {
    totalLogs: number;
    byCategory: Record<string, number>;
    bySeverity: Record<string, number>;
    byUser: Record<string, number>;
    recentActivity: AuditLog[];
    topActions: Array<{ action: string; count: number }>;
  } {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);
    
    const recentLogs = this.getAuditLogs().filter(log => 
      new Date(log.timestamp) >= cutoffDate
    );

    const byCategory: Record<string, number> = {};
    const bySeverity: Record<string, number> = {};
    const byUser: Record<string, number> = {};
    const actionCounts: Record<string, number> = {};

    recentLogs.forEach(log => {
      byCategory[log.category] = (byCategory[log.category] || 0) + 1;
      bySeverity[log.severity] = (bySeverity[log.severity] || 0) + 1;
      byUser[log.user] = (byUser[log.user] || 0) + 1;
      actionCounts[log.action] = (actionCounts[log.action] || 0) + 1;
    });

    const topActions = Object.entries(actionCounts)
      .map(([action, count]) => ({ action, count }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 10);

    return {
      totalLogs: recentLogs.length,
      byCategory,
      bySeverity,
      byUser,
      recentActivity: recentLogs.slice(0, 20),
      topActions
    };
  }

  // ===== LIMPIEZA Y MANTENIMIENTO =====

  cleanupOldLogs(daysToKeep: number = 90): number {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);
    
    const allLogs = this.getAuditLogs();
    const logsToKeep = allLogs.filter(log => 
      new Date(log.timestamp) > cutoffDate
    );
    
    const removedCount = allLogs.length - logsToKeep.length;
    
    // Guardar logs filtrados
    storageService.setAuditLogs(logsToKeep);
    
    return removedCount;
  }

  // ===== UTILIDADES =====

  getUser(): User | null {
    if (this.currentUserId) {
      return storageService.getUser(this.currentUserId) || null;
    }
    // Usuarío por defecto si no hay uno establecido
    return storageService.getUser('1') || null;
  }

  // Exportar logs para respaldo
  exportLogs(): string {
    return JSON.stringify(this.getAuditLogs(), null, 2);
  }

  // Importar logs de respaldo
  importLogs(logsJson: string): boolean {
    try {
      const logs = JSON.parse(logsJson);
      const allLogs = this.getAuditLogs();
      const newLogs = [...allLogs, ...logs];
      storageService.setAuditLogs(newLogs);
      return true;
    } catch (error) {
      console.error('Error importing logs:', error);
      return false;
    }
  }
}

export default new AuditService();
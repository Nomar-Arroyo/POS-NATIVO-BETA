import storageService from '../storage/storageService';

class VerificationService {
  verifyDataIntegrity(): { 
    isValid: boolean; 
    errors: string[]; 
    warnings: string[] 
  } {
    const errors: string[] = [];
    const warnings: string[] = [];

    // Verificar mesas
    const tables = storageService.getTables();
    const tableIds = new Set<string>();
    
    tables.forEach(table => {
      if (tableIds.has(table.id)) {
        errors.push(`Mesa duplicada: ${table.id}`);
      }
      tableIds.add(table.id);

      // Verificar estado consistente
      if (table.status === 'OCUPADA' && !table.currentSession) {
        errors.push(`Mesa ${table.id} marcada como OCUPADA sin sessión`);
      }
      
      if (table.status === 'LIBRE' && table.currentSession) {
        warnings.push(`Mesa ${table.id} marcada como LIBRE con sessión activa`);
      }
    });

    // Verificar órdenes
    const orders = storageService.getOrders();
    const orderIds = new Set<string>();

    orders.forEach(order => {
      if (orderIds.has(order.id)) {
        errors.push(`Orden duplicada: ${order.id}`);
      }
      orderIds.add(order.id);

      // Verificar que la mesa exista
      if (order.tableId !== 'direct-sale' && !tableIds.has(order.tableId)) {
        errors.push(`Orden ${order.id} refers a mesa inexistente: ${order.tableId}`);
      }

    });

    // Verificar facturas
    const facturas = storageService.getFacturas();
    const factIds = new Set<string>();
    const exchangeRate = storageService.getConfig().exchangeRate

    facturas.forEach(factura => {
      if (factIds.has(factura.id)) {
        errors.push(`Factura duplicada: ${factura.id}`);
      }
      factIds.add(factura.id);

      // Verificar que los pagos sumen el total
      const totalPagadoUSD = factura.payments.reduce(
        (sum, payment) => sum + (
          payment.currency === 'Bs'
            ? payment.amount / exchangeRate
            : payment.amount
        ),
        0
      )
      if (Math.abs(totalPagadoUSD - factura.total) > 0.01) {
        errors.push(`Factura ${factura.number}: pagos no coinciden con total`)
      }
    });

    // Verificar pagos huérfanos
    const pagos = storageService.getPagos();
    const facturasWithPagos = new Set<string>();
    
    facturas.forEach(f => {
      f.payments.forEach(p => facturasWithPagos.add(p.id));
    });

    pagos.forEach(pago => {
      if (!facturasWithPagos.has(pago.id)) {
        warnings.push(`Pago ${pago.id} no asociado a ninguna factura`);
      }
    });

    return {
      isValid: errors.length === 0,
      errors,
      warnings
    };
  }

  // Reparación automática de problemas comunes
  autoRepair(): { repaired: string[]; remaining: string[] } {
    const repaired: string[] = [];
    const remaining: string[] = [];
    
    const verification = this.verifyDataIntegrity();
    
    // Reparar mesas con estado inconsistente
    const tables = storageService.getTables();
    tables.forEach(table => {
      if (table.status === 'OCUPADA' && !table.currentSession) {
        storageService.updateTable(table.id, { 
          status: 'LIBRE',
          currentSession: undefined 
        });
        repaired.push(`Mesa ${table.id} reparada: estado OCUPADA sin sessión`);
      }
      
      if (table.status === 'LIBRE' && table.currentSession) {
        storageService.updateTable(table.id, { 
          status: 'OCUPADA' 
        });
        repaired.push(`Mesa ${table.id} reparada: estado LIBRE con sessión`);
      }
    });

    remaining.push(...verification.errors);
    remaining.push(...verification.warnings);

    return { repaired, remaining };
  }
}

export default new VerificationService();
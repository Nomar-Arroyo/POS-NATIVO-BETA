import { AccountItem, Factura, Pago, Product } from '../../types';

class CalculationService {
  // Redondeo monetario consistente (2 decimales)
  roundMoney(value: number): number {
    return Math.round(value * 100) / 100;
  }

  private validateExchangeRate(exchangeRate: number): void {
    if (!Number.isFinite(exchangeRate) || exchangeRate <= 0) {
      throw new RangeError('La tasa de cambio debe ser mayor que cero');
    }
  }

  // Cálculos básicos
  calculateSubtotal(items: AccountItem[]): number {
    return this.roundMoney(
      items.reduce((sum, item) => sum + (item.quantity * item.unitPrice), 0)
    );
  }

  calculateTotal(items: AccountItem[]): number {
    return this.calculateSubtotal(items);
  }

  calculateIVA(subtotal: number, rate: number): number {
    return this.roundMoney(subtotal * rate);
  }

  calculateIGTF(subtotal: number, rate: number): number {
    return this.roundMoney(subtotal * rate);
  }

  calculateTotalFactura(
    subtotal: number, 
    ivaRate: number, 
    igtfRate: number = 0
  ): { subtotal: number; iva: number; igtf: number; total: number } {
    const iva = this.calculateIVA(subtotal, ivaRate);
    const igtf = igtfRate > 0 ? this.calculateIGTF(subtotal, igtfRate) : 0;
    const total = this.roundMoney(subtotal + iva + igtf);

    return { subtotal, iva, igtf, total };
  }

  // Conversión monetaria
  convertUSDToBs(amountUSD: number, exchangeRate: number): number {
    this.validateExchangeRate(exchangeRate);
    return this.roundMoney(amountUSD * exchangeRate);
  }

  convertBsToUSD(amountBs: number, exchangeRate: number): number {
    this.validateExchangeRate(exchangeRate);
    return this.roundMoney(amountBs / exchangeRate);
  }

  // Pagos mixtos
  calculateTotalPaid(pagos: Pago[], currency: 'USD' | 'Bs'): number {
    return this.roundMoney(
      pagos
        .filter(p => p.currency === currency)
        .reduce((sum, p) => sum + p.amount, 0)
    );
  }

  calculateRemaining(totalUSD: number, pagos: Pago[], exchangeRate: number): { 
    remainingUSD: number; 
    remainingBs: number 
  } {
    const paidUSD = this.calculateTotalPaid(pagos, 'USD');
    const paidBs = this.calculateTotalPaid(pagos, 'Bs');
    const paidInUSD = this.roundMoney(
      paidUSD + this.convertBsToUSD(paidBs, exchangeRate)
    )
    const remainingUSD = this.roundMoney(
      Math.max(0, totalUSD - paidInUSD)
    )

    return {
      remainingUSD,
      remainingBs: this.convertUSDToBs(remainingUSD, exchangeRate)
    };
  }

  calculateChange(total: number, paid: number): number {
    return this.roundMoney(Math.max(0, paid - total));
  }

  // Validaciones de pago
  validatePaymentComplete(
    totalUSD: number, 
    pagos: Pago[], 
    exchangeRate: number
  ): { 
    isValid: boolean; 
    remainingUSD: number; 
    remainingBs: number;
    totalPaidUSD: number;
    totalPaidBs: number;
  } {
    const totalPaidUSD = this.calculateTotalPaid(pagos, 'USD');
    const totalPaidBs = this.calculateTotalPaid(pagos, 'Bs');
    
    // Convertir todo a USD para comparación
    const totalPaidInUSD = this.roundMoney(
      totalPaidUSD + this.convertBsToUSD(totalPaidBs, exchangeRate)
    );
    
    const isValid = Math.abs(totalPaidInUSD - totalUSD) < 0.01;
    const remainingUSD = isValid
      ? 0
      : this.roundMoney(Math.max(0, totalUSD - totalPaidInUSD));

    return {
      isValid,
      remainingUSD,
      remainingBs: this.convertUSDToBs(remainingUSD, exchangeRate),
      totalPaidUSD,
      totalPaidBs
    };
  }

  // Formateo
  formatCurrency(amount: number, currency: 'USD' | 'Bs'): string {
    return new Intl.NumberFormat('es-VE', {
      style: 'currency',
      currency: currency === 'USD' ? 'USD' : 'VES',
      minimumFractionDigits: 2,
      maximumFractionDigits: 2
    }).format(amount);
  }

  formatNumber(number: number, decimals: number = 2): string {
    return number.toFixed(decimals);
  }

  // Generar números de documento
  generateFacturaNumber(): string {
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
    return `FAC-${timestamp}-${random}`;
  }

  generateControlNumber(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let result = '';
    for (let i = 0; i < 16; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }

  // Cálculos de inventario
  calculateStockValue(products: Product[]): number {
    return this.roundMoney(
      products.reduce((sum, product) => {
        const stock = product.stock || 0;
        return sum + (stock * product.price);
      }, 0)
    );
  }

  // Estadísticas
  calculateSalesStats(facturas: Factura[]): {
    totalSales: number;
    totalInBs: number;
    averageTicket: number;
    totalInvoices: number;
  } {
    const totalSales = this.roundMoney(
      facturas.reduce((sum, f) => sum + f.total, 0)
    );
    
    const totalInBs = this.roundMoney(
      facturas.reduce((sum, f) => sum + (f.total * 20), 0) // Usar tasa actual
    );
    
    return {
      totalSales,
      totalInBs,
      averageTicket: facturas.length > 0 ? this.roundMoney(totalSales / facturas.length) : 0,
      totalInvoices: facturas.length
    };
  }
}

export default new CalculationService();
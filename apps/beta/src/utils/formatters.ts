class Formatters {
  formatCurrency(amount: number, currency: 'USD' | 'Bs' = 'USD'): string {
    return new Intl.NumberFormat('es-VE', {
      style: 'currency',
      currency: currency === 'USD' ? 'USD' : 'VES'
    }).format(amount)
  }

  formatDate(date: Date, format: 'short' | 'long' | 'time' = 'short'): string {
    switch (format) {
      case 'short':
        return date.toLocaleDateString('es-ES')
      case 'long':
        return date.toLocaleDateString('es-ES', {
          weekday: 'long',
          year: 'numeric',
          month: 'long',
          day: 'numeric'
        })
      case 'time':
        return date.toLocaleTimeString('es-ES')
      default:
        return date.toString()
    }
  }

  formatNumber(number: number, decimals: number = 2): string {
    return number.toFixed(decimals)
  }

  formatPercentage(value: number, decimals: number = 1): string {
    return (value * 100).toFixed(decimals) + '%'
  }

  formatPhone(phone: string): string {
    // Formato específico para Venezuela
    return phone.replace(/(\+58)?(\d{3})(\d{3})(\d{4})/, '+58 $1 $2 $3')
  }

  truncateText(text: string, maxLength: number): string {
    if (text.length <= maxLength) return text
    return text.substring(0, maxLength) + '...'
  }
}

export default new Formatters()
class Validators {
  required(value: any): boolean {
    return value !== null && value !== undefined && value !== ''
  }

  email(email: string): boolean {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return re.test(email)
  }

  phone(phone: string): boolean {
    const re = /^[\+]?[0-9\-\s\(\)]{10,}$/
    return re.test(phone)
  }

  number(value: any): boolean {
    return !isNaN(value) && isFinite(value)
  }

  positiveNumber(value: any): boolean {
    return this.number(value) && parseFloat(value) > 0
  }

  min(value: number, minValue: number): boolean {
    return value >= minValue
  }

  max(value: number, maxValue: number): boolean {
    return value <= maxValue
  }

  minLength(value: string, length: number): boolean {
    return value.length >= length
  }

  maxLength(value: string, length: number): boolean {
    return value.length <= length
  }

  rif(rif: string): boolean {
    // Validación básica para RIF venezolano
    const re = /^[JG]-\d{8}-\d$/
    return re.test(rif)
  }

  cedula(cedula: string): boolean {
    // Validación básica para cédula venezolana
    const re = /^[V,E]-\d{8}$/
    return re.test(cedula)
  }
}

export default new Validators()
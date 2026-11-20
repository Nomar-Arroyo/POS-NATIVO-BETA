import storageService from '../storage/storageService'
import { Config } from '../../types'

class ConfigService {
  private defaultConfig: Config = {
    establishmentName: 'CAFÉ ANALÍTICA C.A.',
    taxId: 'J-12345678-9',
    currency: 'USD',
    exchangeRate: 20.0,
    exchangeRateSource: 'BCV',
    ivaRate: 0.16,
    igtfRate: 0.03,
    fiscalSimulation: true,
    printWidth: 58
  }

  getConfig(): Config {
    return storageService.getConfig()
  }

  updateConfig(updates: Partial<Config>): Config {
    const currentConfig = this.getConfig()
    const newConfig = { ...currentConfig, ...updates }

    storageService.setConfig(newConfig)
    return newConfig
  }

  validateConfig(config: Config): { isValid: boolean; errors: string[] } {
    const errors: string[] = []

    if (!config.establishmentName || config.establishmentName.trim().length < 3) {
      errors.push('El nombre del establecimiento debe tener al menos 3 caracteres')
    }

    if (!config.taxId || config.taxId.trim().length < 5) {
      errors.push('El RIF/Cédula debe tener al menos 5 caracteres')
    }

    if (!Number.isFinite(config.exchangeRate) || config.exchangeRate <= 0) {
      errors.push('La tasa de cambio debe ser mayor a 0')
    }

    if (config.ivaRate < 0 || config.ivaRate > 1) {
      errors.push('El IVA debe estar entre 0% y 100%')
    }

    if (config.igtfRate < 0 || config.igtfRate > 1) {
      errors.push('El IGTF debe estar entre 0% y 100%')
    }

    return {
      isValid: errors.length === 0,
      errors
    }
  }

  resetToDefault(): Config {
    storageService.setConfig(this.defaultConfig)
    return this.defaultConfig
  }

  exportConfig(): string {
    return JSON.stringify(this.getConfig(), null, 2)
  }

  importConfig(configJson: string): { success: boolean; message: string } {
    try {
      const config = JSON.parse(configJson)
      const validation = this.validateConfig(config)

      if (!validation.isValid) {
        return {
          success: false,
          message: `Configuración inválida: ${validation.errors.join(', ')}`
        }
      }

      storageService.setConfig(config)
      return { success: true, message: 'Configuración importada correctamente' }
    } catch (error) {
      return { success: false, message: 'Error parseando la configuración' }
    }
  }
}

export default new ConfigService()

import { useMemo } from 'react'
import { useStore } from '../store/store'
import configService from '../services/config/configService'
import { Config } from '../types'

export const useConfig = () => {
  const { config, setConfig, updateExchangeRate } = useStore()

  const actions = useMemo(() => ({
    // Actualizar configuración completa
    updateConfig: (updates: Partial<Config>) => {
      const newConfig = { ...config, ...updates }
      const validation = configService.validateConfig(newConfig)
      
      if (validation.isValid) {
        if (newConfig.exchangeRate !== config.exchangeRate) {
          setConfig({ ...newConfig, exchangeRate: config.exchangeRate })
          updateExchangeRate(newConfig.exchangeRate)
        } else {
          setConfig(newConfig)
        }
        return { success: true, message: 'Configuración actualizada' }
      } else {
        return { 
          success: false, 
          message: `Error: ${validation.errors.join(', ')}` 
        }
      }
    },

    // Actualizar tasa de cambio específico
    updateRate: (rate: number) => {
      if (rate <= 0) {
        return { success: false, message: 'La tasa debe ser mayor a 0' }
      }
      
      updateExchangeRate(rate)
      return { success: true, message: 'Tasa de cambio actualizada' }
    },

    // Resetear a valores por defecto
    resetToDefault: () => {
      const defaultConfig = configService.resetToDefault()
      setConfig(defaultConfig)
      if (defaultConfig.exchangeRate !== config.exchangeRate) {
        updateExchangeRate(
          defaultConfig.exchangeRate,
          defaultConfig.exchangeRateSource ?? 'BCV'
        )
      }
      return { success: true, message: 'Configuración reseteada' }
    },

    // Validar configuración actual
    validate: () => configService.validateConfig(config)
  }), [config, setConfig, updateExchangeRate])

  return {
    config,
    ...actions
  }
}

export default useConfig
import { useCallback, useState } from 'react'

export interface ValidationRule {
  required?: boolean
  minLength?: number
  maxLength?: number
  min?: number
  max?: number
  pattern?: RegExp
  custom?: (value: unknown) => boolean | string
}

export interface FieldConfig {
  validation?: ValidationRule
  errorMessage?: string
}

type FieldErrors<T> = Partial<Record<keyof T, string>>
type TouchedFields<T> = Partial<Record<keyof T, boolean>>

const isEmptyValue = (value: unknown): boolean =>
  value === undefined || value === null ||
  (typeof value === 'string' && value.trim() === '')

export const useFormValidation = <T extends Record<string, unknown>>(
  initialState: T,
  fieldConfigs: Partial<Record<keyof T, FieldConfig>> = {}
) => {
  const [values, setValues] = useState<T>(initialState)
  const [errors, setErrors] = useState<FieldErrors<T>>({})
  const [touched, setTouched] = useState<TouchedFields<T>>({})

  const validateField = useCallback((name: keyof T, value: unknown): string => {
    const config = fieldConfigs[name]
    const validation = config?.validation
    if (!validation) return ''

    if (validation.required && isEmptyValue(value)) {
      return config.errorMessage || 'Este campo es obligatorio'
    }
    if (isEmptyValue(value)) return ''

    const text = String(value)
    if (validation.minLength !== undefined && text.length < validation.minLength) {
      return config.errorMessage || `Mínimo ${validation.minLength} caracteres`
    }
    if (validation.maxLength !== undefined && text.length > validation.maxLength) {
      return config.errorMessage || `Máximo ${validation.maxLength} caracteres`
    }

    if (validation.min !== undefined || validation.max !== undefined) {
      const numberValue = typeof value === 'number' ? value : Number(text)
      if (!Number.isFinite(numberValue)) {
        return config.errorMessage || 'Debe ingresar un número válido'
      }
      if (validation.min !== undefined && numberValue < validation.min) {
        return config.errorMessage || `El valor debe ser mayor o igual a ${validation.min}`
      }
      if (validation.max !== undefined && numberValue > validation.max) {
        return config.errorMessage || `El valor debe ser menor o igual a ${validation.max}`
      }
    }

    if (validation.pattern) {
      validation.pattern.lastIndex = 0
      if (!validation.pattern.test(text)) {
        return config.errorMessage || 'Formato inválido'
      }
    }

    const customResult = validation.custom?.(value)
    if (typeof customResult === 'string') return customResult
    if (customResult === false) return config.errorMessage || 'Valor inválido'
    return ''
  }, [fieldConfigs])

  const handleChange = useCallback(<K extends keyof T>(name: K, value: T[K]) => {
    setValues(previous => ({ ...previous, [name]: value }))
    if (touched[name]) {
      const error = validateField(name, value)
      setErrors(previous => ({ ...previous, [name]: error }))
    }
  }, [touched, validateField])

  const handleBlur = useCallback((name: keyof T) => {
    setTouched(previous => ({ ...previous, [name]: true }))
    const error = validateField(name, values[name])
    setErrors(previous => ({ ...previous, [name]: error }))
  }, [values, validateField])

  const validateAll = useCallback((): boolean => {
    const newErrors: FieldErrors<T> = {}
    let valid = true

    for (const name of Object.keys(fieldConfigs) as Array<keyof T>) {
      const error = validateField(name, values[name])
      if (error) {
        newErrors[name] = error
        valid = false
      }
    }

    setErrors(newErrors)
    setTouched(Object.keys(fieldConfigs).reduce<TouchedFields<T>>((result, name) => {
      result[name as keyof T] = true
      return result
    }, {}))
    return valid
  }, [fieldConfigs, validateField, values])

  const reset = useCallback(() => {
    setValues({ ...initialState })
    setErrors({})
    setTouched({})
  }, [initialState])

  const isValid = Object.values(errors).every(error => !error)

  return {
    values,
    errors,
    touched,
    handleChange,
    handleBlur,
    validateAll,
    reset,
    isValid,
    setValues
  }
}

export default useFormValidation

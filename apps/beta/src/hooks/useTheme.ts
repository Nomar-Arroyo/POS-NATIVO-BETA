import { useCallback, useEffect, useState } from 'react'

export type AppTheme = 'dark' | 'light'

const THEME_STORAGE_KEY = 'pos_nativo_beta_theme'

const getInitialTheme = (): AppTheme => {
  try {
    return localStorage.getItem(THEME_STORAGE_KEY) === 'light' ? 'light' : 'dark'
  } catch (error) {
    console.error('No se pudo leer el tema guardado:', error)
    return 'dark'
  }
}

export const useTheme = () => {
  const [theme, setTheme] = useState<AppTheme>(getInitialTheme)

  useEffect(() => {
    const root = document.documentElement
    root.classList.toggle('theme-light', theme === 'light')
    root.dataset.theme = theme

    try {
      localStorage.setItem(THEME_STORAGE_KEY, theme)
    } catch (error) {
      console.error('No se pudo guardar el tema seleccionado:', error)
    }
  }, [theme])

  const toggleTheme = useCallback(() => {
    setTheme(currentTheme => currentTheme === 'dark' ? 'light' : 'dark')
  }, [])

  return { theme, toggleTheme }
}

export default useTheme

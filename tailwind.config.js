module.exports = {
  content: [
    './src/**/*.{js,ts,jsx,tsx}',
    './src-tauri/**/*.html'
  ],
  theme: {
    extend: {
      colors: {
        'amalfi': {
          turquoise: '#159FA2',
          deep: '#087E83',
          white: '#FFFFFF',
          graphite: '#202B30'
        },
        'navy': {
          900: '#0a0e27',
          800: '#131a3a',
          700: '#1e2749',
          600: '#2a3a66'
        },
        'slate': {
          900: '#0f172a',
          800: '#1e293b',
          700: '#334155',
          600: '#475569'
        },
        'orange': {
          500: '#f97316',
          600: '#ea580c',
          700: '#c2410c'
        },
        'electric': {
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8'
        }
      },
      animation: {
        'fade-in': 'fadeIn 0.3s ease-in-out',
        'slide-in-right': 'slideInRight 0.3s ease-out',
        'pulse-slow': 'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite'
      },
      keyframes: {
        fadeIn: {
          '0%': { opacity: '0', transform: 'translateY(10px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' }
        },
        slideInRight: {
          '0%': { transform: 'translateX(100%)', opacity: '0' },
          '100%': { transform: 'translateX(0)', opacity: '1' }
        }
      }
    }
  },
  plugins: []
}
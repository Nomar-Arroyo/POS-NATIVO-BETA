import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import https from 'node:https'
import tls from 'node:tls'
import path from 'path'

const defaultCaCertificates = tls.getCACertificates?.('default') ?? []
const systemCaCertificates = tls.getCACertificates?.('system') ?? []
const bcvProxyAgent = systemCaCertificates.length > 0
  ? new https.Agent({
    ca: [...defaultCaCertificates, ...systemCaCertificates]
  })
  : undefined

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, 'src')
    }
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,
    minify: 'esbuild'
  },
  server: {
    port: 1420,
    strictPort: true,
    host: true,
    proxy: {
      '/api/bcv-rate': {
        target: 'https://www.bcv.org.ve',
        changeOrigin: true,
        secure: true,
        agent: bcvProxyAgent,
        rewrite: () => '/estadisticas/tipo-cambio-de-referencia-smc'
      }
    },
    watch: {
      ignored: ['**/src-tauri/**']
    }
  }
})
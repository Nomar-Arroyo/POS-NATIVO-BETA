# Arquitectura

## Vista general

La aplicación es una SPA de escritorio local-first. La entrada es `src/main.tsx`,
que inicializa el almacenamiento y monta `src/App.tsx`. El componente raíz carga
los módulos de forma diferida y muestra `Layout`, que incluye navegación,
encabezado y contenido. La selección de módulo se mantiene en el estado de
interfaz; no se usa un router de URL.

```text
React + TypeScript (módulos, componentes y hooks)
                  |
             Zustand store
                  |
     Servicios de dominio y utilidades
        |                     |
   storageService        impresión WebView
        |
 localStorage del navegador/WebView

Tauri 2 / Rust ---- reqwest con TLS ---- página oficial del BCV
```

## Capas y responsabilidades

- **Interfaz (`src/modules`, `src/components`, `src/hooks`):** pantallas de
  operación, componentes compartidos, navegación, formularios y coordinación de
  acciones. React y Tailwind CSS implementan la experiencia adaptable; los iconos
  vectoriales se centralizan en `Icon`.
- **Estado (`src/store/store.ts`):** Zustand conserva el estado de sesión en
  memoria y coordina cambios con los servicios de persistencia y dominio.
- **Dominio (`src/services`):** reúne reglas de cálculo, ventas, comandas, mesas,
  caja, auditoría, cancelaciones, división de cuenta, tasa BCV y simulación fiscal.
- **Persistencia (`src/services/storage/storageService.ts`):** guarda el
  documento de datos local, rellena valores ausentes y aplica migraciones simples.
- **Escritorio (`src-tauri`):** Tauri 2 presenta la WebView. El comando Rust
  `fetch_bcv_exchange_rate_page` consulta el sitio oficial mediante `reqwest` con
  `rustls`; no desactiva la verificación TLS.
- **Desarrollo web (`vite.config.ts`):** `/api/bcv-rate` se dirige al sitio del
  BCV con TLS verificado. En producción nativa la consulta usa el comando Tauri.

No existe API propia ni base de datos central. La conexión de red funcional es la
consulta a la página pública del BCV; las operaciones y catálogos permanecen en
el equipo.

## Decisiones importantes

1. **Persistencia local:** se eligió `localStorage` para simplificar la beta sin
   servidor. Cada perfil de navegador/WebView mantiene su propio conjunto de
   datos; esto no ofrece sincronización, transacciones multiusuario ni cifrado de
   datos sensibles.
2. **Moneda base:** los precios de productos y los importes operativos se
   calculan en USD; los equivalentes en bolívares dependen de la tasa configurada.
   Una tasa manual se conserva frente a una consulta BCV automática. Una tasa
   oficial con fecha futura se almacena, pero no se aplica antes de ser efectiva.
3. **Consulta BCV:** la aplicación de escritorio usa Rust para evitar depender de
   CORS en la WebView. La aplicación web de desarrollo usa el proxy de Vite.
   Ambos caminos mantienen la verificación TLS.
4. **Fiscalidad:** la emisión se marca explícitamente como simulada. Los números
   de factura/control y los cálculos actuales no representan una integración ni
   certificación fiscal.
5. **Impresión:** la beta delega en la ventana de impresión y en los controladores
   instalados en el sistema, en lugar de implementar protocolos directos de
   impresora.
6. **Versiones Windows:** el proyecto conserva `1.0.0-beta`, mientras que
   `tauri.windows.conf.json` declara una versión numérica compatible con MSI. El
   número de esa configuración debe actualizarse al preparar una entrega.

## Inicio de la aplicación

`src/App.tsx` carga los módulos bajo demanda, inicializa la tienda y comprueba si
debe cargar los productos de demostración. La tasa BCV se consulta al iniciar y
se vuelve a comprobar cada hora; solo se solicita de nuevo automáticamente
cuando corresponde a un nuevo día calendario en `America/Caracas`. La interfaz
permite refrescarla manualmente.
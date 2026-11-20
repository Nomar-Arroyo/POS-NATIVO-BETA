# Café Amalfi POS — Beta

Aplicación de punto de venta para cafetería/restaurante, construida como una SPA
React y distribuida como aplicación de escritorio mediante Tauri. Esta versión
beta permite probar ventas, mesas, comandas, caja, reportes y configuración con
datos guardados localmente. **No está certificada para operar como sistema fiscal
ni como plataforma multiusuario de producción.**

## Funcionalidades principales

- Salón con sesiones de mesa, comandas, precuentas y división de cuentas.
- POS de venta directa y pagos en USD, bolívares o combinados.
- Consulta básica del inventario y catálogo de ejemplo para probar ventas.
- Comandas separadas para cocina y barra.
- Sesiones de caja, movimientos, reportes X/Z, reportes de ventas y auditoría.
- Consulta de tasa de referencia USD del BCV, con aplicación condicionada a la
  fecha de vigencia y posibilidad de conservar una tasa manual.
- Impresión mediante el diálogo del sistema y formatos de 58 mm u 80 mm.
- Tema claro/oscuro y diseño adaptable.

## Arquitectura y tecnologías

La interfaz está en `src/`: React 18, TypeScript estricto, Vite y Tailwind CSS.
Zustand mantiene el estado en memoria; los servicios aíslan los cálculos y las
operaciones de ventas, mesas, caja, impresión y persistencia. Tauri 2 y Rust
proporcionan la ventana de escritorio y la consulta nativa al BCV. Las pruebas
usan Vitest.

No hay servidor de negocio ni base de datos remota: los datos de operación se
guardan en el almacenamiento local del navegador/WebView. Consulta
[docs/ARQUITECTURA.md](./docs/ARQUITECTURA.md) y
[docs/MODELO_DE_DATOS.md](./docs/MODELO_DE_DATOS.md) para el detalle.

## Requisitos

Para desarrollo web: Node.js 22 (22.12 o posterior) y npm.

Para compilar la aplicación de escritorio en Windows se requieren además Windows
10/11 de 64 bits, Rust estable con `x86_64-pc-windows-msvc`, Microsoft C++ Build
Tools y WebView2 Runtime. La primera compilación puede necesitar conexión a
Internet para descargar dependencias y herramientas de empaquetado.

## Instalación y desarrollo local

Desde la raíz del proyecto:

```powershell
npm ci
npm run dev
```

Vite inicia el servidor de desarrollo en `http://localhost:1420`. Para abrir la
ventana nativa de Tauri mientras Vite sirve la interfaz:

```powershell
npm run tauri:dev
```

En el primer inicio se cargan productos de demostración si el catálogo está
vacío. Antes de probar, revisa [docs/FUNCIONALIDADES.md](./docs/FUNCIONALIDADES.md)
y [docs/LIMITACIONES_BETA.md](./docs/LIMITACIONES_BETA.md).

## Pruebas y compilación

```powershell
npm run typecheck
npm run test:all
npm run test:coverage
npm run build
```

`npm run build` compila únicamente la interfaz web en `dist/`. Los comandos y el
alcance de las pruebas se describen en [docs/PRUEBAS.md](./docs/PRUEBAS.md).

## Empaquetado e instalación en Windows

Para crear los instaladores MSI y NSIS y ejecutar previamente los chequeos:

```powershell
npm run package:windows
```

El MSI se genera en `src-tauri/target/release/bundle/msi/` y el instalador NSIS
en `src-tauri/target/release/bundle/nsis/`. Para compilar solo los paquetes
nativos se puede usar `npm run tauri:build:windows`. Los instaladores beta no
están firmados por defecto. Consulta
[docs/INSTALACION_WINDOWS.md](./docs/INSTALACION_WINDOWS.md).

## Persistencia y datos de demostración

`storageService` guarda la configuración y los datos operativos en `localStorage`
del navegador o del perfil WebView local. No hay sincronización entre equipos.
La aplicación ofrece exportación/importación JSON y copia local; aun así, exporta
una copia antes de reiniciar datos o cambiar de entorno.

El conjunto de demostración contiene 23 productos, 8 categorías, 12 mesas
numeradas más Barra, Para llevar y Delivery, y perfiles locales de ejemplo. No
uses datos reales de clientes o transacciones para probar la beta.
La edición completa del catálogo aún no está expuesta en la navegación principal
y el ajuste de stock del inventario todavía es un control sin operación asociada.

## Impresión y documentos fiscales

La impresión abre una ventana con el documento y utiliza el diálogo de impresión
del sistema operativo. Requiere una impresora instalada y configurada; no existe
integración directa con comandos ESC/POS ni garantía de corte, cajón o periféricos.

La factura y su número de control se generan en modo simulado. No se transmiten al
SENIAT y no son documentos fiscales válidos. Los detalles están en
[docs/LIMITACIONES_BETA.md](./docs/LIMITACIONES_BETA.md).

## Documentación

- [Arquitectura](./docs/ARQUITECTURA.md)
- [Funcionalidades](./docs/FUNCIONALIDADES.md)
- [Modelo de datos](./docs/MODELO_DE_DATOS.md)
- [Pruebas](./docs/PRUEBAS.md)
- [Instalación en Windows](./docs/INSTALACION_WINDOWS.md)
- [Limitaciones de la beta](./docs/LIMITACIONES_BETA.md)
- [Pendientes para la fase Full](./docs/PENDIENTES_FASE_FULL.md)
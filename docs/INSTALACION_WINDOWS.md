# Empaquetar e instalar en Windows

## Requisitos de compilación

- Windows 10 u 11 de 64 bits.
- Node.js 22.12 o posterior y npm.
- Rust estable con el destino `x86_64-pc-windows-msvc`.
- Microsoft C++ Build Tools con el toolset MSVC y WebView2 Runtime, según los
  requisitos de Tauri 2.
- Acceso a Internet durante la primera compilación para obtener dependencias de
  npm/Cargo y las herramientas WiX/NSIS que utiliza Tauri.

## Compilar y empaquetar

Desde la raíz del proyecto:

```powershell
npm ci
npm run typecheck
npm run test:all
npm run build
```

Para compilar la ventana nativa y generar ambos instaladores:

```powershell
npm run tauri:build:windows
```

Para ejecutar chequeos de tipo, todas las pruebas, el empaquetado y la
validación final en una sola secuencia:

```powershell
npm run package:windows
```

El proceso compila la interfaz con Vite y crea paquetes nativos MSI/NSIS. No
elimina builds ni instaladores anteriores antes de empezar.

Windows Installer requiere una versión numérica; `tauri.windows.conf.json`
sobrescribe el sufijo beta solo para el empaquetado de Windows. Actualmente
declara `1.0.0`; actualiza ese número al preparar una nueva entrega.

Los paquetes x64 se generan en:

- MSI: `src-tauri/target/release/bundle/msi/`
- NSIS: `src-tauri/target/release/bundle/nsis/`

El ejecutable interno se crea en `src-tauri/target/release/`, pero no sustituye
a los instaladores.

## Instalación y distribución

Ejecuta el instalador `.msi` o el `.exe` de NSIS en el equipo destino. Se
recomienda probar ambos formatos en una máquina limpia antes de distribuirlos.

Los instaladores beta no están firmados por defecto y Windows puede mostrar una
advertencia de SmartScreen. Para distribución pública configura firma con un
certificado protegido fuera del repositorio y valida el proceso de actualización.

## CI

El workflow `.github/workflows/build-windows.yml` ejecuta chequeos de tipos,
pruebas y empaquetado en `windows-latest` para cambios enviados a `main` o
`develop` y pull requests dirigidos a `main`. Publica MSI y NSIS como artefacto
descargable de GitHub Actions. El artefacto de CI sirve para prueba; antes de una
publicación real hay que revisar firma, versión y procedimiento de instalación.
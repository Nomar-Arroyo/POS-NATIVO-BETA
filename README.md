# Café Amalfi POS

Repositorio de las aplicaciones Café Amalfi POS y sus paquetes compartidos.
La Beta y Flutter se mantienen como productos separados: la nueva app no lee ni
modifica el almacenamiento local de la Beta.

## Aplicaciones

- [Beta React/Tauri](apps/beta/README.md): referencia funcional existente.
- [Desktop Flutter](apps/desktop/README.md): aplicación completa para Windows.
- [App móvil de gerencia](apps/mobile_manager/README.md): espacio reservado para
  la aplicación móvil del gerente; su alcance funcional se desarrollará por
  separado.

## Paquetes y documentación

- `packages/`: reglas de negocio, persistencia, sincronización y recursos
  compartidos entre aplicaciones Flutter.
- [Arquitectura objetivo](ARQUITECTURA_OBJETIVO.md), [roadmap](ROADMAP.md),
  [seguridad](SECURITY.md), [sincronización offline](OFFLINE_SYNC.md) y
  [estrategia de pruebas](TESTING.md).

## Comandos principales

Beta:

```powershell
Set-Location apps/beta
npm ci
npm run dev
npm run typecheck
npm run test:all
npm run build
```

Flutter Desktop:

```powershell
Set-Location apps/desktop
flutter pub get
flutter analyze
flutter test
flutter build windows
```

Los datos de demostración de la Beta no son datos de producción. No se deben
importar ni eliminar datos reales sin autorización.

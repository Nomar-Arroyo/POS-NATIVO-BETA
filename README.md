# Café Amalfi POS

Monorepo de la aplicación Café Amalfi en desarrollo: una Beta React/Tauri
conservada como referencia, un POS Flutter para Windows y una nueva aplicación
Flutter móvil en preparación. Los paquetes compartidos aíslan cálculos,
persistencia local, sincronización y recursos de marca. El backend PostgreSQL
está implementado y probado localmente; aún no se ha desplegado a Supabase.

## Aplicaciones

- [Beta React/Tauri](apps/beta/README.md): versión anterior conservada como
  referencia funcional; sus datos permanecen separados.
- [POS Desktop Flutter](apps/desktop/README.md): aplicación Windows offline-first
  con sincronización opcional a Supabase (`confirm_sale`).
- [App móvil Flutter](apps/mobile/README.md): scaffold inicial para las
  experiencias gerencial y de pedidos de clientes; las funciones están por
  desarrollar.

## Paquetes

- [core_money](packages/core_money/README.md): importes y cálculos exactos.
- [core_sync](packages/core_sync/README.md): contratos de sincronización.
- [data_local](packages/data_local/README.md): almacenamiento SQLite local.
- [data_migration](packages/data_migration/README.md): importación piloto.
- [amalfi_brand_assets](packages/amalfi_brand_assets/README.md): recursos de
  marca compartidos.

## Documentación

- [Plan de trabajo compartido](docs/PLAN_TRABAJO.md)
- [Arquitectura objetivo](ARQUITECTURA_OBJETIVO.md)
- [Roadmap](ROADMAP.md)
- [Seguridad](SECURITY.md)
- [Arquitectura de backend](docs/BACKEND_ARCHITECTURE.md)
- [Esquema de datos](docs/DATABASE_SCHEMA.md)
- [Contratos de API](docs/API_CONTRACTS.md)
- [Autorización](docs/AUTHORIZATION.md)
- [Tablets de clientes](docs/CUSTOMER_TABLETS.md)
- [Protocolo de sincronización](docs/SYNC_PROTOCOL.md)
- [Despliegue del backend](docs/BACKEND_DEPLOYMENT.md)
- [App móvil](docs/MOBILE_APP.md)
- [Documentación de referencia](docs/reference/)

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

Flutter Mobile:

```powershell
Set-Location apps/mobile
flutter pub get
flutter analyze
flutter test
```

La carpeta `supabase/` contiene las migraciones, el seed de desarrollo y las
pruebas de integración del backend local. No contiene secretos ni un despliegue
activo; consulta [docs/BACKEND_DEPLOYMENT.md](docs/BACKEND_DEPLOYMENT.md).

Los datos de demostración de la Beta no son datos de producción. No se deben
importar ni eliminar datos reales sin autorización.

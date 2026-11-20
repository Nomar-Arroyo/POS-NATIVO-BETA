# Pruebas

## Ejecución

Desde la raíz del proyecto (PowerShell):

```powershell
npm test
npm run test:watch
npm run test:all
npm run test:unit
npm run test:integration
npm run test:coverage
npm run typecheck
npm run build
```

Las pruebas usan Vitest en entorno Node. No sustituyen pruebas manuales de
impresoras, WebView, instaladores ya instalados ni validación fiscal.

## Cobertura funcional

- Consulta BCV: lectura de tasa/fecha, formatos numéricos, fechas futuras,
  errores HTTP, comando Tauri y solicitudes concurrentes.
- Configuración y estado: validación de tasas, conservación de tasa manual,
  almacenamiento de cotización BCV y aplicación explícita cuando está vigente.
- Cálculos: redondeo, impuestos simulados, pagos mixtos USD/Bs y saldos.
- Verificación: referencias de órdenes/mesas y conciliación de pagos.
- Integración operativa: mesas, comandas por estación, precuentas, caja y
  división equitativa de cuentas.

En la ejecución verificada para esta entrega pasaron **28 pruebas en 8 archivos**.
`npm run test:coverage` midió **14,58 % de sentencias, 11,75 % de ramas,
12,25 % de funciones y 15,10 % de líneas** en todo `src`. Es una cobertura inicial:
varias pantallas y flujos de interfaz no tienen pruebas automatizadas.

## Comprobaciones manuales

- [x] **Navegación y responsive:** 320, 390, 720 y 1366 px; menú móvil, cierre
  con Escape, ausencia de desbordamiento horizontal y temas claro/oscuro.
- [ ] **Tasa BCV:** consulta al iniciar y al cambiar el día; actualización manual,
  conservación de tasa manual y aplicación explícita de tasa BCV vigente.
- [ ] **Mesas:** abrir, modificar artículos, enviar comanda, emitir precuenta,
  dividir cuenta y cerrar sesión.
- [ ] **Venta y pagos:** venta directa; pagos USD, Bs y mixtos; revisar factura
  simulada.
- [ ] **Comandas:** cambiar estados en cocina y barra.
- [ ] **Caja:** apertura/cierre, movimientos y reportes X/Z.
- [ ] **Productos/inventario:** conectar el módulo de productos a la navegación
  principal y completar/verificar el ajuste de stock (actualmente pendiente).
- [ ] **Persistencia:** recargar y confirmar datos; exportar e importar una copia.
- [ ] **Impresión:** probar diálogos, papel y márgenes en cada modelo de impresora.

Los escenarios manuales deben ejecutarse con datos de demostración o una copia
de prueba. No uses información operativa real. El empaquetado integral se ejecuta
con `npm run package:windows` y produce MSI/NSIS únicamente en Windows.
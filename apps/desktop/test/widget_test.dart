import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amalfi_pos_desktop/app.dart';
import 'package:amalfi_pos_desktop/desktop_state.dart';
import 'package:amalfi_pos_desktop/widgets/amalfi_ui.dart';
import 'package:data_local/data_local.dart';
import 'package:amalfi_pos_desktop/widgets/payment_allocation_dialog.dart';

void main() {
  testWidgets('Desktop app renders database unavailable state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AmalfiDesktopApp());

    expect(find.text('La base local no está disponible'), findsOneWidget);
  });

  testWidgets('first run requests real local workspace details', (
    WidgetTester tester,
  ) async {
    final database = await LocalDatabase.openInMemory();
    addTearDown(database.close);

    await tester.pumpWidget(AmalfiDesktopApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Configuración local inicial'), findsOneWidget);
    expect(find.text('Empresa'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Guardar en este equipo'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Guardar en este equipo'), findsOneWidget);
    expect(database.localWorkspace, isNull);
  });

  testWidgets('first run can open and exit the isolated demo', (
    WidgetTester tester,
  ) async {
    final database = await LocalDatabase.openInMemory();
    addTearDown(database.close);

    await tester.pumpWidget(AmalfiDesktopApp(database: database));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Abrir demo aislada'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Abrir demo aislada'));
    await tester.pumpAndSettle();

    expect(find.text('DEMO'), findsOneWidget);
    expect(database.localWorkspace, isNull);
    await tester.tap(find.byTooltip('Salir del entorno demo'));
    await tester.pumpAndSettle();

    expect(find.text('Configuración local inicial'), findsOneWidget);
    expect(database.localWorkspace, isNull);
  });

  testWidgets('payment dialog accepts exact split payments in USD', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    List<LocalPaymentInput>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await showPaymentAllocation(
                    context,
                    totalMinor: BigInt.from(1000),
                  );
                },
                child: const Text('Cobrar'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cobrar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '6.00');
    await tester.tap(find.text('Agregar método de pago'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, '4.00');
    await tester.tap(find.text('Confirmar pagos'));
    await tester.pumpAndSettle();

    expect(result, hasLength(2));
    expect(
      result!.fold(
        BigInt.zero,
        (sum, payment) => sum + BigInt.parse(payment.amountMinor),
      ),
      BigInt.from(1000),
    );
  });

  testWidgets('desktop exposes table and kitchen/bar modules', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = await LocalDatabase.openInMemory();
    addTearDown(database.close);
    database.createLocalWorkspace(
      const LocalWorkspaceInput(
        organizationId: 'widget-org',
        organizationName: 'Synthetic Widget Cafe',
        branchId: 'widget-branch',
        branchName: 'Synthetic Branch',
        terminalId: 'widget-terminal',
        terminalName: 'Widget Terminal',
        profileId: 'widget-profile',
        profileName: 'Widget Operator',
        profilePin: '1234',
        warehouseId: 'widget-warehouse',
        warehouseName: 'Widget Warehouse',
        cashRegisterId: 'widget-cash',
        cashRegisterName: 'Widget Register',
      ),
    );

    await tester.pumpWidget(AmalfiDesktopApp(database: database));
    await tester.pumpAndSettle();
    await _signIn(tester);
    await tester.tap(find.text('Mesas y Salón'));
    await tester.pumpAndSettle();
    expect(find.text('Salón y Mesas'), findsOneWidget);
    expect(find.text('Agregar mesa'), findsOneWidget);
    await tester.tap(find.text('Comandas'));
    await tester.pumpAndSettle();
    expect(find.text('Comandas'), findsWidgets);
    expect(find.textContaining('Cocina'), findsWidgets);
    expect(find.textContaining('Barra'), findsWidgets);
  });

  testWidgets(
    'screens follow the Amalfi beta modules and demo catalog is marked',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = await LocalDatabase.openInMemory();
      addTearDown(database.close);
      database.createLocalWorkspace(
        const LocalWorkspaceInput(
          organizationId: 'visual-org',
          organizationName: 'Caffè Amalfi',
          branchId: 'visual-branch',
          branchName: 'Principal',
          terminalId: 'visual-terminal',
          terminalName: 'Terminal 1',
          profileId: 'visual-profile',
          profileName: 'Administrador',
          profilePin: '1234',
          warehouseId: 'visual-warehouse',
          warehouseName: 'Principal',
          cashRegisterId: 'visual-cash',
          cashRegisterName: 'Caja 1',
        ),
      );
      await tester.pumpWidget(AmalfiDesktopApp(database: database));
      await tester.pumpAndSettle();
      await _signIn(tester);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Gestiona, vende y disfruta'), findsOneWidget);
      final sidebarSlogan = find.text('Sabor que inspira...');
      expect(sidebarSlogan, findsOneWidget);
      expect(tester.widget<Text>(sidebarSlogan).style?.fontFamily, 'Georgia');
      expect(
        tester.getRect(find.text('Gestiona, vende y disfruta')).right,
        greaterThan(1320),
      );
      expect(
        tester.getCenter(find.byTooltip('Seleccionar tema')).dx,
        greaterThan(1050),
      );
      expect(
        tester.getTopRight(find.byTooltip('Cerrar sesión')).dx,
        greaterThan(1320),
      );
      expect(find.text('No hay mesas configuradas'), findsOneWidget);
      expect(find.text('Todavía no hay comprobantes'), findsOneWidget);
      final coffeeBackground = find.byKey(
        const ValueKey('coffee-scene-background'),
      );
      expect(coffeeBackground, findsOneWidget);
      expect(tester.widget<Image>(coffeeBackground).fit, BoxFit.cover);
      expect(tester.getSize(coffeeBackground).height, greaterThan(600));
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1920, 1080);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1366, 768);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AnimatedOpacity), findsOneWidget);
      expect(find.text('Modo claro'), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      await tester.tap(find.text('Modo claro'));
      await tester.pumpAndSettle();
      expect(find.text('Modo oscuro'), findsOneWidget);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.light,
      );
      expect(find.text('Gestiona, vende y disfruta'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1920, 1080);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      tester.view.physicalSize = const Size(1366, 768);
      await tester.pumpAndSettle();
      expect(database.getLocalPreference('desktop.theme_mode'), 'light');
      final restoredAppearance = DesktopAppearanceModel(database: database);
      expect(restoredAppearance.themeMode, ThemeMode.light);
      restoredAppearance.dispose();
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .theme!
            .inputDecorationTheme
            .filled,
        isTrue,
      );
      await tester.tap(find.text('Modo oscuro'));
      await tester.pumpAndSettle();
      expect(database.getLocalPreference('desktop.theme_mode'), 'dark');

      await tester.tap(find.byTooltip('Seleccionar tema'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sistema'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.system,
      );
      expect(database.getLocalPreference('desktop.theme_mode'), 'system');
      await tester.tap(find.byTooltip('Seleccionar tema'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Inventario'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cargar catálogo demo'));
      await tester.pumpAndSettle();
      expect(find.text('Inventario'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey(DesktopModule.inventory)),
          matching: find.text('Café Americano'),
        ),
        findsOneWidget,
      );
      expect(find.text('DEMO'), findsWidgets);
      await tester.tap(find.text('Agregar producto'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo producto local'), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(TextFormField).first))
            .inputDecorationTheme
            .filled,
        isTrue,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('POS / Venta'));
      await tester.pumpAndSettle();
      expect(find.text('POS - Venta Directa'), findsOneWidget);
      expect(find.text('Ticket de Venta'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey(DesktopModule.pos)),
          matching: find.text('Café Americano'),
        ),
        findsOneWidget,
      );
      final productSearch = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.hintText == 'Buscar producto por nombre...',
      );
      await tester.enterText(productSearch, 'capu');
      await tester.tap(find.text('Caja'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('POS / Venta'));
      await tester.pumpAndSettle();
      final searchEditor = find.descendant(
        of: productSearch,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(searchEditor).controller.text, 'capu');

      await tester.tap(find.text('Caja'));
      await tester.pumpAndSettle();
      expect(find.text('Gestión de Caja'), findsOneWidget);
      await tester.tap(find.text('Reportes'));
      await tester.pumpAndSettle();
      expect(find.text('Reporte de Ventas'), findsOneWidget);
      await tester.tap(find.text('Auditoría'));
      await tester.pumpAndSettle();
      expect(find.text('Auditoría del Sistema'), findsOneWidget);
      await tester.tap(find.text('Configuración'));
      await tester.pumpAndSettle();
      expect(find.text('Configuración Fiscal'), findsOneWidget);
      expect(find.text('Reglas fiscales desactivadas'), findsOneWidget);

      tester.view.physicalSize = const Size(900, 600);
      await tester.pumpAndSettle();
      for (final module in [
        'Dashboard',
        'Mesas y Salón',
        'POS / Venta',
        'Comandas',
        'Inventario',
        'Caja',
        'Reportes',
        'Auditoría',
        'Configuración',
      ]) {
        await tester.tap(find.byTooltip(module));
        await tester.pumpAndSettle();
        expect(find.byType(AmalfiBrandFooter), findsOneWidget);
      }

      tester.view.physicalSize = const Size(720, 600);
      await tester.pumpAndSettle();
      for (final module in [
        'POS / Venta',
        'Mesas y Salón',
        'Comandas',
        'Inventario',
      ]) {
        await tester.tap(find.byTooltip(module));
        await tester.pumpAndSettle();
        expect(find.byType(AmalfiBrandFooter), findsOneWidget);
      }
      await tester.tap(find.byTooltip('Dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('Gestiona, vende y disfruta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('Desktop navigation changes module', () {
    final navigation = DesktopNavigationModel();
    expect(navigation.activeModule, DesktopModule.dashboard);

    navigation.select(DesktopModule.pos);
    expect(navigation.activeModule, DesktopModule.pos);
  });
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, '1234');
  await tester.tap(find.text('Entrar'));
  await tester.pumpAndSettle();
}

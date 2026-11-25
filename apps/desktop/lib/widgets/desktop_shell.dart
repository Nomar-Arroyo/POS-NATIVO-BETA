import 'package:data_local/data_local.dart';
import 'package:amalfi_brand_assets/amalfi_brand_assets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../desktop_state.dart';
import '../theme/amalfi_theme.dart';
import 'amalfi_ui.dart';
import 'audit_screen.dart';
import 'cash_screen.dart';
import 'dashboard_screen.dart';
import 'dining_screen.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'production_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';

class DesktopShell extends StatelessWidget {
  const DesktopShell({required this.onLogout, super.key});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final navigation = context.watch<DesktopNavigationModel>();
    final database = context.read<LocalDatabase>();
    final workspace = database.localWorkspace!;
    final size = MediaQuery.sizeOf(context);
    final compact = size.width < 1050;
    final brandFooterHeight = (size.height * .10).clamp(64.0, 108.0);

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            selected: navigation.activeModule,
            compact: compact,
            allowedModules: navigation.allowedModules,
            onSelect: navigation.select,
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Column(
              children: [
                _DesktopHeader(
                  workspace: workspace,
                  isDemo: database.isDemoMode,
                  compact: compact,
                  onLogout: onLogout,
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const AmalfiPageBackground(child: SizedBox.expand()),
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: brandFooterHeight),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              for (final module in DesktopModule.values)
                                if (navigation.visitedModules.contains(module))
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      ignoring:
                                          navigation.activeModule != module,
                                      child: ExcludeSemantics(
                                        excluding:
                                            navigation.activeModule != module,
                                        child: AnimatedOpacity(
                                          opacity:
                                              navigation.activeModule == module
                                              ? 1
                                              : 0,
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          curve: Curves.easeInOut,
                                          child: AnimatedSlide(
                                            offset:
                                                navigation.activeModule ==
                                                    module
                                                ? Offset.zero
                                                : const Offset(.012, 0),
                                            duration: const Duration(
                                              milliseconds: 220,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            child: TickerMode(
                                              enabled:
                                                  navigation.activeModule ==
                                                  module,
                                              child: _ModuleContent(
                                                key: ValueKey(module),
                                                module: module,
                                                database: database,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: AmalfiBrandFooter(height: brandFooterHeight),
                      ),
                    ],
                  ),
                ),
                const _DesktopFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selected,
    required this.compact,
    required this.allowedModules,
    required this.onSelect,
  });

  final DesktopModule selected;
  final bool compact;
  final Set<DesktopModule> allowedModules;
  final ValueChanged<DesktopModule> onSelect;

  static const _items = [
    (DesktopModule.dashboard, 'Dashboard', AmalfiIconName.dashboard),
    (DesktopModule.tables, 'Mesas y Salón', AmalfiIconName.tables),
    (DesktopModule.pos, 'POS / Venta', AmalfiIconName.posCart),
    (DesktopModule.orders, 'Comandas', AmalfiIconName.orders),
    (DesktopModule.inventory, 'Inventario', AmalfiIconName.inventory),
    (DesktopModule.cash, 'Caja', AmalfiIconName.cash),
    (DesktopModule.reports, 'Reportes', AmalfiIconName.reports),
    (DesktopModule.audit, 'Auditoría', AmalfiIconName.audit),
    (DesktopModule.settings, 'Configuración', AmalfiIconName.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final width = compact ? 68.0 : 182.0;
    return Container(
      width: width,
      color: AmalfiTheme.deepBrandFor(context),
      child: Column(
        children: [
          SizedBox(
            height: compact ? 76 : 174,
            child: compact
                ? Center(child: _AmalfiLogoMark(size: 42))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7F2),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AmalfiTheme.brandFor(context),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AmalfiTheme.brandFor(context)
                                  .withValues(alpha: .24),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: _AmalfiLogoMark(size: 82),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'POS NATIVO',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: .6,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        'Sistema de Punto de Ventas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AmalfiTheme.muted,
                          fontSize: 9,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 10),
              children: [
                for (final item in _items.where(
                  (item) => allowedModules.contains(item.$1),
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Tooltip(
                      message: compact ? item.$2 : '',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => onSelect(item.$1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 190),
                          curve: Curves.easeOutCubic,
                          height: 40,
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 11 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected == item.$1
                                ? AmalfiTheme.brandFor(context)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: selected == item.$1
                                ? [
                                    BoxShadow(
                                      color: AmalfiTheme.brandFor(context)
                                          .withValues(alpha: .24),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              AmalfiIcon(
                                name: item.$3,
                                size: 17,
                                color: selected == item.$1
                                    ? Theme.of(context).colorScheme.onPrimary
                                    : Colors.white,
                                semanticLabel: item.$2,
                              ),
                              if (!compact) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.$2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected == item.$1
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                          : Colors.white,
                                      fontSize: 12,
                                      fontWeight: selected == item.$1
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!compact) const _SidebarBrandSignature(),
        ],
      ),
    );
  }
}

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.workspace,
    required this.isDemo,
    required this.compact,
    required this.onLogout,
  });

  final LocalWorkspace workspace;
  final bool isDemo;
  final bool compact;
  final VoidCallback onLogout;

  String _date(DateTime date) {
    const weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final appearance = context.watch<DesktopAppearanceModel>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Column(
      children: [
        Container(
          height: 68,
          color: AmalfiTheme.deepBrandFor(context),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const AmalfiIcon(
                      name: AmalfiIconName.coffee,
                      color: AmalfiTheme.muted,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      flex: 2,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            workspace.organizationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${workspace.branchName} · ${workspace.terminalName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AmalfiTheme.muted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 22),
                      const AmalfiIcon(
                        name: AmalfiIconName.calendar,
                        size: 15,
                        color: AmalfiTheme.muted,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          '${_date(now)}  ·  $time',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AmalfiTheme.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 8 : 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AmalfiIcon(
                          name: isDemo
                              ? AmalfiIconName.coffee
                              : AmalfiIconName.wifi,
                          size: 15,
                          color: isDemo
                              ? AmalfiTheme.brandFor(context)
                              : AmalfiTheme.warning,
                        ),
                        SizedBox(width: 7),
                        Text(
                          compact
                              ? (isDemo ? 'DEMO' : 'Local')
                              : (isDemo ? 'DEMO AISLADA' : 'Modo local'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (!compact)
                    TextButton.icon(
                      onPressed: () => appearance.toggle(systemIsDark: isDark),
                      icon: AmalfiIcon(
                        name: isDark ? AmalfiIconName.sun : AmalfiIconName.moon,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: Text(
                        appearance.themeMode == ThemeMode.system
                            ? 'Tema del sistema'
                            : isDark
                            ? 'Modo claro'
                            : 'Modo oscuro',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    )
                  else
                    const SizedBox.shrink(),
                  PopupMenuButton<ThemeMode>(
                    tooltip: 'Seleccionar tema',
                    icon: AmalfiIcon(
                      name: isDark ? AmalfiIconName.moon : AmalfiIconName.sun,
                      size: 18,
                      color: Colors.white,
                    ),
                    onSelected: appearance.setThemeMode,
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: ThemeMode.system,
                        child: Text('Sistema'),
                      ),
                      PopupMenuItem(
                        value: ThemeMode.light,
                        child: Text('Claro'),
                      ),
                      PopupMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Oscuro'),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 28,
                    child: VerticalDivider(width: 14, color: Colors.white24),
                  ),
                  const SizedBox(width: 6),
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: AmalfiTheme.brandFor(context),
                    child: Text(
                      workspace.profileName.isEmpty
                          ? '?'
                          : workspace.profileName.characters.first
                                .toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: compact ? 80 : 140),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workspace.profileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Operador local',
                          style: TextStyle(
                            color: AmalfiTheme.muted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: isDemo
                        ? 'Salir del entorno demo'
                        : 'Cerrar sesión',
                    onPressed: onLogout,
                    icon: const Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: const BoxDecoration(
            color: AmalfiTheme.navy,
            border: Border(top: BorderSide(color: Color(0xFF374151))),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compactStatus = constraints.maxWidth < 500;
              final successColor = AmalfiTheme.successFor(context);
              return Row(
                children: [
                  Icon(Icons.check_circle, color: successColor, size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Configuración local válida',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: successColor, fontSize: 10),
                    ),
                  ),
                  if (!compactStatus) ...[
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        constraints.maxWidth < 900
                            ? 'CAFFÈ AMALFI · Modo local'
                            : 'CAFFÈ AMALFI  ·  Escritorio  ·  Sin conexión remota',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: AmalfiTheme.muted,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DesktopFooter extends StatelessWidget {
  const _DesktopFooter();

  @override
  Widget build(BuildContext context) => Container(
    height: 30,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    color: AmalfiTheme.navy,
    child: LayoutBuilder(
      builder: (context, constraints) => Row(
        children: [
          const Expanded(
            child: Text(
              'POS Nativo  ·  Caffè Amalfi',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AmalfiTheme.muted, fontSize: 10),
            ),
          ),
          if (constraints.maxWidth >= 500)
            const Text(
              'Operación local · No fiscal',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AmalfiTheme.muted, fontSize: 10),
            ),
        ],
      ),
    ),
  );
}

class _ModuleContent extends StatelessWidget {
  const _ModuleContent({
    required this.module,
    required this.database,
    super.key,
  });

  final DesktopModule module;
  final LocalDatabase database;

  @override
  Widget build(BuildContext context) => switch (module) {
    DesktopModule.dashboard => const DashboardScreen(),
    DesktopModule.tables => const DiningScreen(),
    DesktopModule.pos => const PosScreen(),
    DesktopModule.orders => const ProductionScreen(),
    DesktopModule.inventory => const InventoryScreen(),
    DesktopModule.cash => const CashScreen(),
    DesktopModule.reports => const ReportsScreen(),
    DesktopModule.audit => const AuditScreen(),
    DesktopModule.settings => const SettingsScreen(),
  };
}

class _SidebarBrandSignature extends StatelessWidget {
  const _SidebarBrandSignature();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Café Amalfi',
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Georgia',
              fontSize: 18,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Sabor que inspira...',
            style: const TextStyle(
              color: AmalfiTheme.muted,
              fontFamily: 'Georgia',
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: Container(height: 1.2, color: AmalfiTheme.turquoise),
            ),
            const SizedBox(width: 5),
            Container(width: 9, height: 1.6, color: AmalfiTheme.error),
          ],
        ),
      ],
    ),
  );
}

class _AmalfiLogoMark extends StatelessWidget {
  const _AmalfiLogoMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: Image.asset(
      AmalfiBrandAssets.logo,
      width: size,
      height: size,
      fit: BoxFit.cover,
    ),
  );
}

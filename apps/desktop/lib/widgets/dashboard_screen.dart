import 'package:core_money/core_money.dart';
import 'package:data_local/data_local.dart';
import 'package:amalfi_brand_assets/amalfi_brand_assets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../desktop_state.dart';
import '../theme/amalfi_theme.dart';
import 'amalfi_ui.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    watchDesktopNavigation(context);
    final database = context.read<LocalDatabase>();
    final tables = database.getDiningTables();
    final sales = database.recentSales(limit: 1000);
    final today = DateTime.now();
    final todaySales = sales
        .where((sale) {
          final createdAt = DateTime.tryParse(sale.createdAt)?.toLocal();
          return createdAt != null &&
              createdAt.year == today.year &&
              createdAt.month == today.month &&
              createdAt.day == today.day;
        })
        .toList(growable: false);
    final totalToday = todaySales.fold<BigInt>(
      BigInt.zero,
      (total, sale) => total + BigInt.parse(sale.totalMinor),
    );
    final occupied = tables.where((table) => table.status != 'FREE').length;
    final pending = database.outbox.pending().length;
    final cashOpen = database.activeCashSession != null;
    final viewport = MediaQuery.sizeOf(context);
    final compactViewport = viewport.width < 820 || viewport.height < 680;
    final panels = _DashboardPanels(tables: tables, sales: todaySales);
    final children = <Widget>[
      ScreenHeading(
        title: 'Dashboard',
        subtitle: 'Resumen del sistema',
        trailing: const DashboardBrandHeader(),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          final columns = constraints.maxWidth >= 1100
              ? 4
              : constraints.maxWidth >= 680
              ? 2
              : 1;
          final width =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              SizedBox(
                width: width,
                child: SummaryCard(
                  label: 'Mesas ocupadas',
                  value: '$occupied/${tables.length}',
                  icon: AmalfiIconName.tables,
                ),
              ),
              SizedBox(
                width: width,
                child: SummaryCard(
                  label: 'Ventas del día',
                  value: Money(
                    minorUnits: totalToday,
                    currency: Currency.usd,
                  ).format(),
                  icon: AmalfiIconName.currency,
                  valueColor: AmalfiTheme.brandFor(context),
                ),
              ),
              SizedBox(
                width: width,
                child: SummaryCard(
                  label: 'Comprobantes locales',
                  value: '${sales.length}',
                  icon: AmalfiIconName.receipt,
                ),
              ),
              SizedBox(
                width: width,
                child: SummaryCard(
                  label: 'Estado de caja',
                  value: cashOpen ? 'Abierta' : 'Cerrada',
                  icon: AmalfiIconName.cash,
                  valueColor: cashOpen
                      ? AmalfiTheme.successFor(context)
                      : AmalfiTheme.errorFor(context),
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 14),
      if (compactViewport)
        SizedBox(height: 420, child: panels)
      else
        Expanded(child: panels),
      const SizedBox(height: 8),
      Text(
        '$pending operaciones locales pendientes · los datos no se han sincronizado',
        style: AmalfiTheme.mutedText(context, fontSize: 10),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: compactViewport
          ? SingleChildScrollView(
              primary: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
    );
  }
}

class _DashboardPanels extends StatelessWidget {
  const _DashboardPanels({required this.tables, required this.sales});

  final List<LocalDiningTable> tables;
  final List<LocalSaleSummary> sales;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 620) {
        return Column(
          children: [
            Expanded(child: _RecentTables(tables: tables)),
            const SizedBox(height: 12),
            Expanded(child: _RecentSales(sales: sales)),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: _RecentTables(tables: tables)),
          const SizedBox(width: 12),
          Expanded(child: _RecentSales(sales: sales)),
        ],
      );
    },
  );
}

class DashboardBrandHeader extends StatelessWidget {
  const DashboardBrandHeader({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth.clamp(0.0, 500.0).toDouble()
          : 500.0;
      final theme = Theme.of(context);
      return SizedBox(
        width: width,
        height: 86,
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'CAFÉ AMALFI',
                style: TextStyle(
                  color: AmalfiTheme.brandFor(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  'Gestiona, vende y disfruta',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontFamily: 'Georgia',
                    fontSize: 22,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1.5,
                      color: AmalfiTheme.brandFor(context),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Container(
                    width: 13,
                    height: 2,
                    color: AmalfiTheme.errorFor(context),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Una experiencia de gestión con identidad propia.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AmalfiTheme.mutedText(context, fontSize: 9),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _RecentTables extends StatelessWidget {
  const _RecentTables({required this.tables});

  final List<LocalDiningTable> tables;

  @override
  Widget build(BuildContext context) => AmalfiPanel(
    title: 'Mesas recientes',
    child: tables.isEmpty
        ? const DashboardEmptyState(
            icon: AmalfiIconName.tables,
            title: 'No hay mesas configuradas',
            description: 'Las mesas disponibles aparecerán aquí cuando estén registradas.',
          )
        : ListView(
            children: [
              for (final table in tables.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          table.name,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      StatusBadge(
                        label: switch (table.status) {
                          'OCCUPIED' => 'OCUPADA',
                          'PREBILL' => 'PRECUENTA',
                          _ => 'LIBRE',
                        },
                        color: switch (table.status) {
                          'OCCUPIED' => AmalfiTheme.warning,
                          'PREBILL' => AmalfiTheme.brandFor(context),
                          _ => AmalfiTheme.mutedFor(context),
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
  );
}

class _RecentSales extends StatelessWidget {
  const _RecentSales({required this.sales});

  final List<LocalSaleSummary> sales;

  @override
  Widget build(BuildContext context) => AmalfiPanel(
    title: 'Últimos comprobantes locales',
    child: sales.isEmpty
        ? const DashboardEmptyState(
            icon: AmalfiIconName.receipt,
            title: 'Todavía no hay comprobantes',
            description:
                'Los comprobantes generados aparecerán en este espacio.',
          )
        : ListView.separated(
            itemCount: sales.length > 8 ? 8 : sales.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final sale = sales[index];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  sale.saleNumber,
                  style: const TextStyle(fontSize: 11),
                ),
                subtitle: Text(
                  '${sale.createdAt} · ${sale.syncStatus}',
                  style: const TextStyle(fontSize: 9),
                ),
                trailing: Text(
                  Money(
                    minorUnits: BigInt.parse(sale.totalMinor),
                    currency: sale.totalCurrency == 'VES'
                        ? Currency.ves
                        : Currency.usd,
                  ).format(),
                  style: const TextStyle(fontSize: 11),
                ),
              );
            },
          ),
  );
}

class DashboardEmptyState extends StatelessWidget {
  const DashboardEmptyState({
    required this.icon,
    required this.title,
    required this.description,
    super.key,
  });

  final AmalfiIconName icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 160;
      final iconSize = compact ? 34.0 : 54.0;
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 20,
            vertical: compact ? 3 : 20,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: AmalfiTheme.brandFor(context).withValues(alpha: .10),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: AmalfiIcon(
                    name: icon,
                    size: compact ? 19 : 25,
                    color: AmalfiTheme.brandFor(context),
                  ),
                ),
                SizedBox(height: compact ? 6 : 13),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: compact ? 12 : null,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: compact ? 3 : 5),
                Text(
                  description,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AmalfiTheme.mutedText(
                    context,
                    fontSize: compact ? 10 : 11,
                  ).copyWith(height: 1.2),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

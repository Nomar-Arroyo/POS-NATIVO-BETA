import 'package:core_money/core_money.dart';
import 'package:data_local/data_local.dart';
import 'package:amalfi_brand_assets/amalfi_brand_assets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../desktop_state.dart';
import '../services/local_print_service.dart';
import '../theme/amalfi_theme.dart';
import 'amalfi_ui.dart';

class ProductionScreen extends StatefulWidget {
  const ProductionScreen({super.key});

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> {
  final _printer = const LocalPrintService();
  String _station = 'ALL';
  String _statusFilter = 'ACTIVE';

  static const _activeStatuses = {'PENDING', 'PREPARING', 'READY'};

  void _reportError(String action, Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$action: $error'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _printOrder(LocalProductionOrder order) async {
    try {
      final printed = await _printer.printProductionOrder(order);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            printed
                ? 'Comanda enviada a impresión'
                : 'No se confirmó la impresión',
          ),
        ),
      );
    } catch (error) {
      if (mounted) _reportError('No se pudo imprimir la comanda', error);
    }
  }

  @override
  Widget build(BuildContext context) {
    watchDesktopNavigation(context);
    final compactHeight = MediaQuery.sizeOf(context).height < 700;
    final database = context.read<LocalDatabase>();
    final allOrders = database.getProductionOrders();
    final stationOrders = _station == 'ALL'
        ? allOrders
        : allOrders.where((order) => order.station == _station).toList();
    final orders = stationOrders
        .where(
          (order) =>
              _statusFilter != 'ACTIVE' ||
              _activeStatuses.contains(order.status),
        )
        .toList(growable: false);
    final kitchenCount = allOrders
        .where((order) => order.station == 'KITCHEN')
        .length;
    final barCount = allOrders.where((order) => order.station == 'BAR').length;
    final pendingCount = allOrders
        .where((order) => order.status == 'PENDING')
        .length;
    final preparingCount = allOrders
        .where((order) => order.status == 'PREPARING')
        .length;
    final deliveredCount = allOrders
        .where((order) => order.status == 'DELIVERED')
        .length;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(
            title: 'Comandas',
            subtitle: 'Gestiona todas las órdenes del sistema',
            trailing: DropdownButton<String>(
              value: _statusFilter,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                  value: 'ACTIVE',
                  child: Text('Órdenes activas'),
                ),
                DropdownMenuItem(
                  value: 'ALL',
                  child: Text('Historial completo'),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _statusFilter = value ?? 'ACTIVE'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StationTab(
                label: 'General',
                selected: _station == 'ALL',
                count: allOrders.length,
                onTap: () => setState(() => _station = 'ALL'),
              ),
              _StationTab(
                label: 'Cocina',
                selected: _station == 'KITCHEN',
                count: kitchenCount,
                onTap: () => setState(() => _station = 'KITCHEN'),
              ),
              _StationTab(
                label: 'Barra',
                selected: _station == 'BAR',
                count: barCount,
                onTap: () => setState(() => _station = 'BAR'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  label: 'Total órdenes',
                  value: '${stationOrders.length}',
                  icon: AmalfiIconName.orders,
                  valueColor: AmalfiTheme.brandFor(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryCard(
                  label: 'Pendientes',
                  value: '$pendingCount',
                  icon: AmalfiIconName.bell,
                  valueColor: AmalfiTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryCard(
                  label: 'En preparación',
                  value: '$preparingCount',
                  icon: AmalfiIconName.coffee,
                  valueColor: AmalfiTheme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryCard(
                  label: 'Entregadas',
                  value: '$deliveredCount',
                  icon: AmalfiIconName.check,
                  valueColor: AmalfiTheme.successFor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!compactHeight) ...[
            SizedBox(
              height: 136,
              child: AmalfiPanel(
                title: 'Rendimiento de Cocina',
                child: Row(
                  children: [
                    Expanded(
                      child: _PerformanceMetric(
                        icon: Icons.schedule,
                        value: '—',
                        label: 'Tiempo promedio',
                      ),
                    ),
                    Expanded(
                      child: _PerformanceMetric(
                        icon: Icons.soup_kitchen_outlined,
                        value: '$kitchenCount',
                        label: 'Órdenes Cocina',
                      ),
                    ),
                    Expanded(
                      child: _PerformanceMetric(
                        icon: Icons.local_bar_outlined,
                        value: '$barCount',
                        label: 'Órdenes Barra',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Expanded(
            child: AmalfiPanel(
              title: 'Órdenes Recientes',
              child: orders.isEmpty
                  ? Center(
                      child: Text(
                        _statusFilter == 'ACTIVE'
                            ? 'No hay comandas activas en ${_station == 'BAR'
                                  ? 'barra'
                                  : _station == 'KITCHEN'
                                  ? 'cocina'
                                  : 'el sistema'}.'
                            : 'No hay comandas en el historial.',
                        style: AmalfiTheme.mutedText(context, fontSize: 11),
                      ),
                    )
                  : ListView.separated(
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        return _OrderCard(
                          order: order,
                          onPrint: () => _printOrder(order),
                          onAdvance: () {
                            final nextStatus = switch (order.status) {
                              'PENDING' => 'PREPARING',
                              'PREPARING' => 'READY',
                              'READY' => 'DELIVERED',
                              _ => null,
                            };
                            if (nextStatus == null) return;
                            try {
                              database.transitionProductionOrder(
                                orderId: order.id,
                                nextStatus: nextStatus,
                              );
                              setState(() {});
                            } catch (error) {
                              _reportError(
                                'No se pudo actualizar la comanda',
                                error,
                              );
                            }
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onPrint,
    required this.onAdvance,
  });

  final LocalProductionOrder order;
  final VoidCallback onPrint;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final nextAction = switch (order.status) {
      'PENDING' => 'Iniciar preparación',
      'PREPARING' => 'Marcar listo',
      'READY' => 'Marcar entregado',
      _ => null,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${order.orderNumber} · ${order.tableName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(_localizedStatus(order.status))),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Imprimir comanda',
                  onPressed: onPrint,
                  icon: const Icon(Icons.print_outlined),
                ),
                if (nextAction != null)
                  FilledButton(onPressed: onAdvance, child: Text(nextAction)),
              ],
            ),
            Text('Creada ${order.createdAt}'),
            const Divider(),
            for (final item in order.items)
              ListTile(
                dense: true,
                leading: Text(item.quantity),
                title: Text(item.productName),
                subtitle: item.notes == null || item.notes!.isEmpty
                    ? null
                    : Text(item.notes!),
                trailing: Text(
                  Money(
                    minorUnits: BigInt.parse(item.subtotalMinor),
                    currency: Currency.usd,
                  ).format(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _localizedStatus(String status) => switch (status) {
    'PENDING' => 'Pendiente',
    'PREPARING' => 'En preparación',
    'READY' => 'Listo',
    'DELIVERED' => 'Entregado',
    _ => status,
  };
}

class _StationTab extends StatelessWidget {
  const _StationTab({
    required this.label,
    required this.selected,
    required this.count,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Container(
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AmalfiTheme.brandFor(context)
              : AmalfiTheme.panelFor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AmalfiTheme.outlineFor(context)),
        ),
        child: Text(
          '$label   $count',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}

class _PerformanceMetric extends StatelessWidget {
  const _PerformanceMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: 18, color: AmalfiTheme.brandFor(context)),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      ),
      Text(label, style: AmalfiTheme.mutedText(context, fontSize: 9)),
    ],
  );
}

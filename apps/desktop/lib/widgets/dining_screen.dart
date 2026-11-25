import 'package:core_money/core_money.dart';
import 'package:data_local/data_local.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../desktop_state.dart';
import '../services/local_print_service.dart';
import '../theme/amalfi_theme.dart';
import 'amalfi_ui.dart';
import 'payment_allocation_dialog.dart';

class DiningScreen extends StatefulWidget {
  const DiningScreen({super.key});

  @override
  State<DiningScreen> createState() => _DiningScreenState();
}

class _DiningScreenState extends State<DiningScreen> {
  final _printer = const LocalPrintService();
  String? _selectedTableId;
  bool _busy = false;
  String _tableSearch = '';
  String _tableFilter = 'Todas las mesas';

  void _refresh() {
    final tables = context.read<LocalDatabase>().getDiningTables();
    if (_selectedTableId != null &&
        !tables.any((table) => table.id == _selectedTableId)) {
      _selectedTableId = null;
    }
  }

  Future<void> _addTable() async {
    final input = await showDialog<({String name, int capacity})>(
      context: context,
      builder: (context) => const _DiningTableDialog(),
    );
    if (input == null || !mounted) return;
    try {
      final table = context.read<LocalDatabase>().createDiningTable(
        name: input.name,
        capacity: input.capacity,
      );
      setState(() {
        _refresh();
        _selectedTableId = table.id;
      });
    } catch (error) {
      _notify('No se pudo crear la mesa: $error', isError: true);
    }
  }

  void _openTable(LocalDiningTable table) {
    try {
      final session = context.read<LocalDatabase>().openDiningSession(table.id);
      setState(() => _selectedTableId = table.id);
      _notify('Cuenta local abierta para ${session.tableName}');
    } catch (error) {
      _notify('No se pudo abrir la mesa: $error', isError: true);
    }
  }

  Future<void> _addItem(
    LocalDiningSession session,
    LocalCatalogProduct product,
  ) async {
    final input = await showDialog<({String quantity, String? notes})>(
      context: context,
      builder: (context) => _DiningItemDialog(product: product),
    );
    if (input == null || !mounted) return;
    try {
      context.read<LocalDatabase>().addDiningItem(
        sessionId: session.id,
        variantId: product.variantId,
        quantity: input.quantity,
        notes: input.notes,
      );
      setState(_refresh);
    } catch (error) {
      _notify('No se pudo agregar el producto: $error', isError: true);
    }
  }

  void _removeItem(LocalDiningItem item) {
    try {
      context.read<LocalDatabase>().removeUnsentDiningItem(item.id);
      setState(_refresh);
    } catch (error) {
      _notify('No se pudo quitar el producto: $error', isError: true);
    }
  }

  Future<void> _sendOrders(LocalDiningSession session) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final database = context.read<LocalDatabase>();
      final orders = database.sendDiningOrders(session.id);
      final printResult = await printOrdersWithoutStationDisplays(
        database: database,
        orders: orders,
        printOrder: _printer.printProductionOrder,
      );
      if (!mounted) return;
      setState(_refresh);
      if (printResult.hasIssues) {
        _notify(
          'Comandas guardadas; impresión pendiente. '
          '${printResult.failures.join(' | ')}'
          '${printResult.cancelledCount > 0 ? ' ${printResult.cancelledCount} diálogo(s) cancelado(s).' : ''}',
          isError: true,
        );
      } else {
        _notify('${orders.length} comanda(s) enviada(s) a cocina/barra local');
      }
    } catch (error) {
      _notify('No se pudo enviar la comanda: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generatePrecuenta(LocalDiningSession session) async {
    try {
      final precuenta = context.read<LocalDatabase>().generateLocalPrecuenta(
        session.id,
      );
      setState(_refresh);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Precuenta · ${precuenta.tableName}'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Documento no fiscal · ${precuenta.generatedAt}'),
                const Divider(),
                SizedBox(
                  height: 320,
                  child: ListView(
                    children: [
                      for (final item in precuenta.items)
                        ListTile(
                          dense: true,
                          title: Text('${item.quantity} × ${item.productName}'),
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
                const Divider(),
                ListTile(
                  title: const Text('TOTAL USD'),
                  trailing: Text(
                    Money(
                      minorUnits: BigInt.parse(precuenta.totalUsdMinor),
                      currency: Currency.usd,
                    ).format(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final printed = await _printer.printPrecuenta(precuenta);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      printed
                          ? 'Precuenta enviada a impresión'
                          : 'No se confirmó la impresión',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('Imprimir'),
            ),
          ],
        ),
      );
    } catch (error) {
      _notify('No se pudo generar la precuenta: $error', isError: true);
    }
  }

  Future<void> _checkout(LocalDiningSession session) async {
    final database = context.read<LocalDatabase>();
    final cashSession = database.activeCashSession;
    if (cashSession == null) {
      _notify('Abre la caja antes de cobrar la mesa', isError: true);
      return;
    }
    final total = BigInt.parse(session.totalUsdMinor);
    if (total <= BigInt.zero) {
      _notify('La cuenta no tiene productos por cobrar', isError: true);
      return;
    }
    final payments = await showPaymentAllocation(context, totalMinor: total);
    if (payments == null || !mounted) return;
    final workspace = database.localWorkspace!;
    final reservations = <String, BigInt>{};
    for (final item in session.activeItems) {
      final quantity = BigInt.parse(item.quantity);
      reservations.update(
        item.variantId,
        (value) => value + quantity,
        ifAbsent: () => quantity,
      );
    }
    final saleId = const Uuid().v4();
    final saleNumber = 'M-${DateTime.now().toUtc().millisecondsSinceEpoch}';
    setState(() => _busy = true);
    try {
      database.confirmSale(
        LocalSaleInput(
          id: saleId,
          organizationId: workspace.organizationId,
          branchId: workspace.branchId,
          terminalId: workspace.terminalId,
          profileId: workspace.profileId,
          cashSessionId: cashSession.id,
          diningSessionId: session.id,
          idempotencyKey: saleId,
          saleNumber: saleNumber,
          totalCurrency: 'USD',
          totalMinor: total.toString(),
          items: [
            for (final item in session.activeItems)
              LocalSaleItemInput(
                variantId: item.variantId,
                quantity: item.quantity,
                unitPriceMinor: item.unitPriceMinor,
                subtotalMinor: item.subtotalMinor,
              ),
          ],
          payments: payments,
          inventoryConsumptions: [
            for (final entry in reservations.entries)
              LocalInventoryConsumption(
                warehouseId: workspace.warehouseId,
                variantId: entry.key,
                quantity: entry.value.toString(),
                reservedQuantity: entry.value.toString(),
              ),
          ],
        ),
      );
      if (!mounted) return;
      setState(() {
        _selectedTableId = session.tableId;
        _refresh();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Mesa cobrada localmente · venta pendiente de sincronización',
          ),
          action: SnackBarAction(
            label: 'Imprimir',
            onPressed: () => _printTableReceipt(
              saleNumber,
              session.activeItems,
              payments,
              total,
            ),
          ),
        ),
      );
    } catch (error) {
      _notify('No se pudo cobrar la mesa: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _closeEmpty(LocalDiningSession session) {
    try {
      context.read<LocalDatabase>().closeEmptyDiningSession(session.id);
      setState(_refresh);
      _notify('Mesa liberada localmente');
    } catch (error) {
      _notify('No se pudo liberar la mesa: $error', isError: true);
    }
  }

  Future<void> _printTableReceipt(
    String saleNumber,
    List<LocalDiningItem> items,
    List<LocalPaymentInput> payments,
    BigInt totalMinor,
  ) async {
    try {
      final printed = await _printer.printSaleReceipt(
        saleNumber: saleNumber,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        items: items,
        totalUsdMinor: totalMinor.toString(),
        payments: payments,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              printed
                  ? 'Comprobante enviado a impresión'
                  : 'No se confirmó la impresión',
            ),
          ),
        );
      }
    } catch (error) {
      _notify('Error al imprimir el comprobante: $error', isError: true);
    }
  }

  void _notify(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    watchDesktopNavigation(context);
    final database = context.read<LocalDatabase>();
    final tables = database.getDiningTables();
    final freeCount = tables.where((table) => table.status == 'FREE').length;
    final occupiedCount = tables.length - freeCount;
    LocalDiningTable? selectedTable;
    for (final table in tables) {
      if (table.id == _selectedTableId) selectedTable = table;
    }
    final session = selectedTable?.openSessionId == null
        ? null
        : database.getDiningSession(selectedTable!.openSessionId!);
    final visibleTables = tables
        .where((table) {
          final matchesSearch = table.name.toLowerCase().contains(
            _tableSearch.toLowerCase(),
          );
          final matchesFilter = switch (_tableFilter) {
            'Libres' => table.status == 'FREE',
            'Ocupadas' => table.status == 'OCCUPIED',
            'Precuenta' => table.status == 'PREBILL',
            _ => true,
          };
          return matchesSearch && matchesFilter;
        })
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(
            title: 'Salón y Mesas',
            subtitle: 'Gestiona el estado de todas las mesas',
            trailing: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 6,
              children: [
                StatusBadge(
                  label: '$freeCount Libres',
                  color: AmalfiTheme.successFor(context),
                ),
                StatusBadge(
                  label: '$occupiedCount Ocupadas',
                  color: AmalfiTheme.warning,
                ),
                StatusBadge(
                  label:
                      '${tables.isEmpty ? '0.0' : (occupiedCount * 100 / tables.length).toStringAsFixed(1)}% ocupación',
                  color: AmalfiTheme.mutedFor(context),
                ),
                if (session != null)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _selectedTableId = null),
                    icon: const Icon(Icons.arrow_back, size: 15),
                    label: const Text('Todas las mesas'),
                  ),
                FilledButton.icon(
                  onPressed: _addTable,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar mesa'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: session != null && selectedTable != null
                ? _sessionPanel(database, selectedTable, session)
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText:
                                    'Busca por nombre o número de mesa...',
                                prefixIcon: Icon(Icons.search, size: 18),
                              ),
                              onChanged: (value) =>
                                  setState(() => _tableSearch = value.trim()),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 210,
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _tableFilter,
                              decoration: const InputDecoration(),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Todas las mesas',
                                  child: Text(
                                    'Todas las mesas',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Libres',
                                  child: Text('Libres'),
                                ),
                                DropdownMenuItem(
                                  value: 'Ocupadas',
                                  child: Text('Ocupadas'),
                                ),
                                DropdownMenuItem(
                                  value: 'Precuenta',
                                  child: Text('Precuenta'),
                                ),
                              ],
                              onChanged: (value) => setState(
                                () => _tableFilter = value ?? 'Todas las mesas',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: tables.isEmpty
                            ? const _EmptyTables()
                            : visibleTables.isEmpty
                            ? Center(
                                child: Text(
                                  'No hay mesas que coincidan.',
                                  style: AmalfiTheme.mutedText(context),
                                ),
                              )
                            : GridView.builder(
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 165,
                                      mainAxisExtent: 102,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                    ),
                                itemCount: visibleTables.length,
                                itemBuilder: (context, index) {
                                  final table = visibleTables[index];
                                  final isFree = table.status == 'FREE';
                                  final color = switch (table.status) {
                                    'PREBILL' => AmalfiTheme.brandFor(context),
                                    'OCCUPIED' => AmalfiTheme.warning,
                                    _ => const Color(0xFF64748B),
                                  };
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
                                      if (table.openSessionId == null) {
                                        _openTable(table);
                                      } else {
                                        setState(
                                          () => _selectedTableId = table.id,
                                        );
                                      }
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AmalfiTheme.panelFor(context),
                                        border: Border.all(
                                          color: color.withValues(alpha: .8),
                                          width: 1.2,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.all(9),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            table.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Capacidad: ${table.capacity} personas',
                                            style: AmalfiTheme.mutedText(
                                              context,
                                              fontSize: 9,
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          StatusBadge(
                                            label: _tableStatus(table.status)
                                                .toUpperCase(),
                                            color: color,
                                          ),
                                          if (isFree)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 3,
                                              ),
                                              child: Text(
                                                'Clic para abrir',
                                                style: AmalfiTheme.mutedText(
                                                  context,
                                                  fontSize: 8,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 66,
                        child: AmalfiPanel(
                          title: 'Leyenda',
                          padding: const EdgeInsets.all(10),
                          child: Wrap(
                            spacing: 22,
                            runSpacing: 8,
                            children: [
                              _LegendItem(
                                color: Color(0xFF64748B),
                                label: 'Mesa libre',
                              ),
                              _LegendItem(
                                color: AmalfiTheme.warning,
                                label: 'Mesa ocupada',
                              ),
                              _LegendItem(
                                color: AmalfiTheme.brandFor(context),
                                label: 'Precuenta emitida',
                              ),
                              _LegendItem(
                                color: AmalfiTheme.muted,
                                label: 'Clic para abrir mesa',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sessionPanel(
    LocalDatabase database,
    LocalDiningTable table,
    LocalDiningSession session,
  ) {
    final products = database
        .getCatalogProducts()
        .where((product) {
          final stock =
              BigInt.tryParse(product.availableQuantity ?? '') ?? BigInt.zero;
          return (database.isDemoMode || !product.isSynthetic) &&
              stock > BigInt.zero &&
              (product.fulfillmentStation == 'KITCHEN' ||
                  product.fulfillmentStation == 'BAR');
        })
        .toList(growable: false);
    final items = session.activeItems;
    final total = BigInt.parse(session.totalUsdMinor);
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
                    '${table.name} · ${table.capacity} puestos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(_tableStatus(table.status))),
                const SizedBox(width: 8),
                Text('Abierta ${session.openedAt}'),
              ],
            ),
            const Divider(),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: products.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay productos con estación asignada, stock conocido y venta offline habilitada.',
                            ),
                          )
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 220,
                                  mainAxisExtent: 104,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              return OutlinedButton(
                                onPressed: () => _addItem(session, product),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${Money(minorUnits: BigInt.parse(product.priceMinor), currency: Currency.usd).format()} · ${product.fulfillmentStation == 'KITCHEN' ? 'Cocina' : 'Barra'}',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const VerticalDivider(width: 20),
                  SizedBox(
                    width: 370,
                    child: Column(
                      children: [
                        Expanded(
                          child: items.isEmpty
                              ? const Center(child: Text('Cuenta vacía'))
                              : ListView(
                                  children: [
                                    for (final item in items)
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          '${item.quantity} × ${item.productName}',
                                        ),
                                        subtitle: Text(
                                          '${item.station == 'KITCHEN' ? 'Cocina' : 'Barra'} · ${item.status}${item.notes == null || item.notes!.isEmpty ? '' : ' · ${item.notes}'}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              Money(
                                                minorUnits: BigInt.parse(
                                                  item.subtotalMinor,
                                                ),
                                                currency: Currency.usd,
                                              ).format(),
                                            ),
                                            if (item.status == 'UNSENT')
                                              IconButton(
                                                tooltip: 'Quitar artículo',
                                                onPressed: () =>
                                                    _removeItem(item),
                                                icon: const Icon(
                                                  Icons.remove_circle_outline,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        const Divider(),
                        Row(
                          children: [
                            const Expanded(child: Text('Total sin impuestos')),
                            Text(
                              Money(
                                minorUnits: total,
                                currency: Currency.usd,
                              ).format(),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy || items.isEmpty
                                  ? null
                                  : () => _sendOrders(session),
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Enviar comanda'),
                            ),
                            OutlinedButton.icon(
                              onPressed: items.isEmpty
                                  ? null
                                  : () => _generatePrecuenta(session),
                              icon: const Icon(Icons.receipt_long_outlined),
                              label: const Text('Precuenta'),
                            ),
                            if (items.isEmpty)
                              FilledButton(
                                onPressed: () => _closeEmpty(session),
                                child: const Text('Liberar mesa vacía'),
                              )
                            else
                              FilledButton.icon(
                                onPressed: _busy
                                    ? null
                                    : () => _checkout(session),
                                icon: const Icon(Icons.payments_outlined),
                                label: const Text('Cobrar y cerrar'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Pagos en USD; sin conversión ni impuestos. La precuenta no es factura fiscal.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tableStatus(String status) => switch (status) {
    'FREE' => 'Libre',
    'PREBILL' => 'Precuenta emitida',
    _ => 'Ocupada',
  };
}

class _DiningTableDialog extends StatefulWidget {
  const _DiningTableDialog();

  @override
  State<_DiningTableDialog> createState() => _DiningTableDialogState();
}

class _DiningTableDialogState extends State<_DiningTableDialog> {
  final _name = TextEditingController();
  final _capacity = TextEditingController(text: '2');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _capacity.dispose();
    super.dispose();
  }

  void _submit() {
    final capacity = int.tryParse(_capacity.text.trim());
    if (_name.text.trim().isEmpty || capacity == null || capacity <= 0) {
      setState(() => _error = 'Indica nombre y capacidad válida');
      return;
    }
    Navigator.pop(context, (name: _name.text.trim(), capacity: capacity));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Agregar mesa'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre o número'),
          ),
          TextField(
            controller: _capacity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Capacidad'),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Guardar')),
    ],
  );
}

class _DiningItemDialog extends StatefulWidget {
  const _DiningItemDialog({required this.product});

  final LocalCatalogProduct product;

  @override
  State<_DiningItemDialog> createState() => _DiningItemDialogState();
}

class _DiningItemDialogState extends State<_DiningItemDialog> {
  final _quantity = TextEditingController(text: '1');
  final _notes = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = BigInt.tryParse(_quantity.text.trim());
    if (quantity == null || quantity <= BigInt.zero) {
      setState(() => _error = 'La cantidad debe ser un entero positivo');
      return;
    }
    Navigator.pop(context, (
      quantity: quantity.toString(),
      notes: _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.product.name),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Disponible: ${widget.product.availableQuantity ?? 'desconocido'}',
          ),
          TextField(
            controller: _quantity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad'),
          ),
          TextField(
            controller: _notes,
            decoration: const InputDecoration(
              labelText: 'Notas para cocina/barra',
            ),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Agregar')),
    ],
  );
}

class _EmptyTables extends StatelessWidget {
  const _EmptyTables();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;
    return AmalfiPanel(
      title: 'Todas las Mesas',
      child: Center(
        child: compact
            ? const Text('Aún no hay mesas configuradas')
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.table_restaurant_outlined,
                    color: AmalfiTheme.mutedFor(context),
                    size: 34,
                  ),
                  const SizedBox(height: 8),
                  const Text('Aún no hay mesas configuradas'),
                  const SizedBox(height: 4),
                  Text(
                    'Agrega las mesas reales del establecimiento.',
                    style: AmalfiTheme.mutedText(context, fontSize: 10),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 9, color: color),
      const SizedBox(width: 6),
      Text(label, style: AmalfiTheme.mutedText(context, fontSize: 9)),
    ],
  );
}

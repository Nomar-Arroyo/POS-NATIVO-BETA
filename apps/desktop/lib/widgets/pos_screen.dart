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

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final _printer = const LocalPrintService();
  final Map<String, int> _cart = {};
  bool _saving = false;
  String _search = '';
  String _category = 'Todas';

  @override
  Widget build(BuildContext context) {
    watchDesktopNavigation(context);
    final database = context.read<LocalDatabase>();
    final products = database.getCatalogProducts();
    final session = database.activeCashSession;
    final workspace = database.localWorkspace!;
    final categories = {
      for (final product in products) product.categoryName,
    }.toList()..sort();
    categories.insert(0, 'Todas');
    final visibleProducts = products
        .where((product) {
          final matchesSearch =
              _search.isEmpty ||
              product.name.toLowerCase().contains(_search.toLowerCase()) ||
              (product.sku?.toLowerCase().contains(_search.toLowerCase()) ??
                  false);
          return matchesSearch &&
              (_category == 'Todas' || product.categoryName == _category);
        })
        .toList(growable: false);
    final productByVariant = {
      for (final product in products) product.variantId: product,
    };
    var totalMinor = BigInt.zero;
    for (final entry in _cart.entries) {
      final product = productByVariant[entry.key];
      if (product != null) {
        totalMinor +=
            BigInt.parse(product.priceMinor) * BigInt.from(entry.value);
      }
    }
    final hasSyntheticCart =
        !database.isDemoMode &&
        _cart.keys.any((id) => productByVariant[id]?.isSynthetic ?? false);
    final cartQuantity = _cart.values.fold<int>(
      0,
      (sum, quantity) => sum + quantity,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(
            title: 'POS - Venta Directa',
            subtitle: 'Realice ventas rápidas sin necesidad de mesa',
            trailing: Wrap(
              spacing: 6,
              children: [
                StatusBadge(
                  label: '$cartQuantity artículos',
                  color: AmalfiTheme.brandFor(context),
                ),
                StatusBadge(
                  label: Money(
                    minorUnits: totalMinor,
                    currency: Currency.usd,
                  ).format(),
                  color: AmalfiTheme.warning,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      SizedBox(
                        height: MediaQuery.sizeOf(context).width < 760
                            ? 116
                            : 96,
                        child: AmalfiPanel(
                          title: 'Buscador de Productos',
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  decoration: const InputDecoration(
                                    hintText: 'Buscar producto por nombre...',
                                    prefixIcon: Icon(Icons.search, size: 18),
                                  ),
                                  onChanged: (value) =>
                                      setState(() => _search = value.trim()),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 190,
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: _category,
                                  decoration: const InputDecoration(
                                    labelText: 'Categoría',
                                  ),
                                  items: [
                                    for (final category in categories)
                                      DropdownMenuItem(
                                        value: category,
                                        child: Text(category),
                                      ),
                                  ],
                                  onChanged: (value) => setState(
                                    () => _category = value ?? 'Todas',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: AmalfiPanel(
                          title: 'Catálogo de Productos',
                          trailing: Text(
                            '${visibleProducts.length} artículos',
                            style: AmalfiTheme.mutedText(context, fontSize: 10),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: visibleProducts.isEmpty
                              ? Center(
                                  child: Text(
                                    products.isEmpty
                                        ? 'No hay productos disponibles para venta offline.'
                                        : 'No se encontraron productos.',
                                    style: AmalfiTheme.mutedText(context),
                                  ),
                                )
                              : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 180,
                                        mainAxisExtent: 96,
                                        crossAxisSpacing: 8,
                                        mainAxisSpacing: 8,
                                      ),
                                  itemCount: visibleProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = visibleProducts[index];
                                    final quantity =
                                        _cart[product.variantId] ?? 0;
                                    final available =
                                        int.tryParse(
                                          product.availableQuantity ?? '',
                                        ) ??
                                        0;
                                    final canAdd =
                                        available > quantity && session != null;
                                    return Card(
                                      color: AmalfiTheme.panelFor(context),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: !canAdd
                                            ? null
                                            : () => setState(() {
                                                _cart.update(
                                                  product.variantId,
                                                  (value) => value + 1,
                                                  ifAbsent: () => 1,
                                                );
                                              }),
                                        child: Padding(
                                          padding: const EdgeInsets.all(9),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              Expanded(
                                                child: Center(
                                                  child: Text(
                                                    product.name,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                Money(
                                                  minorUnits: BigInt.parse(
                                                    product.priceMinor,
                                                  ),
                                                  currency: Currency.usd,
                                                ).format(),
                                                style: TextStyle(
                                                  color: AmalfiTheme.brandFor(
                                                    context,
                                                  ),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Flexible(
                                                    child: _MiniTag(
                                                      product.categoryName,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  _MiniTag(
                                                    product.fulfillmentStation ==
                                                            'KITCHEN'
                                                        ? 'COCINA'
                                                        : 'BARRA',
                                                    accent: true,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                product.isSynthetic &&
                                                        !database.isDemoMode
                                                    ? 'DEMO · No cobrable'
                                                    : 'Stock: $available',
                                                style: TextStyle(
                                                  color:
                                                      product.isSynthetic &&
                                                          !database.isDemoMode
                                                      ? AmalfiTheme.warning
                                                      : AmalfiTheme.successFor(
                                                          context,
                                                        ),
                                                  fontSize: 9,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 320,
                  child: AmalfiPanel(
                    title: 'Ticket de Venta',
                    trailing: StatusBadge(
                      label: '$cartQuantity artículos',
                      color: AmalfiTheme.brandFor(context),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        if (session == null)
                          StatusBadge(
                            label: 'Caja cerrada · Abre un turno para vender',
                            color: AmalfiTheme.errorFor(context),
                          ),
                        if (hasSyntheticCart)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'El catálogo demo es solo visual: no permite registrar ventas.',
                              style: TextStyle(
                                color: AmalfiTheme.warning,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        Expanded(
                          child: _cart.isEmpty
                              ? Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.receipt_long_outlined,
                                        color: AmalfiTheme.mutedFor(context),
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Sin artículos. Busca y agrega productos para comenzar.',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: AmalfiTheme.mutedText(
                                            context,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView(
                                  children: [
                                    for (final entry in _cart.entries)
                                      if (productByVariant[entry.key]
                                          case final product?)
                                        ListTile(
                                          dense: true,
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                          subtitle: Text(
                                            '${entry.value} × ${Money(minorUnits: BigInt.parse(product.priceMinor), currency: Currency.usd).format()}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                          trailing: IconButton(
                                            tooltip: 'Quitar una unidad',
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () => setState(() {
                                              if (entry.value <= 1) {
                                                _cart.remove(entry.key);
                                              } else {
                                                _cart[entry.key] =
                                                    entry.value - 1;
                                              }
                                            }),
                                            icon: const Icon(
                                              Icons.remove_circle_outline,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                  ],
                                ),
                        ),
                        const Divider(),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Total USD',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                            Text(
                              Money(
                                minorUnits: totalMinor,
                                currency: Currency.usd,
                              ).format(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed:
                                session == null ||
                                    _cart.isEmpty ||
                                    hasSyntheticCart ||
                                    totalMinor <= BigInt.zero ||
                                    _saving
                                ? null
                                : () => _confirmSale(
                                    database,
                                    workspace,
                                    session,
                                    productByVariant,
                                    totalMinor,
                                  ),
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.payments_outlined, size: 17),
                            label: const Text('Registrar pago'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Venta local · No fiscal',
                          style: AmalfiTheme.mutedText(context, fontSize: 9),
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

  Future<void> _confirmSale(
    LocalDatabase database,
    LocalWorkspace workspace,
    LocalCashSession session,
    Map<String, LocalCatalogProduct> products,
    BigInt totalMinor,
  ) async {
    final payments = await showPaymentAllocation(
      context,
      totalMinor: totalMinor,
    );
    if (payments == null || !mounted) return;
    setState(() => _saving = true);
    final id = const Uuid().v4();
    final saleNumber = 'L-${DateTime.now().toUtc().millisecondsSinceEpoch}';
    try {
      final items = <LocalSaleItemInput>[];
      final consumptions = <LocalInventoryConsumption>[];
      for (final entry in _cart.entries) {
        final product = products[entry.key];
        if (product == null) continue;
        final quantity = BigInt.from(entry.value);
        final unitPrice = BigInt.parse(product.priceMinor);
        items.add(
          LocalSaleItemInput(
            variantId: product.variantId,
            quantity: quantity.toString(),
            unitPriceMinor: unitPrice.toString(),
            subtotalMinor: (unitPrice * quantity).toString(),
          ),
        );
        consumptions.add(
          LocalInventoryConsumption(
            warehouseId: workspace.warehouseId,
            variantId: product.variantId,
            quantity: quantity.toString(),
          ),
        );
      }
      database.confirmSale(
        LocalSaleInput(
          id: id,
          organizationId: workspace.organizationId,
          branchId: workspace.branchId,
          terminalId: workspace.terminalId,
          profileId: workspace.profileId,
          cashSessionId: session.id,
          idempotencyKey: id,
          saleNumber: saleNumber,
          totalCurrency: 'USD',
          totalMinor: totalMinor.toString(),
          items: items,
          payments: payments,
          inventoryConsumptions: consumptions,
        ),
      );
      if (!mounted) return;
      setState(_cart.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Venta $saleNumber guardada localmente · pendiente de sincronización',
          ),
          action: SnackBarAction(
            label: 'Imprimir',
            onPressed: () =>
                _printReceipt(saleNumber, items, payments, totalMinor),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo confirmar la venta: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _printReceipt(
    String saleNumber,
    List<LocalSaleItemInput> saleItems,
    List<LocalPaymentInput> payments,
    BigInt totalMinor,
  ) async {
    final products = context.read<LocalDatabase>().getCatalogProducts();
    final productByVariant = {
      for (final product in products) product.variantId: product,
    };
    final now = DateTime.now().toUtc().toIso8601String();
    final printItems = saleItems
        .map((item) {
          final product = productByVariant[item.variantId];
          return LocalDiningItem(
            id: const Uuid().v4(),
            variantId: item.variantId,
            productName: product?.name ?? item.variantId,
            quantity: item.quantity,
            unitPriceMinor: item.unitPriceMinor,
            currencyCode: 'USD',
            station: product?.fulfillmentStation ?? 'BAR',
            status: 'DELIVERED',
            createdAt: now,
          );
        })
        .toList(growable: false);
    try {
      final printed = await _printer.printSaleReceipt(
        saleNumber: saleNumber,
        createdAt: now,
        items: printItems,
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error al imprimir: $error')));
      }
    }
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag(this.label, {this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: 75),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: accent
          ? AmalfiTheme.warning.withValues(alpha: .18)
          : Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: accent ? AmalfiTheme.warning : AmalfiTheme.mutedFor(context),
        fontSize: 8,
      ),
    ),
  );
}

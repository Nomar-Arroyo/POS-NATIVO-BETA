import 'package:core_money/core_money.dart';
import 'package:data_local/data_local.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../desktop_state.dart';
import '../theme/amalfi_theme.dart';
import 'amalfi_ui.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<LocalCatalogProduct> _products = const [];
  String _query = '';
  String _category = 'Todas';
  bool _wasActive = false;

  void _reload() {
    final database = context.read<LocalDatabase>();
    _products = database.getCatalogProducts(offlineOnly: false);
  }

  Future<void> _addProduct() async {
    final database = context.read<LocalDatabase>();
    final input = await showDialog<LocalProductInput>(
      context: context,
      builder: (context) => const _ProductDialog(),
    );
    if (input == null || !mounted) return;
    try {
      database.createLocalProduct(input);
      setState(_reload);
      _notify('Producto guardado localmente');
    } catch (error) {
      _notify('No se pudo guardar el producto: $error', isError: true);
    }
  }

  Future<void> _adjustStock() async {
    final database = context.read<LocalDatabase>();
    final products = _products
        .where((product) => database.isDemoMode || !product.isSynthetic)
        .toList();
    if (products.isEmpty) return;
    final input =
        await showDialog<({String variantId, String delta, String reason})>(
          context: context,
          builder: (context) => _StockAdjustmentDialog(products: products),
        );
    if (input == null || !mounted) return;
    try {
      final quantity = context.read<LocalDatabase>().adjustLocalInventory(
        variantId: input.variantId,
        quantityDelta: input.delta,
        reason: input.reason,
      );
      setState(_reload);
      _notify('Existencia actualizada: $quantity unidades');
    } catch (error) {
      _notify('No se pudo ajustar el stock: $error', isError: true);
    }
  }

  void _loadDemoCatalog() {
    try {
      final count = context.read<LocalDatabase>().loadSyntheticDemoCatalog();
      setState(_reload);
      _notify(
        count == 0
            ? 'El catálogo de demostración ya está cargado'
            : 'Se cargaron $count productos sintéticos de demostración',
      );
    } catch (error) {
      _notify(
        'No se pudo cargar el catálogo de demostración: $error',
        isError: true,
      );
    }
  }

  void _notify(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final database = context.read<LocalDatabase>();
    final isActive =
        context.watch<DesktopNavigationModel>().activeModule ==
        DesktopModule.inventory;
    if (isActive && !_wasActive) _reload();
    _wasActive = isActive;
    final categories = {
      for (final product in _products) product.categoryName,
    }.toList()..sort();
    categories.insert(0, 'Todas');
    final filteredProducts = _products
        .where((product) {
          final matchesSearch =
              _query.isEmpty ||
              product.name.toLowerCase().contains(_query.toLowerCase()) ||
              (product.sku?.toLowerCase().contains(_query.toLowerCase()) ??
                  false);
          return matchesSearch &&
              (_category == 'Todas' || product.categoryName == _category);
        })
        .toList(growable: false);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(
            title: 'Inventario',
            subtitle:
                'Consulta existencias, precios y disponibilidad de productos',
            trailing: Wrap(
              spacing: 8,
              children: [
                if (_products.isEmpty)
                  OutlinedButton.icon(
                    onPressed: _loadDemoCatalog,
                    icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                    label: const Text('Cargar catálogo demo'),
                  ),
                OutlinedButton.icon(
                  onPressed:
                      _products.any(
                        (product) =>
                            database.isDemoMode || !product.isSynthetic,
                      )
                      ? _adjustStock
                      : null,
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Ajustar stock'),
                ),
                FilledButton.icon(
                  onPressed: _addProduct,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar producto'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar producto por nombre o SKU...',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(value: category, child: Text(category)),
                  ],
                  onChanged: (value) =>
                      setState(() => _category = value ?? 'Todas'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AmalfiPanel(
              title: 'Estado del Inventario',
              trailing: Text(
                '${filteredProducts.length} productos',
                style: AmalfiTheme.mutedText(context, fontSize: 10),
              ),
              padding: EdgeInsets.zero,
              child: _products.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            color: AmalfiTheme.mutedFor(context),
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          const Text('No hay productos locales'),
                          const SizedBox(height: 4),
                          Text(
                            'Los productos demo son sintéticos y no se sincronizan.',
                            style: AmalfiTheme.mutedText(context, fontSize: 11),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _loadDemoCatalog,
                            icon: const Icon(Icons.auto_awesome_outlined),
                            label: const Text(
                              'Cargar catálogo de demostración',
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        _InventoryRow(
                          isHeader: true,
                          name: 'PRODUCTO',
                          category: 'CATEGORÍA',
                          price: 'PRECIO',
                          stock: 'STOCK',
                          availability: 'DISPONIBLE',
                        ),
                        Expanded(
                          child: filteredProducts.isEmpty
                              ? const Center(
                                  child: Text('No hay coincidencias'),
                                )
                              : ListView.builder(
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (context, index) {
                                    final product = filteredProducts[index];
                                    final quantity = product.availableQuantity;
                                    return _InventoryRow(
                                      name: product.name,
                                      category: product.categoryName,
                                      price: Money(
                                        minorUnits: BigInt.parse(
                                          product.priceMinor,
                                        ),
                                        currency: product.currencyCode == 'VES'
                                            ? Currency.ves
                                            : Currency.usd,
                                      ).format(),
                                      stock: quantity ?? 'N/D',
                                      availability: quantity == null
                                          ? 'N/D'
                                          : BigInt.parse(quantity) > BigInt.zero
                                          ? 'Sí'
                                          : 'No',
                                      synthetic: product.isSynthetic,
                                      station: _stationLabel(
                                        product.fulfillmentStation,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _stationLabel(String station) => switch (station) {
    'KITCHEN' => 'Cocina',
    'BAR' => 'Barra',
    _ => 'Sin estación',
  };
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.availability,
    this.station,
    this.synthetic = false,
    this.isHeader = false,
  });

  final String name;
  final String category;
  final String price;
  final String stock;
  final String availability;
  final String? station;
  final bool synthetic;
  final bool isHeader;

  @override
  Widget build(BuildContext context) => Container(
    height: isHeader ? 32 : 40,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    color: isHeader
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : Colors.transparent,
    child: Row(
      children: [
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isHeader ? 9 : 11,
                    color: isHeader ? AmalfiTheme.mutedFor(context) : null,
                    fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (!isHeader && synthetic)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: StatusBadge(label: 'DEMO', color: AmalfiTheme.warning),
                ),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            category,
            style: TextStyle(
              fontSize: isHeader ? 9 : 10,
              color: isHeader ? AmalfiTheme.mutedFor(context) : null,
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            price,
            style: TextStyle(
              fontSize: isHeader ? 9 : 10,
              color: isHeader ? AmalfiTheme.mutedFor(context) : null,
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            stock,
            style: TextStyle(
              fontSize: isHeader ? 9 : 10,
              color: isHeader ? AmalfiTheme.mutedFor(context) : null,
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            availability,
            style: TextStyle(
              fontSize: isHeader ? 9 : 10,
              color: isHeader
                  ? AmalfiTheme.mutedFor(context)
                  : availability == 'Sí'
                  ? AmalfiTheme.successFor(context)
                  : AmalfiTheme.errorFor(context),
              fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProductDialog extends StatefulWidget {
  const _ProductDialog();

  @override
  State<_ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<_ProductDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _category = TextEditingController();
  final _sku = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController(text: '0');
  bool _offlineSellable = false;
  String? _fulfillmentStation;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _category.dispose();
    _sku.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final price = Money.parse(_price.text, Currency.usd);
      final stock = BigInt.parse(_stock.text.trim());
      if (price.minorUnits < BigInt.zero || stock < BigInt.zero) {
        throw const FormatException(
          'Precio y existencia deben ser no negativos',
        );
      }

      final productId = const Uuid().v4();
      Navigator.of(context).pop(
        LocalProductInput(
          productId: productId,
          variantId: const Uuid().v4(),
          categoryId: const Uuid().v4(),
          categoryName: _category.text.trim(),
          name: _name.text.trim(),
          sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
          priceMinor: price.minorUnits.toString(),
          initialStock: stock.toString(),
          offlineSellable: _offlineSellable,
          fulfillmentStation: _fulfillmentStation!,
        ),
      );
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo producto local'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              _field(_name, 'Nombre', validator: _required),
              _field(_category, 'Categoría', validator: _required),
              _field(_sku, 'SKU (opcional)'),
              _field(
                _price,
                'Precio USD',
                validator: _required,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              _field(
                _stock,
                'Existencia inicial (unidades enteras)',
                validator: _required,
                keyboardType: TextInputType.number,
              ),
              DropdownButtonFormField<String>(
                initialValue: _fulfillmentStation,
                validator: (value) =>
                    value == null ? 'Selecciona cocina o barra' : null,
                decoration: const InputDecoration(
                  labelText: 'Estación de preparación',
                ),
                items: const [
                  DropdownMenuItem(value: 'KITCHEN', child: Text('Cocina')),
                  DropdownMenuItem(value: 'BAR', child: Text('Barra')),
                ],
                onChanged: (value) =>
                    setState(() => _fulfillmentStation = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Permitir venta sin conexión'),
                subtitle: const Text(
                  'Se venderá contra la existencia conocida en este terminal.',
                ),
                value: _offlineSellable,
                onChanged: (value) => setState(() => _offlineSellable = value),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    ),
  );
}

class _StockAdjustmentDialog extends StatefulWidget {
  const _StockAdjustmentDialog({required this.products});

  final List<LocalCatalogProduct> products;

  @override
  State<_StockAdjustmentDialog> createState() => _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState extends State<_StockAdjustmentDialog> {
  final _quantity = TextEditingController();
  final _reason = TextEditingController();
  late String _variantId = widget.products.first.variantId;
  String _direction = 'add';
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  void _save() {
    final quantity = BigInt.tryParse(_quantity.text.trim());
    if (quantity == null ||
        quantity <= BigInt.zero ||
        _reason.text.trim().isEmpty) {
      setState(() => _error = 'Indica una cantidad positiva y el motivo.');
      return;
    }
    Navigator.pop(context, (
      variantId: _variantId,
      delta: (_direction == 'add' ? quantity : -quantity).toString(),
      reason: _reason.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ajustar stock'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _variantId,
            decoration: const InputDecoration(labelText: 'Producto'),
            items: [
              for (final product in widget.products)
                DropdownMenuItem(
                  value: product.variantId,
                  child: Text(
                    '${product.name} · ${product.availableQuantity ?? 'N/D'}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) =>
                setState(() => _variantId = value ?? _variantId),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _direction,
                  decoration: const InputDecoration(labelText: 'Movimiento'),
                  items: const [
                    DropdownMenuItem(value: 'add', child: Text('Entrada')),
                    DropdownMenuItem(value: 'remove', child: Text('Salida')),
                  ],
                  onChanged: (value) =>
                      setState(() => _direction = value ?? 'add'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Unidades'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reason,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Motivo'),
          ),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _save, child: const Text('Guardar ajuste')),
    ],
  );
}

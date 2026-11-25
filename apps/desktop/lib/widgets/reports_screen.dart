import 'package:core_money/core_money.dart';
import 'package:data_local/data_local.dart';
import 'package:amalfi_brand_assets/amalfi_brand_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../desktop_state.dart';
import '../theme/amalfi_theme.dart';
import 'amalfi_ui.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _range = 'Hoy';

  bool _withinRange(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return false;
    final now = DateTime.now();
    return switch (_range) {
      '7 días' => now.difference(date).inDays < 7 && !date.isAfter(now),
      'Este mes' => date.year == now.year && date.month == now.month,
      _ =>
        date.year == now.year && date.month == now.month && date.day == now.day,
    };
  }

  Future<void> _export(List<LocalSaleSummary> sales) async {
    final csv = StringBuffer('Venta,Fecha,Moneda,Total,Estado local\n');
    for (final sale in sales) {
      csv.writeln(
        '${sale.saleNumber},${sale.createdAt},${sale.totalCurrency},${sale.totalMinor},${sale.syncStatus}',
      );
    }
    await Clipboard.setData(ClipboardData(text: csv.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporte CSV copiado al portapapeles')),
    );
  }

  @override
  Widget build(BuildContext context) {
    watchDesktopNavigation(context);
    final database = context.watch<LocalDatabase>();
    final allSales = database.recentSales(limit: 5000);
    final sales = allSales
        .where((sale) => _withinRange(sale.createdAt))
        .toList();
    final total = sales.fold<BigInt>(
      BigInt.zero,
      (sum, sale) => sum + BigInt.parse(sale.totalMinor),
    );
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(
            title: 'Reportes',
            subtitle: 'Consulta la actividad local del terminal',
            trailing: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _range,
                    decoration: const InputDecoration(labelText: 'Período'),
                    items: const [
                      DropdownMenuItem(value: 'Hoy', child: Text('Hoy')),
                      DropdownMenuItem(value: '7 días', child: Text('7 días')),
                      DropdownMenuItem(
                        value: 'Este mes',
                        child: Text('Este mes'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _range = value ?? 'Hoy'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _export(sales),
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Copiar CSV'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SummaryCard(
                  label: 'Ventas registradas',
                  value: '${sales.length}',
                  icon: AmalfiIconName.receipt,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SummaryCard(
                  label: 'Total local',
                  value: Money(
                    minorUnits: total,
                    currency: Currency.usd,
                  ).format(),
                  icon: AmalfiIconName.currency,
                  valueColor: AmalfiTheme.successFor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AmalfiPanel(
              title: 'Reporte de Ventas',
              child: sales.isEmpty
                  ? Center(
                      child: Text(
                        'No hay ventas locales para el período seleccionado.',
                        style: AmalfiTheme.mutedText(context, fontSize: 11),
                      ),
                    )
                  : ListView(
                      children: [
                        const _ReportRow(
                          sale: 'VENTA',
                          date: 'FECHA',
                          total: 'TOTAL',
                          status: 'ESTADO',
                          header: true,
                        ),
                        for (final sale in sales)
                          _ReportRow(
                            sale: sale.saleNumber,
                            date: sale.createdAt,
                            total: Money(
                              minorUnits: BigInt.parse(sale.totalMinor),
                              currency: sale.totalCurrency == 'VES'
                                  ? Currency.ves
                                  : Currency.usd,
                            ).format(),
                            status: sale.syncStatus,
                          ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Reporte local de operaciones; no es un libro fiscal ni una declaración tributaria.',
            style: AmalfiTheme.mutedText(context, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.sale,
    required this.date,
    required this.total,
    required this.status,
    this.header = false,
  });

  final String sale;
  final String date;
  final String total;
  final String status;
  final bool header;

  @override
  Widget build(BuildContext context) => Container(
    height: header ? 34 : 42,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    color: header
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : null,
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            sale,
            style: TextStyle(
              fontSize: header ? 9 : 11,
              color: header ? AmalfiTheme.mutedFor(context) : null,
              fontWeight: header ? FontWeight.w700 : null,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            date,
            style: TextStyle(
              fontSize: header ? 9 : 10,
              color: header ? AmalfiTheme.mutedFor(context) : null,
              fontWeight: header ? FontWeight.w700 : null,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            total,
            style: TextStyle(
              fontSize: header ? 9 : 10,
              color: header ? AmalfiTheme.mutedFor(context) : null,
              fontWeight: header ? FontWeight.w700 : null,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            status,
            style: TextStyle(
              fontSize: header ? 9 : 10,
              color: header
                  ? AmalfiTheme.mutedFor(context)
                  : AmalfiTheme.warning,
              fontWeight: header ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    ),
  );
}

import 'dart:convert';

import 'package:data_local/data_local.dart';
import 'package:core_money/core_money.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class LocalPrintService {
  const LocalPrintService();

  Future<bool> printPrecuenta(
    LocalPrecuenta precuenta, {
    int widthMm = 80,
  }) => printLines(
    title: 'Precuenta ${precuenta.id}',
    widthMm: widthMm,
    lines: [
      'CAFFE AMALFI',
      'PRECUENTA - NO FISCAL',
      'Mesa: ${precuenta.tableName}',
      'Fecha: ${precuenta.generatedAt}',
      '--------------------------------',
      for (final item in precuenta.items)
        '${item.quantity} x ${item.productName}  '
            '${Money(minorUnits: BigInt.parse(item.subtotalMinor), currency: Currency.usd).toDecimalString()} USD',
      '--------------------------------',
      'TOTAL USD: ${precuenta.totalUsdMinor}',
      'Documento no fiscal',
    ],
  );

  Future<bool> printProductionOrder(
    LocalProductionOrder order, {
    int widthMm = 80,
  }) => printLines(
    title: 'Comanda ${order.orderNumber}',
    widthMm: widthMm,
    lines: [
      'CAFFE AMALFI',
      order.station == 'KITCHEN' ? 'COMANDA - COCINA' : 'COMANDA - BARRA',
      'Orden: ${order.orderNumber}',
      'Mesa: ${order.tableName}',
      'Fecha: ${order.createdAt}',
      '--------------------------------',
      for (final item in order.items)
        '${item.quantity} x ${item.productName}'
            '${item.notes == null || item.notes!.isEmpty ? '' : '\n  Nota: ${item.notes}'}',
      '--------------------------------',
      'Estado: ${order.status}',
    ],
  );

  Future<bool> printSaleReceipt({
    required String saleNumber,
    required String createdAt,
    required List<LocalDiningItem> items,
    required String totalUsdMinor,
    required List<LocalPaymentInput> payments,
    int widthMm = 80,
  }) => printLines(
    title: 'Comprobante $saleNumber',
    widthMm: widthMm,
    lines: [
      'CAFFE AMALFI',
      'COMPROBANTE LOCAL NO FISCAL',
      'Venta: $saleNumber',
      'Fecha: $createdAt',
      '--------------------------------',
      for (final item in items)
        '${item.quantity} x ${item.productName}  '
            '${Money(minorUnits: BigInt.parse(item.subtotalMinor), currency: Currency.usd).toDecimalString()} USD',
      '--------------------------------',
      for (final payment in payments)
        '${_paymentMethod(payment.method)}: '
            '${Money(minorUnits: BigInt.parse(payment.amountMinor), currency: Currency.usd).toDecimalString()} USD',
      'TOTAL USD: ${_formatUsd(totalUsdMinor)}',
      'Documento no fiscal',
    ],
  );

  Future<bool> printCashClosure({
    required LocalCashSession session,
    required String expectedUsdMinor,
    required int widthMm,
  }) => printLines(
    title: 'Cierre de caja',
    widthMm: widthMm,
    lines: [
      'CAFFE AMALFI',
      'CIERRE LOCAL DE CAJA',
      'Turno: ${session.id}',
      'Apertura: ${session.openedAt}',
      'Cierre: ${session.closedAt ?? ''}',
      '--------------------------------',
      'Esperado USD: ${_formatUsd(expectedUsdMinor)}',
      'Contado USD: ${_formatUsd(_usdMinor(session.closingMinor))}',
      'Diferencia USD: ${_formatUsd(session.differenceUsdMinor ?? '0')}',
      'Documento local no fiscal',
    ],
  );

  Future<bool> printLines({
    required String title,
    required List<String> lines,
    int widthMm = 80,
  }) async {
    if (widthMm != 58 && widthMm != 80) {
      throw ArgumentError.value(widthMm, 'widthMm', 'Use 58 or 80 mm');
    }
    final document = pw.Document();
    final pageWidth = widthMm * PdfPageFormat.mm;
    final pageFormat = PdfPageFormat(
      pageWidth,
      240 * PdfPageFormat.mm,
      marginAll: 5 * PdfPageFormat.mm,
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        build: (_) => [
          for (var index = 0; index < lines.length; index++)
            pw.Padding(
              padding: pw.EdgeInsets.only(bottom: index == 0 ? 8 : 3),
              child: pw.Text(
                lines[index],
                style: pw.TextStyle(
                  fontSize: index == 0 ? 12 : 9,
                  fontWeight: index == 0
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                ),
                textAlign: index == 0 ? pw.TextAlign.center : pw.TextAlign.left,
              ),
            ),
        ],
      ),
    );
    final bytes = await document.save();
    return Printing.layoutPdf(
      name: title,
      format: pageFormat,
      onLayout: (_) async => bytes,
    );
  }

  String _usdMinor(String? encoded) {
    if (encoded == null) return '0';
    return (jsonDecode(encoded) as Map<String, dynamic>)['USD'] as String;
  }

  String _formatUsd(String minorUnits) => Money(
    minorUnits: BigInt.parse(minorUnits),
    currency: Currency.usd,
  ).toDecimalString();

  String _paymentMethod(String method) => switch (method) {
    'CASH_USD' => 'Efectivo USD',
    'CARD_USD' => 'Tarjeta USD',
    'TRANSFER_USD' => 'Transferencia USD',
    'ZELLE_USD' => 'Zelle USD',
    _ => method,
  };
}

class ProductionPrintFallbackResult {
  const ProductionPrintFallbackResult({
    required this.failures,
    required this.cancelledCount,
  });

  final List<String> failures;
  final int cancelledCount;

  bool get hasIssues => failures.isNotEmpty || cancelledCount > 0;
}

Future<ProductionPrintFallbackResult> printOrdersWithoutStationDisplays({
  required LocalDatabase database,
  required Iterable<LocalProductionOrder> orders,
  required Future<bool> Function(LocalProductionOrder) printOrder,
}) async {
  final failures = <String>[];
  var cancelledCount = 0;
  for (final order in orders) {
    if (database.isStationDisplayEnabled(order.station)) continue;
    try {
      if (!await printOrder(order)) cancelledCount++;
    } catch (error) {
      failures.add('${order.station}: $error');
    }
  }
  return ProductionPrintFallbackResult(
    failures: failures,
    cancelledCount: cancelledCount,
  );
}

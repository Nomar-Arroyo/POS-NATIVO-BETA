import 'package:core_money/core_money.dart';
import 'package:data_local/data_local.dart';
import 'package:flutter/material.dart';

const _paymentMethods = {
  'CASH_USD': 'Efectivo USD',
  'CARD_USD': 'Tarjeta USD',
  'TRANSFER_USD': 'Transferencia USD',
  'ZELLE_USD': 'Zelle USD',
};

Future<List<LocalPaymentInput>?> showPaymentAllocation(
  BuildContext context, {
  required BigInt totalMinor,
}) => showDialog<List<LocalPaymentInput>>(
  context: context,
  builder: (context) => PaymentAllocationDialog(totalMinor: totalMinor),
);

class PaymentAllocationDialog extends StatefulWidget {
  const PaymentAllocationDialog({required this.totalMinor, super.key});

  final BigInt totalMinor;

  @override
  State<PaymentAllocationDialog> createState() =>
      _PaymentAllocationDialogState();
}

class _PaymentAllocationDialogState extends State<PaymentAllocationDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<_PaymentLine> _lines = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _lines.add(
      _PaymentLine(
        'CASH_USD',
        Money(
          minorUnits: widget.totalMinor,
          currency: Currency.usd,
        ).toDecimalString(),
      ),
    );
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.amount.dispose();
    }
    super.dispose();
  }

  void _addLine() {
    final used = _lines.map((line) => line.method).toSet();
    final next = _paymentMethods.keys.firstWhere(
      (method) => !used.contains(method),
      orElse: () => '',
    );
    if (next.isEmpty) return;
    setState(() {
      _lines.add(_PaymentLine(next, '0.00'));
      _error = null;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final methods = _lines.map((line) => line.method).toSet();
      if (methods.length != _lines.length) {
        throw const FormatException('Cada método debe aparecer una sola vez');
      }
      final payments = <LocalPaymentInput>[];
      var paid = BigInt.zero;
      for (final line in _lines) {
        final amount = Money.parse(line.amount.text, Currency.usd).minorUnits;
        if (amount <= BigInt.zero) {
          throw const FormatException('Cada pago debe ser mayor que cero');
        }
        paid += amount;
        payments.add(
          LocalPaymentInput(
            method: line.method,
            amountMinor: amount.toString(),
            currencyCode: 'USD',
            originalAmountMinor: amount.toString(),
            originalCurrencyCode: 'USD',
          ),
        );
      }
      if (paid != widget.totalMinor) {
        throw const FormatException(
          'La suma de los pagos debe ser igual al total exacto',
        );
      }
      Navigator.of(context).pop(payments);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final used = _lines.map((line) => line.method).toSet();
    final totalPaid = _lines.fold<BigInt>(BigInt.zero, (sum, line) {
      try {
        return sum + Money.parse(line.amount.text, Currency.usd).minorUnits;
      } on FormatException {
        return sum;
      }
    });
    final remaining = widget.totalMinor - totalPaid;

    return AlertDialog(
      title: const Text('Distribuir pago'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Total ${Money(minorUnits: widget.totalMinor, currency: Currency.usd).format()}',
                ),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < _lines.length; index++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _lines[index].method,
                          decoration: const InputDecoration(
                            labelText: 'Método',
                          ),
                          items: _paymentMethods.entries
                              .where(
                                (entry) =>
                                    entry.key == _lines[index].method ||
                                    !used.contains(entry.key),
                              )
                              .map(
                                (entry) => DropdownMenuItem(
                                  value: entry.key,
                                  child: Text(
                                    entry.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _lines[index].method = value;
                              _error = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _lines[index].amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Monto USD',
                          ),
                          validator: (value) {
                            try {
                              Money.parse(value ?? '', Currency.usd);
                              return null;
                            } catch (_) {
                              return 'Monto inválido';
                            }
                          },
                          onChanged: (_) => setState(() => _error = null),
                        ),
                      ),
                      if (_lines.length > 1)
                        IconButton(
                          tooltip: 'Quitar método',
                          onPressed: () => setState(() {
                            _lines.removeAt(index).amount.dispose();
                          }),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _lines.length == _paymentMethods.length
                      ? null
                      : _addLine,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar método de pago'),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Saldo por asignar: ${Money(minorUnits: remaining, currency: Currency.usd).format()}',
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Pagos en USD únicamente. No se convierte moneda ni se calcula vuelto.',
                ),
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
        FilledButton(onPressed: _submit, child: const Text('Confirmar pagos')),
      ],
    );
  }
}

class _PaymentLine {
  _PaymentLine(this.method, String amount)
    : amount = TextEditingController(text: amount);

  String method;
  final TextEditingController amount;
}

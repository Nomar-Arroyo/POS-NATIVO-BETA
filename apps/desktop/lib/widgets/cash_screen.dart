import 'dart:convert';

import 'package:core_money/core_money.dart';
import 'package:data_local/data_local.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../desktop_state.dart';
import '../services/local_print_service.dart';
import '../theme/amalfi_theme.dart';
import 'amalfi_ui.dart';

class CashScreen extends StatefulWidget {
  const CashScreen({super.key});

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  final _printer = const LocalPrintService();
  final _amount = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _openSession() async {
    final database = context.read<LocalDatabase>();
    try {
      final opening = Money.parse(_amount.text, Currency.usd);
      if (opening.minorUnits < BigInt.zero) {
        throw const FormatException('El monto no puede ser negativo');
      }
      setState(() => _busy = true);
      database.openLocalCashSession(
        sessionId: const Uuid().v4(),
        openingUsdMinor: opening.minorUnits.toString(),
      );
      _amount.clear();
      _notify('Caja abierta y guardada localmente');
    } catch (error) {
      _notify('No se pudo abrir la caja: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeSession(LocalCashSession session) async {
    final database = context.read<LocalDatabase>();
    final expectedMinor = database.cashExpectedUsdMinor(session.id);
    final controller = TextEditingController(
      text: Money(
        minorUnits: BigInt.parse(expectedMinor),
        currency: Currency.usd,
      ).toDecimalString(),
    );
    final amount = await showDialog<Money>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar caja'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Efectivo esperado: ${Money(minorUnits: BigInt.parse(expectedMinor), currency: Currency.usd).format()}',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Conteo real USD'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              try {
                Navigator.pop(
                  context,
                  Money.parse(controller.text, Currency.usd),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa un monto válido')),
                );
              }
            },
            child: const Text('Cerrar turno'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (amount == null || !mounted) return;
    try {
      setState(() => _busy = true);
      final result = database.closeLocalCashSession(
        sessionId: session.id,
        closingUsdMinor: amount.minorUnits.toString(),
      );
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cierre local de caja'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CashMetric(
                  label: 'Esperado',
                  value: Money(
                    minorUnits: BigInt.parse(result.expectedUsdMinor!),
                    currency: Currency.usd,
                  ).format(),
                ),
                _CashMetric(
                  label: 'Contado',
                  value: Money(
                    minorUnits: BigInt.parse(
                      result.closingMinor == null
                          ? '0'
                          : (jsonDecode(result.closingMinor!)
                                    as Map<String, dynamic>)['USD']
                                as String,
                    ),
                    currency: Currency.usd,
                  ).format(),
                ),
                _CashMetric(
                  label: 'Diferencia',
                  value: Money(
                    minorUnits: BigInt.parse(result.differenceUsdMinor!),
                    currency: Currency.usd,
                  ).format(),
                ),
                const SizedBox(height: 8),
                const Text('Cierre local. No es un reporte fiscal.'),
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
                try {
                  final printed = await _printer.printCashClosure(
                    session: result,
                    expectedUsdMinor: result.expectedUsdMinor!,
                    widthMm: 80,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          printed
                              ? 'Cierre enviado a impresión'
                              : 'No se confirmó la impresión',
                        ),
                      ),
                    );
                  }
                } catch (error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al imprimir: $error')),
                    );
                  }
                }
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('Imprimir cierre'),
            ),
          ],
        ),
      );
      if (mounted) _notify('Caja cerrada localmente');
    } catch (error) {
      _notify('No se pudo cerrar la caja: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordMovement(LocalCashSession session, String type) async {
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
    final amount = await showDialog<Money>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          type == 'income' ? 'Registrar ingreso' : 'Registrar egreso',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto USD',
                prefixText: '\$ ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              try {
                final parsed = Money.parse(amountController.text, Currency.usd);
                if (parsed.minorUnits <= BigInt.zero ||
                    reasonController.text.trim().isEmpty) {
                  throw const FormatException(
                    'Monto y motivo son obligatorios',
                  );
                }
                Navigator.pop(context, parsed);
              } catch (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Datos inválidos: $error')),
                );
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    amountController.dispose();
    reasonController.dispose();
    if (amount == null || !mounted) return;
    try {
      setState(() => _busy = true);
      context.read<LocalDatabase>().recordLocalCashMovement(
        sessionId: session.id,
        type: type,
        amountUsdMinor: amount.minorUnits.toString(),
        reason: reason,
      );
      _notify(type == 'income' ? 'Ingreso registrado' : 'Egreso registrado');
    } catch (error) {
      _notify('No se pudo registrar el movimiento: $error', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notify(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    watchDesktopNavigation(context);
    final database = context.watch<LocalDatabase>();
    final workspace = database.localWorkspace!;
    final session = database.activeCashSession;
    final opening = session == null
        ? null
        : (jsonDecode(session.openingMinor) as Map<String, dynamic>)['USD']
              as String;
    final expected = session == null
        ? null
        : database.cashExpectedUsdMinor(session.id);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeading(
            title: 'Gestión de Caja',
            subtitle: 'Control de efectivo y turnos',
            trailing: StatusBadge(
              label: session == null ? 'Caja cerrada' : 'Turno abierto',
              color: session == null
                  ? AmalfiTheme.errorFor(context)
                  : AmalfiTheme.successFor(context),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AmalfiPanel(
              title: '${workspace.cashRegisterName} · ${workspace.profileName}',
              padding: const EdgeInsets.all(16),
              child: session == null
                  ? _openForm()
                  : _activeSession(session, opening!, expected!),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Flujo local en USD. Sin conexión bancaria, sincronización remota ni validez fiscal.',
            style: AmalfiTheme.mutedText(context, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _openForm() {
    final compact = MediaQuery.sizeOf(context).height < 700;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!compact) ...[
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: AmalfiTheme.brandFor(context),
          ),
          const SizedBox(height: 14),
        ],
        Text('Caja cerrada', style: Theme.of(context).textTheme.titleMedium),
        if (!compact) ...[
          const SizedBox(height: 4),
          Text(
            'Abre una caja para iniciar el control de efectivo del turno.',
            style: AmalfiTheme.mutedText(context, fontSize: 11),
          ),
        ],
        SizedBox(height: compact ? 8 : 16),
        SizedBox(
          width: 300,
          child: TextField(
            controller: _amount,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Fondo inicial USD',
              prefixText: '\$ ',
            ),
          ),
        ),
        SizedBox(height: compact ? 6 : 12),
        FilledButton.icon(
          onPressed: _busy ? null : _openSession,
          icon: const Icon(Icons.payments_outlined, size: 17),
          label: const Text('Abrir caja'),
        ),
      ],
    );
  }

  Widget _activeSession(
    LocalCashSession session,
    String opening,
    String expected,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_open, color: Color(0xFF159FA2)),
              const SizedBox(width: 8),
              Text(
                'Turno abierto',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _recordMovement(session, 'income'),
            icon: const Icon(Icons.add),
            label: const Text('Ingreso'),
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _recordMovement(session, 'expense'),
            icon: const Icon(Icons.remove),
            label: const Text('Egreso'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : () => _closeSession(session),
            icon: const Icon(Icons.lock),
            label: const Text('Cerrar caja'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AmalfiTheme.outlineFor(context)),
        ),
        child: Text(
          'El fondo inicial, ventas en efectivo, ingresos y egresos se incluyen en el conteo del turno.',
          style: AmalfiTheme.mutedText(context, fontSize: 11),
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 24,
        runSpacing: 12,
        children: [
          _CashMetric(
            label: 'Fondo inicial',
            value: Money(
              minorUnits: BigInt.parse(opening),
              currency: Currency.usd,
            ).format(),
          ),
          _CashMetric(
            label: 'Efectivo esperado',
            value: Money(
              minorUnits: BigInt.parse(expected),
              currency: Currency.usd,
            ).format(),
          ),
          _CashMetric(
            label: 'Estado de sincronización',
            value: 'Local / pendiente',
          ),
        ],
      ),
    ],
  );
}

class _CashMetric extends StatelessWidget {
  const _CashMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}

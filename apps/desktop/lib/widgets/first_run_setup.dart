import 'package:data_local/data_local.dart';
import 'package:amalfi_brand_assets/amalfi_brand_assets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class FirstRunSetup extends StatefulWidget {
  const FirstRunSetup({
    required this.onComplete,
    required this.onOpenDemo,
    this.errorMessage,
    super.key,
  });

  final VoidCallback onComplete;
  final VoidCallback onOpenDemo;
  final String? errorMessage;

  @override
  State<FirstRunSetup> createState() => _FirstRunSetupState();
}

class _FirstRunSetupState extends State<FirstRunSetup> {
  final _formKey = GlobalKey<FormState>();
  final _organization = TextEditingController();
  final _branch = TextEditingController();
  final _terminal = TextEditingController();
  final _operator = TextEditingController();
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  final _warehouse = TextEditingController();
  final _cashRegister = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _organization.dispose();
    _branch.dispose();
    _terminal.dispose();
    _operator.dispose();
    _pin.dispose();
    _confirmPin.dispose();
    _warehouse.dispose();
    _cashRegister.dispose();
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Campo obligatorio' : null;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      context.read<LocalDatabase>().createLocalWorkspace(
        LocalWorkspaceInput(
          organizationId: const Uuid().v4(),
          organizationName: _organization.text,
          branchId: const Uuid().v4(),
          branchName: _branch.text,
          terminalId: const Uuid().v4(),
          terminalName: _terminal.text,
          profileId: const Uuid().v4(),
          profileName: _operator.text,
          warehouseId: const Uuid().v4(),
          warehouseName: _warehouse.text,
          cashRegisterId: const Uuid().v4(),
          cashRegisterName: _cashRegister.text,
          profilePin: _pin.text,
        ),
      );
      widget.onComplete();
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Center(
                      child: Image.asset(
                        AmalfiBrandAssets.logo,
                        width: 76,
                        height: 76,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Configuración local inicial',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Esta configuración permanece en este equipo. Supabase/Auth no está conectado; no representa una cuenta verificada.',
                    ),
                    const SizedBox(height: 24),
                    _field(_organization, 'Empresa'),
                    _field(_branch, 'Sucursal'),
                    _field(_terminal, 'Nombre de este terminal'),
                    _field(_operator, 'Administrador local'),
                    _pinField(_pin, 'PIN de administrador'),
                    _pinField(
                      _confirmPin,
                      'Confirmar PIN',
                      validator: (value) =>
                          value != _pin.text ? 'Los PIN no coinciden' : null,
                    ),
                    _field(_warehouse, 'Almacén'),
                    _field(_cashRegister, 'Caja'),
                    if (_error != null || widget.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error ?? widget.errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _saving ? null : widget.onOpenDemo,
                          icon: const Icon(Icons.science_outlined),
                          label: const Text('Abrir demo aislada'),
                        ),
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: const Text('Guardar en este equipo'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      validator: _required,
      decoration: InputDecoration(labelText: label),
    ),
  );

  Widget _pinField(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 8,
      validator:
          validator ??
          (value) => value == null || !RegExp(r'^[0-9]{4,8}$').hasMatch(value)
              ? 'Usa entre 4 y 8 dígitos'
              : null,
      decoration: InputDecoration(labelText: label, counterText: ''),
    ),
  );
}

import 'package:data_local/data_local.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../desktop_state.dart';
import '../theme/amalfi_theme.dart';
import 'amalfi_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _addProfile() async {
    final input = await showDialog<({String name, String role, String pin})>(
      context: context,
      builder: (context) => const _LocalProfileDialog(),
    );
    if (input == null || !mounted) return;
    try {
      context.read<LocalDatabase>().createLocalProfile(
        displayName: input.name,
        roleCode: input.role,
        pin: input.pin,
      );
      setState(() {});
      _notify('Perfil local creado');
    } catch (error) {
      _notify('No se pudo crear el perfil: $error', isError: true);
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
    watchDesktopNavigation(context);
    final database = context.watch<LocalDatabase>();
    final workspace = database.localWorkspace!;
    final pending = database.outbox.pending().length;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ScreenHeading(
            title: 'Configuración',
            subtitle: 'Configuración del terminal y preferencias locales',
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                _SettingsSection(
                  title: 'Configuración del Catálogo',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _ReadOnlyField(
                              label: 'Nombre del establecimiento',
                              value: workspace.organizationName,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _ReadOnlyField(
                              label: 'Sucursal',
                              value: workspace.branchName,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ReadOnlyField(
                              label: 'Terminal',
                              value: workspace.terminalName,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _ReadOnlyField(
                              label: 'Operador local',
                              value: workspace.profileName,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ReadOnlyField(
                              label: 'Almacén',
                              value: workspace.warehouseName,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _ReadOnlyField(
                              label: 'Caja asignada',
                              value: workspace.cashRegisterName,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'La identidad es local y no se ha verificado con un proveedor de autenticación.',
                          style: AmalfiTheme.mutedText(context, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  title: 'Configuración Fiscal',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            color: AmalfiTheme.warning,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Reglas fiscales desactivadas',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          border: Border.all(
                            color: AmalfiTheme.brandFor(context)
                                .withValues(alpha: .5),
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'No se aplican IVA, IGTF ni otros impuestos. Estos valores permanecerán deshabilitados hasta contar con validación normativa y una implementación fiscal autorizada.',
                          style: TextStyle(fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  title: 'Almacenamiento y Sincronización',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _InfoChip(
                        icon: Icons.storage_outlined,
                        label: 'Esquema SQLite v${database.userVersion}',
                      ),
                      _InfoChip(
                        icon: Icons.sync_outlined,
                        label: '$pending operaciones pendientes',
                      ),
                      const _InfoChip(
                        icon: Icons.cloud_off_outlined,
                        label: 'Servidor no conectado',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  title: 'Perfiles locales',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _addProfile,
                          icon: const Icon(Icons.person_add_alt_1),
                          label: const Text('Agregar perfil'),
                        ),
                      ),
                      for (final profile in database.getLocalProfiles())
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.account_circle_outlined),
                          title: Text(profile.displayName),
                          subtitle: Text(
                            '${profile.roleName} · ${profile.hasPin ? 'PIN configurado' : 'PIN pendiente'}',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SettingsSection(
                  title: 'Salida de comandas',
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: database.isStationDisplayEnabled('KITCHEN'),
                        title: const Text('Pantalla local de cocina'),
                        subtitle: const Text(
                          'Si se desactiva, abre el diálogo de impresión para cada comanda de cocina.',
                        ),
                        onChanged: (enabled) {
                          database.setStationDisplayEnabled('KITCHEN', enabled);
                          setState(() {});
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: database.isStationDisplayEnabled('BAR'),
                        title: const Text('Pantalla local de barra'),
                        subtitle: const Text(
                          'Si se desactiva, abre el diálogo de impresión para cada comanda de barra.',
                        ),
                        onChanged: (enabled) {
                          database.setStationDisplayEnabled('BAR', enabled);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalProfileDialog extends StatefulWidget {
  const _LocalProfileDialog();

  @override
  State<_LocalProfileDialog> createState() => _LocalProfileDialogState();
}

class _LocalProfileDialogState extends State<_LocalProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  String _role = 'cashier';

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nuevo perfil local'),
    content: SizedBox(
      width: 400,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Campo obligatorio'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: const [
                DropdownMenuItem(value: 'cashier', child: Text('Cajero')),
                DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                DropdownMenuItem(value: 'kitchen', child: Text('Cocina')),
                DropdownMenuItem(value: 'bar', child: Text('Barra')),
              ],
              onChanged: (value) => setState(() => _role = value ?? 'cashier'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'PIN (4 a 8 dígitos)',
                counterText: '',
              ),
              validator: (value) =>
                  value == null || !RegExp(r'^[0-9]{4,8}$').hasMatch(value)
                  ? 'Usa entre 4 y 8 dígitos'
                  : null,
            ),
            TextFormField(
              controller: _confirmPin,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Confirmar PIN',
                counterText: '',
              ),
              validator: (value) =>
                  value != _pin.text ? 'Los PIN no coinciden' : null,
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
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, (
            name: _name.text.trim(),
            role: _role,
            pin: _pin.text,
          ));
        },
        child: const Text('Crear perfil'),
      ),
    ],
  );
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AmalfiTheme.panelFor(context),
      border: Border.all(color: AmalfiTheme.outlineFor(context)),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.all(12), child: child),
      ],
    ),
  );
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Text(label, style: AmalfiTheme.mutedText(context, fontSize: 10)),
      ),
      TextFormField(
        initialValue: value,
        readOnly: true,
        decoration: const InputDecoration(isDense: true),
        style: const TextStyle(fontSize: 11),
      ),
    ],
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16, color: AmalfiTheme.brandFor(context)),
    label: Text(label, style: const TextStyle(fontSize: 10)),
    side: BorderSide(color: AmalfiTheme.outlineFor(context)),
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
  );
}

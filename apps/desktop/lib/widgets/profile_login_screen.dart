import 'package:data_local/data_local.dart';
import 'package:amalfi_brand_assets/amalfi_brand_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ProfileLoginScreen extends StatefulWidget {
  const ProfileLoginScreen({
    required this.onAuthenticated,
    required this.onOpenDemo,
    this.errorMessage,
    super.key,
  });

  final ValueChanged<String> onAuthenticated;
  final VoidCallback onOpenDemo;
  final String? errorMessage;

  @override
  State<ProfileLoginScreen> createState() => _ProfileLoginScreenState();
}

class _ProfileLoginScreenState extends State<ProfileLoginScreen> {
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  List<LocalProfile> _profiles = const [];
  String? _selectedProfileId;
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_profiles.isEmpty) _reloadProfiles();
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _reloadProfiles() {
    final profiles = context.read<LocalDatabase>().getLocalProfiles();
    setState(() {
      _profiles = profiles;
      _selectedProfileId ??= profiles.isEmpty ? null : profiles.first.id;
    });
  }

  Future<void> _signIn() async {
    final profileId = _selectedProfileId;
    if (_busy || profileId == null) return;
    final profile = _profiles.firstWhere((item) => item.id == profileId);
    if (!profile.hasPin && _pin.text != _confirmation.text) {
      setState(() => _error = 'Los PIN no coinciden.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final database = context.read<LocalDatabase>();
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    try {
      if (!profile.hasPin) {
        database.configureInitialProfilePin(
          profileId: profileId,
          pin: _pin.text,
        );
      }
      final sessionId = database.authenticateLocalProfile(
        profileId: profileId,
        pin: _pin.text,
      );
      if (sessionId == null) {
        setState(
          () => _error = 'PIN incorrecto o acceso temporalmente bloqueado.',
        );
        return;
      }
      widget.onAuthenticated(sessionId);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _profiles.where((item) => item.id == _selectedProfileId);
    final profile = selected.isEmpty ? null : selected.first;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      AmalfiBrandAssets.logo,
                      width: 92,
                      height: 92,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Iniciar sesión local',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Selecciona tu perfil e ingresa el PIN asignado en este terminal.',
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedProfileId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Perfil'),
                    items: [
                      for (final item in _profiles)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            '${item.displayName} · ${item.roleName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            _selectedProfileId = value;
                            _pin.clear();
                            _confirmation.clear();
                            _error = null;
                          }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: profile?.hasPin == false
                          ? 'Crea el PIN inicial del administrador'
                          : 'PIN',
                      counterText: '',
                    ),
                    onSubmitted: (_) => _signIn(),
                  ),
                  if (profile?.hasPin == false) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirmation,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Confirmar PIN',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _signIn(),
                    ),
                  ],
                  if (_error != null || widget.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error ?? widget.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy || profile == null ? null : _signIn,
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Entrar'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : widget.onOpenDemo,
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Abrir entorno demo aislado'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'La autenticación es local y no requiere Supabase. '
                    'El PIN se almacena como hash con salt; no es una cuenta remota.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

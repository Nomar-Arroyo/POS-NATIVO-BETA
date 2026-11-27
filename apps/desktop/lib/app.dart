import 'package:data_local/data_local.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'desktop_state.dart';
import 'theme/amalfi_theme.dart';
import 'widgets/first_run_setup.dart';
import 'widgets/desktop_shell.dart';
import 'widgets/profile_login_screen.dart';

class AmalfiDesktopApp extends StatefulWidget {
  const AmalfiDesktopApp({super.key, this.database});

  final LocalDatabase? database;

  @override
  State<AmalfiDesktopApp> createState() => _AmalfiDesktopAppState();
}

class _AmalfiDesktopAppState extends State<AmalfiDesktopApp> {
  Future<LocalWorkspace?>? _workspace;
  late final DesktopAppearanceModel _appearance;
  LocalDatabase? _activeDatabase;
  LocalDatabase? _demoDatabase;
  String? _profileSessionId;
  bool _authenticated = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _activeDatabase = widget.database;
    _appearance = DesktopAppearanceModel(database: widget.database);
    _workspace = Future.value(_activeDatabase?.localWorkspace);
  }

  void _reloadWorkspace() {
    setState(() {
      _authenticated = false;
      _startupError = null;
      _workspace = Future.value(_activeDatabase?.localWorkspace);
    });
  }

  void _onAuthenticated(String sessionId) {
    setState(() {
      _profileSessionId = sessionId;
      _authenticated = true;
      _startupError = null;
      _workspace = Future.value(_activeDatabase?.localWorkspace);
    });
  }

  Future<void> _openDemo() async {
    if (mounted) setState(() => _startupError = null);
    try {
      final database = await LocalDatabase.openDemoInMemory();
      database.initializeDemoWorkspace();
      final workspace = database.localWorkspace!;
      final sessionId = database.activeProfileSessionId!;
      if (!mounted) {
        database.close();
        return;
      }
      _appearance.attachDatabase(database);
      setState(() {
        _demoDatabase = database;
        _activeDatabase = database;
        _profileSessionId = sessionId;
        _authenticated = true;
        _startupError = null;
        _workspace = Future.value(workspace);
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _startupError = 'No se pudo iniciar el entorno demo: $error',
        );
      }
    }
  }

  Future<void> _logout() async {
    final database = _activeDatabase;
    final sessionId = _profileSessionId;
    if (database != null && sessionId != null) {
      database.endLocalProfileSession(sessionId);
    }
    final demo = _demoDatabase;
    _appearance.attachDatabase(widget.database);
    setState(() {
      _profileSessionId = null;
      _authenticated = false;
      _activeDatabase = widget.database;
      _workspace = Future.value(widget.database?.localWorkspace);
      _demoDatabase = null;
      _startupError = null;
    });
    if (demo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => demo.close());
    }
  }

  @override
  void dispose() {
    _demoDatabase?.close();
    _appearance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final database = _activeDatabase;
    return ChangeNotifierProvider.value(
      value: _appearance,
      child: Builder(
        builder: (context) => MaterialApp(
          title: 'Caffè Amalfi POS',
          debugShowCheckedModeBanner: false,
          theme: AmalfiTheme.light(),
          darkTheme: AmalfiTheme.dark(),
          themeMode: context.watch<DesktopAppearanceModel>().themeMode,
          home: database == null
              ? const _DatabaseUnavailable()
              : MultiProvider(
                  key: ObjectKey(_profileSessionId ?? database),
                  providers: [
                    Provider<LocalDatabase>.value(value: database),
                    ChangeNotifierProvider(
                      create: (_) => DesktopNavigationModel(
                        allowedModules: _allowedModules(database),
                      ),
                    ),
                  ],
                  child: FutureBuilder<LocalWorkspace?>(
                    future: _workspace,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _StartupError(
                          message: snapshot.error.toString(),
                        );
                      }
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.data == null) {
                        return FirstRunSetup(
                          onComplete: _reloadWorkspace,
                          onOpenDemo: _openDemo,
                          errorMessage: _startupError,
                        );
                      }
                      if (!_authenticated) {
                        return ProfileLoginScreen(
                          onAuthenticated: _onAuthenticated,
                          onOpenDemo: _openDemo,
                          errorMessage: _startupError,
                        );
                      }
                      return DesktopShell(onLogout: _logout);
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Set<DesktopModule> _allowedModules(LocalDatabase database) {
    final allowed = <DesktopModule>{};
    void addIf(String permission, DesktopModule module) {
      if (database.hasPermission(permission)) allowed.add(module);
    }

    addIf('dashboard.view', DesktopModule.dashboard);
    addIf('tables.manage', DesktopModule.tables);
    addIf('sales.create', DesktopModule.pos);
    addIf('production.view', DesktopModule.orders);
    addIf('inventory.manage', DesktopModule.inventory);
    addIf('cash.manage', DesktopModule.cash);
    addIf('reports.view', DesktopModule.reports);
    addIf('audit.view', DesktopModule.audit);
    addIf('settings.manage', DesktopModule.settings);
    return allowed;
  }
}

class _DatabaseUnavailable extends StatelessWidget {
  const _DatabaseUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline),
                SizedBox(height: 12),
                Text('La base local no está disponible'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: SelectableText('No se pudo iniciar: $message')),
  );
}

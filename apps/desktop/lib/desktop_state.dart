import 'package:data_local/data_local.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DesktopAppearanceModel extends ChangeNotifier {
  DesktopAppearanceModel({LocalDatabase? database})
    : _database = database,
      _themeMode = _readThemeMode(database);

  static const _preferenceKey = 'desktop.theme_mode';

  LocalDatabase? _database;
  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  bool get isDark => _themeMode == ThemeMode.dark;

  void attachDatabase(LocalDatabase? database) {
    _database = database;
    _themeMode = _readThemeMode(database);
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    _database?.setLocalPreference(_preferenceKey, mode.name);
    notifyListeners();
  }

  void toggle({bool systemIsDark = false}) {
    final dark =
        _themeMode == ThemeMode.dark ||
        (_themeMode == ThemeMode.system && systemIsDark);
    setThemeMode(dark ? ThemeMode.light : ThemeMode.dark);
  }

  static ThemeMode _readThemeMode(LocalDatabase? database) {
    final savedMode = database?.getLocalPreference(_preferenceKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == savedMode,
      orElse: () => ThemeMode.dark,
    );
  }
}

class DesktopNavigationModel extends ChangeNotifier {
  DesktopNavigationModel({Set<DesktopModule>? allowedModules})
    : allowedModules = Set.unmodifiable(
        allowedModules ?? DesktopModule.values.toSet(),
      ),
      _activeModule = _initialModule(allowedModules),
      _visitedModules = {_initialModule(allowedModules)};

  final Set<DesktopModule> allowedModules;
  DesktopModule _activeModule;
  final Set<DesktopModule> _visitedModules;

  DesktopModule get activeModule => _activeModule;
  Set<DesktopModule> get visitedModules => Set.unmodifiable(_visitedModules);

  void select(DesktopModule module) {
    if (!allowedModules.contains(module)) return;
    if (_activeModule == module) return;
    _activeModule = module;
    _visitedModules.add(module);
    notifyListeners();
  }

  static DesktopModule _initialModule(Set<DesktopModule>? allowedModules) {
    final available = allowedModules ?? DesktopModule.values.toSet();
    return DesktopModule.values.firstWhere(
      available.contains,
      orElse: () => DesktopModule.dashboard,
    );
  }
}

enum DesktopModule {
  dashboard,
  tables,
  pos,
  orders,
  inventory,
  cash,
  reports,
  audit,
  settings,
}

void watchDesktopNavigation(BuildContext context) {
  context.watch<DesktopNavigationModel>();
}

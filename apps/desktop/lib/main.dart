import 'dart:async';
import 'dart:io';

import 'package:data_local/data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'services/desktop_sync_service.dart';
import 'services/rpc_invoker.dart';
import 'services/supabase_config.dart';
import 'services/supabase_sync_transport.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final directory = await getApplicationSupportDirectory();
  final dataDirectory = Directory(
    '${directory.path}${Platform.pathSeparator}Caffe Amalfi POS',
  );
  await dataDirectory.create(recursive: true);
  final database = await LocalDatabase.open(
    '${dataDirectory.path}${Platform.pathSeparator}amalfi_pos.sqlite3',
  );

  final syncService = await _openSyncService(database, dataDirectory);
  if (syncService != null) {
    if (syncService.restoreWarning != null) {
      debugPrint(syncService.restoreWarning);
    }
    _startSync(syncService, database);
  }

  runApp(AmalfiDesktopApp(database: database));
}

Future<DesktopSyncService?> _openSyncService(
  LocalDatabase database,
  Directory dataDirectory,
) async {
  final SupabaseConfig config;
  try {
    final configured = SupabaseConfig.fromEnvironment();
    if (configured == null) return null;
    config = configured;
  } on ArgumentError catch (error) {
    debugPrint('Configuración Supabase inválida: ${error.message}');
    return null;
  }

  final invoker = SupabaseRpcInvoker(
    config: config,
    accessTokenProvider: () async =>
        database.getLocalPreference('supabase.access_token'),
  );
  return DesktopSyncService.open(
    database: database,
    transport: SupabaseSyncTransport(invoker: invoker),
    snapshotPath:
        '${dataDirectory.path}${Platform.pathSeparator}sync_state.json',
  );
}

void _startSync(DesktopSyncService service, LocalDatabase database) {
  Future<void> run() async {
    final token = database.getLocalPreference('supabase.access_token');
    if (token == null || token.trim().isEmpty) return;
    try {
      final summary = await service.synchronize();
      if (summary.warning != null) debugPrint(summary.warning);
    } catch (error) {
      debugPrint('Sincronización no disponible: $error');
    }
  }

  unawaited(run());
  Timer.periodic(const Duration(seconds: 45), (_) => unawaited(run()));
}

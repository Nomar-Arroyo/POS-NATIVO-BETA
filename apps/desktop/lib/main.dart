import 'dart:io';

import 'package:data_local/data_local.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app.dart';

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

  runApp(AmalfiDesktopApp(database: database));
}

import 'package:flutter/material.dart';

void main() {
  runApp(const AmalfiMobileApp());
}

class AmalfiMobileApp extends StatelessWidget {
  const AmalfiMobileApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Café Amalfi',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF079F9F),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    ),
    home: const _MobileScaffoldHome(),
  );
}

class _MobileScaffoldHome extends StatelessWidget {
  const _MobileScaffoldHome();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Café Amalfi')),
    body: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Aplicación móvil en preparación',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
}

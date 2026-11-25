import 'package:amalfi_brand_assets/amalfi_brand_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('brand images and application icon sizes are bundled', () async {
    final assets = [
      AmalfiBrandAssets.logo,
      AmalfiBrandAssets.brandSignature,
      AmalfiBrandAssets.dashboardMotto,
      AmalfiBrandAssets.dashboardBackground,
      AmalfiBrandAssets.coffeeBackground,
      AmalfiBrandAssets.coffeeSceneBackground,
      AmalfiBrandAssets.appIcon192,
      AmalfiBrandAssets.appIcon256,
      AmalfiBrandAssets.appIcon512,
      AmalfiBrandAssets.appIcon,
      for (final mode in ['light', 'dark'])
        'packages/amalfi_brand_assets/assets/icons/png/$mode/dashboard.png',
    ];
    for (final asset in assets) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: 'Missing $asset');
    }
  });

  testWidgets('all branded SVG icons load in a Flutter asset bundle', (
    tester,
  ) async {
    for (final name in AmalfiIconName.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AmalfiIcon(name: name, color: Colors.teal),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Failed to load $name');
    }
  });
}

import 'package:amalfi_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mobile scaffold renders its development state', (tester) async {
    await tester.pumpWidget(const AmalfiMobileApp());

    expect(find.text('Café Amalfi'), findsOneWidget);
    expect(find.text('Aplicación móvil en preparación'), findsOneWidget);
  });
}

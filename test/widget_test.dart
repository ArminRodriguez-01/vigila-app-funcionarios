import 'package:flutter_test/flutter_test.dart';
import 'package:vigila_funcionarios/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VigilaFuncionariosApp());
    expect(find.byType(VigilaFuncionariosApp), findsOneWidget);
  });
}

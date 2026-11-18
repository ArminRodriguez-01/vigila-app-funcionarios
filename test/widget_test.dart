import 'package:flutter_test/flutter_test.dart';
import 'package:vigila_funcionarios/core/auth/auth_controller.dart';
import 'package:vigila_funcionarios/core/auth/mock_auth_repository.dart';
import 'package:vigila_funcionarios/core/auth/sesion_storage.dart';
import 'package:vigila_funcionarios/main.dart';

AuthController _auth() =>
    AuthController(repositorio: MockAuthRepository(), storage: MemorySesionStorage());

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(VigilaFuncionariosApp(auth: _auth()));
    expect(find.byType(VigilaFuncionariosApp), findsOneWidget);
  });

  testWidgets('sin sesión la app abre en el login, no en la lista', (WidgetTester tester) async {
    final auth = _auth();
    await auth.restaurar();

    await tester.pumpWidget(VigilaFuncionariosApp(auth: auth));

    expect(find.text('Ingresar'), findsOneWidget);
    expect(find.text('Municipalidad de Victoria • Cuadrilla'), findsNothing);
  });
}

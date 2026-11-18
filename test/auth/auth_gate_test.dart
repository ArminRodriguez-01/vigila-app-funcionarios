import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigila_funcionarios/core/auth/auth_controller.dart';
import 'package:vigila_funcionarios/core/auth/auth_gate.dart';
import 'package:vigila_funcionarios/core/auth/mock_auth_repository.dart';
import 'package:vigila_funcionarios/core/auth/sesion_storage.dart';

class ControllerEspia extends AuthController {
  ControllerEspia() : super(repositorio: MockAuthRepository(), storage: MemorySesionStorage());
  int renovaciones = 0;

  @override
  Future<void> renovarSiCorresponde() {
    renovaciones++;
    return super.renovarSiCorresponde();
  }
}

AuthController _nuevo() =>
    AuthController(repositorio: MockAuthRepository(), storage: MemorySesionStorage());

const _boton = Key('boton_ingresar');

Widget _app(AuthController controller, {Widget? hijo}) => MaterialApp(
      home: AuthGate(controller: controller, child: hijo ?? const Scaffold(body: Text('LISTA'))),
    );

Future<void> _ingresar(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('campo_correo')), 'demo@victoria.cl');
  await tester.enterText(find.byKey(const Key('campo_clave')), 'demo-1234');
  await tester.tap(find.byKey(_boton));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mientras se restaura la sesión muestra un indicador de carga', (tester) async {
    await tester.pumpWidget(_app(_nuevo()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('LISTA'), findsNothing);
    expect(find.byKey(_boton), findsNothing);
  });

  testWidgets('sin sesión muestra el login y tras ingresar muestra la app', (tester) async {
    final controller = _nuevo();
    await controller.restaurar();
    await tester.pumpWidget(_app(controller));

    expect(find.byKey(_boton), findsOneWidget);
    expect(find.text('LISTA'), findsNothing);

    await _ingresar(tester);

    expect(find.text('LISTA'), findsOneWidget);
    expect(find.byKey(_boton), findsNothing);
  });

  testWidgets('al cerrar la sesión vuelve al login', (tester) async {
    final controller = _nuevo();
    await controller.restaurar();
    await tester.pumpWidget(_app(controller));
    await _ingresar(tester);

    await controller.cerrarSesion();
    await tester.pumpAndSettle();

    expect(find.byKey(_boton), findsOneWidget);
    expect(find.text('LISTA'), findsNothing);
  });

  testWidgets('al cerrarse la sesión se descartan las pantallas abiertas encima', (tester) async {
    final controller = _nuevo();
    await controller.restaurar();
    final hijo = Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('DETALLE'))),
          ),
          child: const Text('LISTA'),
        ),
      ),
    );
    await tester.pumpWidget(_app(controller, hijo: hijo));
    await _ingresar(tester);
    await tester.tap(find.text('LISTA'));
    await tester.pumpAndSettle();
    expect(find.text('DETALLE'), findsOneWidget);

    await controller.cerrarSesion(motivo: MotivoCierre.sesionExpirada);
    await tester.pumpAndSettle();

    expect(find.text('DETALLE'), findsNothing);
    expect(find.byKey(_boton), findsOneWidget);
    expect(find.textContaining('Tu sesión expiró'), findsOneWidget);
  });

  testWidgets('al volver a primer plano pide renovar la sesión', (tester) async {
    final controller = ControllerEspia();
    await controller.restaurar();
    await tester.pumpWidget(_app(controller));
    final antes = controller.renovaciones;

    // Secuencia real de Android al ir a segundo plano y volver (Flutter valida las transiciones).
    for (final estado in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(estado);
    }

    expect(controller.renovaciones, antes + 1);
  });
}

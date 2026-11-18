import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vigila_funcionarios/core/auth/auth_controller.dart';
import 'package:vigila_funcionarios/core/auth/mock_auth_repository.dart';
import 'package:vigila_funcionarios/core/auth/sesion.dart';
import 'package:vigila_funcionarios/core/auth/sesion_storage.dart';
import 'package:vigila_funcionarios/screens/login_screen.dart';

class RepoContador extends MockAuthRepository {
  RepoContador({super.latencia});
  int logins = 0;

  @override
  Future<Sesion> iniciarSesion(String email, String password) {
    logins++;
    return super.iniciarSesion(email, password);
  }
}

const _correo = Key('campo_correo');
const _clave = Key('campo_clave');
const _boton = Key('boton_ingresar');

Future<void> _mostrar(WidgetTester tester, AuthController controller) async {
  await tester.pumpWidget(MaterialApp(home: LoginScreen(controller: controller)));
}

void main() {
  late RepoContador repo;
  late AuthController controller;

  setUp(() {
    repo = RepoContador();
    controller = AuthController(repositorio: repo, storage: MemorySesionStorage());
  });

  testWidgets('con los campos vacíos muestra los avisos y no llama al servidor', (tester) async {
    await _mostrar(tester, controller);

    await tester.tap(find.byKey(_boton));
    await tester.pump();

    expect(find.text('Ingresa tu correo'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
    expect(repo.logins, 0);
  });

  testWidgets('un correo sin @ muestra "Ingresa un correo válido"', (tester) async {
    await _mostrar(tester, controller);

    await tester.enterText(find.byKey(_correo), 'sin-arroba');
    await tester.enterText(find.byKey(_clave), 'x');
    await tester.tap(find.byKey(_boton));
    await tester.pump();

    expect(find.text('Ingresa un correo válido'), findsOneWidget);
    expect(repo.logins, 0);
  });

  testWidgets('con clave incorrecta muestra "Correo o contraseña incorrectos."', (tester) async {
    await _mostrar(tester, controller);

    await tester.enterText(find.byKey(_correo), 'demo@victoria.cl');
    await tester.enterText(find.byKey(_clave), 'mala');
    await tester.tap(find.byKey(_boton));
    await tester.pumpAndSettle();

    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(controller.estado, isNot(EstadoAuth.autenticado));
  });

  testWidgets('con el motivo sesionExpirada muestra el aviso "Tu sesión expiró"', (tester) async {
    await controller.iniciarSesion('demo@victoria.cl', 'demo-1234');
    await controller.cerrarSesion(motivo: MotivoCierre.sesionExpirada);

    await _mostrar(tester, controller);

    expect(find.textContaining('Tu sesión expiró'), findsOneWidget);
  });

  testWidgets('con el motivo cuentaInactiva avisa que la cuenta fue desactivada', (tester) async {
    await controller.iniciarSesion('demo@victoria.cl', 'demo-1234');
    await controller.cerrarSesion(motivo: MotivoCierre.cuentaInactiva);

    await _mostrar(tester, controller);

    expect(find.textContaining('desactivada'), findsOneWidget);
  });

  testWidgets('sin motivo de cierre no muestra ningún aviso de sesión', (tester) async {
    await _mostrar(tester, controller);

    expect(find.textContaining('Tu sesión expiró'), findsNothing);
    expect(find.textContaining('desactivada'), findsNothing);
  });

  testWidgets('mientras inicia sesión el botón queda deshabilitado', (tester) async {
    final lento = RepoContador(latencia: const Duration(milliseconds: 100));
    controller = AuthController(repositorio: lento, storage: MemorySesionStorage());
    await _mostrar(tester, controller);

    await tester.enterText(find.byKey(_correo), 'demo@victoria.cl');
    await tester.enterText(find.byKey(_clave), 'demo-1234');
    await tester.tap(find.byKey(_boton));
    await tester.pump();

    expect(tester.widget<FilledButton>(find.byKey(_boton)).onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 150));
    expect(lento.logins, 1);
  });

  testWidgets('el botón del ojo muestra y oculta la contraseña', (tester) async {
    await _mostrar(tester, controller);

    TextField campo() => tester.widget<TextField>(
          find.descendant(of: find.byKey(_clave), matching: find.byType(TextField)),
        );
    expect(campo().obscureText, isTrue);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();

    expect(campo().obscureText, isFalse);
  });
}

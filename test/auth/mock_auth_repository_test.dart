import 'package:flutter_test/flutter_test.dart';
import 'package:vigila_funcionarios/core/auth/auth_config.dart';
import 'package:vigila_funcionarios/core/auth/auth_exceptions.dart';
import 'package:vigila_funcionarios/core/auth/mock_auth_repository.dart';

void main() {
  late DateTime ahora;
  late MockAuthRepository repo;

  setUp(() {
    ahora = DateTime.utc(2026, 11, 17, 12);
    repo = MockAuthRepository(ahora: () => ahora);
  });

  test('login correcto devuelve una sesión de 7 días', () async {
    final s = await repo.iniciarSesion('demo@victoria.cl', 'demo-1234');

    expect(s.expiraEn, ahora.add(kDuracionSesion));
    expect(kDuracionSesion, const Duration(days: 7));
    expect(s.funcionario.email, 'demo@victoria.cl');
    expect(s.token, isNotEmpty);
  });

  test('el correo se compara sin mayúsculas ni espacios', () async {
    final s = await repo.iniciarSesion('  Demo@Victoria.CL ', 'demo-1234');

    expect(s.funcionario.email, 'demo@victoria.cl');
  });

  test('login con clave incorrecta lanza CredencialesInvalidasException', () {
    expect(
      repo.iniciarSesion('demo@victoria.cl', 'otra'),
      throwsA(isA<CredencialesInvalidasException>()),
    );
  });

  test('login con correo desconocido lanza CredencialesInvalidasException', () {
    expect(
      repo.iniciarSesion('nadie@victoria.cl', 'demo-1234'),
      throwsA(isA<CredencialesInvalidasException>()),
    );
  });

  test('renovar a los 3 días entrega token nuevo con expiración día 3 + 7', () async {
    final primera = await repo.iniciarSesion('demo@victoria.cl', 'demo-1234');
    ahora = ahora.add(const Duration(days: 3));

    final renovada = await repo.renovar(primera.token);

    expect(renovada.token, isNot(primera.token));
    expect(renovada.expiraEn, DateTime.utc(2026, 11, 27, 12));
  });

  test('renovar con la sesión vencida (7 días + 1 s) lanza SesionExpiradaException', () async {
    final s = await repo.iniciarSesion('demo@victoria.cl', 'demo-1234');
    ahora = ahora.add(kDuracionSesion + const Duration(seconds: 1));

    expect(repo.renovar(s.token), throwsA(isA<SesionExpiradaException>()));
  });

  test('renovar justo en el instante de expiración también está vencida', () async {
    final s = await repo.iniciarSesion('demo@victoria.cl', 'demo-1234');
    ahora = ahora.add(kDuracionSesion);

    expect(repo.renovar(s.token), throwsA(isA<SesionExpiradaException>()));
  });

  test('renovar con token desconocido lanza SesionExpiradaException', () {
    expect(repo.renovar('token-inventado'), throwsA(isA<SesionExpiradaException>()));
  });

  test('tras cerrarSesion el token ya no se puede renovar', () async {
    final s = await repo.iniciarSesion('demo@victoria.cl', 'demo-1234');

    await repo.cerrarSesion(s.token);

    expect(repo.renovar(s.token), throwsA(isA<SesionExpiradaException>()));
  });
}

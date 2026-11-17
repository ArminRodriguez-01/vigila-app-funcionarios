import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vigila_funcionarios/core/auth/auth_exceptions.dart';
import 'package:vigila_funcionarios/core/auth/http_auth_repository.dart';

const _base = 'https://test.local/api/v1';
final _ahora = DateTime.utc(2026, 11, 17, 12);

Map<String, dynamic> _cuerpoSesion({String token = 'nuevo'}) => {
      'access_token': token,
      'token_type': 'bearer',
      'expira_en_segundos': 604800,
      'funcionario': {
        'id': '1',
        'email': 'ana@victoria.cl',
        'nombre': 'Ana',
        'rol': 'funcionario',
        'activo': true,
      },
    };

http.Response _json(Object cuerpo, int status) => http.Response(
      jsonEncode(cuerpo),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _error(int status, String codigo, [String mensaje = 'Mensaje del servidor']) =>
    _json({'codigo': codigo, 'mensaje': mensaje}, status);

HttpAuthRepository _repo(Future<http.Response> Function(http.Request) handler) =>
    HttpAuthRepository(client: MockClient(handler), ahora: () => _ahora, baseUrl: _base);

void main() {
  test('iniciarSesion hace POST a /cuadrilla/login con email y password', () async {
    late http.Request visto;
    final repo = _repo((req) async {
      visto = req;
      return _json(_cuerpoSesion(), 200);
    });

    final sesion = await repo.iniciarSesion('ana@victoria.cl', 'clave');

    expect(visto.method, 'POST');
    expect(visto.url.toString(), '$_base/cuadrilla/login');
    expect(visto.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(visto.body), {'email': 'ana@victoria.cl', 'password': 'clave'});
    expect(sesion.token, 'nuevo');
    expect(sesion.expiraEn, DateTime.utc(2026, 11, 24, 12));
    expect(sesion.funcionario.nombre, 'Ana');
  });

  test('renovar hace POST a /cuadrilla/sesion/renovar con Authorization: Bearer', () async {
    late http.Request visto;
    final repo = _repo((req) async {
      visto = req;
      return _json(_cuerpoSesion(token: 'renovado'), 200);
    });

    final sesion = await repo.renovar('viejo');

    expect(visto.method, 'POST');
    expect(visto.url.toString(), '$_base/cuadrilla/sesion/renovar');
    expect(visto.headers['Authorization'], 'Bearer viejo');
    expect(sesion.token, 'renovado');
  });

  test('cerrarSesion hace POST a /cuadrilla/logout con el Bearer y acepta 204', () async {
    late http.Request visto;
    final repo = _repo((req) async {
      visto = req;
      return http.Response('', 204);
    });

    await repo.cerrarSesion('tok');

    expect(visto.method, 'POST');
    expect(visto.url.toString(), '$_base/cuadrilla/logout');
    expect(visto.headers['Authorization'], 'Bearer tok');
  });

  test('401 credenciales_invalidas lanza CredencialesInvalidasException con el mensaje del servidor', () {
    final repo = _repo((_) async => _error(401, 'credenciales_invalidas', 'Clave mala del servidor'));

    expect(
      repo.iniciarSesion('a@b.cl', 'x'),
      throwsA(isA<CredencialesInvalidasException>()
          .having((e) => e.mensaje, 'mensaje', 'Clave mala del servidor')),
    );
  });

  test('401 sesion_expirada y 401 no_autenticado en renovar lanzan SesionExpiradaException', () async {
    for (final codigo in ['sesion_expirada', 'no_autenticado']) {
      final repo = _repo((_) async => _error(401, codigo));
      await expectLater(repo.renovar('t'), throwsA(isA<SesionExpiradaException>()));
    }
  });

  test('401 cuenta_inactiva lanza CuentaInactivaException', () {
    final repo = _repo((_) async => _error(401, 'cuenta_inactiva'));

    expect(repo.renovar('t'), throwsA(isA<CuentaInactivaException>()));
  });

  test('401 sin código: en login son credenciales inválidas, en renovar sesión expirada', () async {
    final repo = _repo((_) async => http.Response('', 401));

    await expectLater(repo.iniciarSesion('a@b.cl', 'x'), throwsA(isA<CredencialesInvalidasException>()));
    await expectLater(repo.renovar('t'), throwsA(isA<SesionExpiradaException>()));
  });

  test('429 lanza DemasiadosIntentosException', () {
    final repo = _repo((_) async => http.Response('', 429));

    expect(repo.iniciarSesion('a@b.cl', 'x'), throwsA(isA<DemasiadosIntentosException>()));
  });

  test('ClientException y SocketException lanzan SinConexionException', () async {
    final fallas = <Object>[http.ClientException('sin red'), const SocketException('sin red')];
    for (final falla in fallas) {
      final repo = _repo((_) async => throw falla);
      await expectLater(repo.renovar('t'), throwsA(isA<SinConexionException>()));
    }
  });

  test('un TimeoutException lanza ServidorLentoException y no culpa a la conexión del usuario', () {
    final repo = _repo((_) async => throw TimeoutException('lento'));

    expect(
      repo.iniciarSesion('a@b.cl', 'x'),
      throwsA(isA<ServidorLentoException>().having((e) => e.mensaje, 'mensaje', contains('tardando'))),
    );
  });

  test('el login espera más que las demás llamadas (arranque en frío del servidor)', () async {
    final repo = HttpAuthRepository(
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        return _json(_cuerpoSesion(), 200);
      }),
      ahora: () => _ahora,
      baseUrl: _base,
      timeoutLogin: const Duration(milliseconds: 600),
      timeoutRapido: const Duration(milliseconds: 50),
    );

    expect((await repo.iniciarSesion('a@b.cl', 'x')).token, 'nuevo');
    await expectLater(repo.renovar('t'), throwsA(isA<ServidorLentoException>()));
  });

  test('por defecto el login espera al menos 45 segundos', () {
    expect(HttpAuthRepository.timeoutLoginPorDefecto, greaterThanOrEqualTo(const Duration(seconds: 45)));
  });

  test('500 lanza ErrorServidorException con el status', () {
    final repo = _repo((_) async => http.Response('boom', 500));

    expect(
      repo.renovar('t'),
      throwsA(isA<ErrorServidorException>().having((e) => e.status, 'status', 500)),
    );
  });

  test('200 con cuerpo que no es JSON lanza ErrorServidorException (no revienta)', () {
    final repo = _repo((_) async => http.Response('<html>', 200));

    expect(repo.iniciarSesion('a@b.cl', 'x'), throwsA(isA<ErrorServidorException>()));
  });

  test('200 con JSON sin access_token lanza ErrorServidorException', () {
    final repo = _repo((_) async => _json({'funcionario': {}}, 200));

    expect(repo.renovar('t'), throwsA(isA<ErrorServidorException>()));
  });
}

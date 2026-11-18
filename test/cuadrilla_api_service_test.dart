import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vigila_funcionarios/services/cuadrilla_api_service.dart';

const _incidenciaJson = {
  'id': 'r1',
  'categoria': 'luminaria_apagada',
  'estado': 'en_revision',
  'creado_en': '2026-11-17T12:00:00Z',
};

http.Response _json(Object cuerpo, [int status = 200]) => http.Response(
      jsonEncode(cuerpo),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  late List<http.Request> vistas;
  late int sesionesInvalidas;

  CuadrillaApiService servicio(
    http.Response Function(http.Request) responder, {
    String? token,
  }) {
    vistas = [];
    sesionesInvalidas = 0;
    final s = CuadrillaApiService(
      client: MockClient((req) async {
        vistas.add(req);
        return responder(req);
      }),
    );
    s.tokenProvider = () => token;
    s.onNoAutorizado = () => sesionesInvalidas++;
    return s;
  }

  test('listarIncidencias envía Authorization: Bearer cuando hay token', () async {
    final s = servicio((_) => _json({'items': []}), token: 'tok');

    await s.listarIncidencias();

    expect(vistas.single.headers['Authorization'], 'Bearer tok');
    expect(vistas.single.url.path, endsWith('/cuadrilla/reportes'));
  });

  test('sin token no se envía el header Authorization', () async {
    final s = servicio((_) => _json({'items': []}));

    await s.listarIncidencias();

    expect(vistas.single.headers.containsKey('Authorization'), isFalse);
  });

  test('obtenerDetalle también envía el Bearer', () async {
    final s = servicio((_) => _json(_incidenciaJson), token: 'tok');

    final incidencia = await s.obtenerDetalle('r1');

    expect(vistas.single.headers['Authorization'], 'Bearer tok');
    expect(incidencia.id, 'r1');
  });

  test('actualizarEstado envía el Bearer, el JSON y el cuerpo esperado', () async {
    final s = servicio((_) => _json(_incidenciaJson), token: 'tok');

    await s.actualizarEstado(id: 'r1', nuevoEstado: 'resuelto', respuestaMunicipal: 'Listo');

    final req = vistas.single;
    expect(req.method, 'POST');
    expect(req.headers['Authorization'], 'Bearer tok');
    expect(req.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(req.body), {'estado': 'resuelto', 'respuesta_municipal': 'Listo'});
  });

  test('una respuesta 401 llama a onNoAutorizado una vez y lanza el aviso de sesión expirada', () async {
    final s = servicio((_) => http.Response('', 401), token: 'tok');

    await expectLater(s.listarIncidencias(), throwsA('Tu sesión expiró. Ingresa de nuevo.'));

    expect(sesionesInvalidas, 1);
  });

  test('el 401 también se detecta en obtenerDetalle y actualizarEstado', () async {
    final s = servicio((_) => http.Response('', 401), token: 'tok');

    await expectLater(s.obtenerDetalle('r1'), throwsA('Tu sesión expiró. Ingresa de nuevo.'));
    await expectLater(
      s.actualizarEstado(id: 'r1', nuevoEstado: 'resuelto'),
      throwsA('Tu sesión expiró. Ingresa de nuevo.'),
    );

    expect(sesionesInvalidas, 2);
  });

  test('una respuesta 200 no llama a onNoAutorizado', () async {
    final s = servicio((_) => _json({'items': []}), token: 'tok');

    await s.listarIncidencias();

    expect(sesionesInvalidas, 0);
  });

  test('otros errores conservan su mensaje y no cierran la sesión', () async {
    final s = servicio((_) => http.Response('boom', 500), token: 'tok');

    await expectLater(s.listarIncidencias(), throwsA('Error al obtener incidencias (500)'));

    expect(sesionesInvalidas, 0);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:vigila_funcionarios/core/auth/sesion.dart';

Map<String, dynamic> _respuesta({int segundos = 604800}) => {
      'access_token': 't',
      'token_type': 'bearer',
      'expira_en_segundos': segundos,
      'funcionario': {
        'id': '1',
        'email': 'a@b.cl',
        'nombre': 'Ana',
        'rol': 'funcionario',
        'activo': true,
      },
    };

void main() {
  test('desdeRespuesta calcula expiraEn con expira_en_segundos', () {
    final s = Sesion.desdeRespuesta(_respuesta(), DateTime.utc(2026, 11, 17, 12));

    expect(s.token, 't');
    expect(s.expiraEn, DateTime.utc(2026, 11, 24, 12));
    expect(s.funcionario.nombre, 'Ana');
    expect(s.funcionario.email, 'a@b.cl');
    expect(s.funcionario.rol, 'funcionario');
  });

  test('estaVencida: en el instante exacto de expiración ya está vencida', () {
    final expira = DateTime.utc(2026, 11, 24, 12);
    final s = Sesion.desdeRespuesta(_respuesta(), DateTime.utc(2026, 11, 17, 12));

    expect(s.estaVencida(expira), isTrue);
    expect(s.estaVencida(expira.subtract(const Duration(seconds: 1))), isFalse);
    expect(s.estaVencida(expira.add(const Duration(seconds: 1))), isTrue);
  });

  test('toJsonString/tryParse ida y vuelta devuelve una Sesion igual', () {
    final original = Sesion.desdeRespuesta(_respuesta(), DateTime.utc(2026, 11, 17, 12));

    final copia = Sesion.tryParse(original.toJsonString());

    expect(copia, original);
    expect(copia.hashCode, original.hashCode);
  });

  test('tryParse devuelve null con texto corrupto o JSON incompleto', () {
    expect(Sesion.tryParse('basura'), isNull);
    expect(Sesion.tryParse(''), isNull);
    expect(Sesion.tryParse('{"token": 1}'), isNull);
    expect(Sesion.tryParse('[1, 2]'), isNull);
    expect(
      Sesion.tryParse(
        '{"token":"t","expira_en":"no-es-fecha","funcionario":{"id":"1","email":"a","nombre":"n","rol":"r"}}',
      ),
      isNull,
    );
  });
}

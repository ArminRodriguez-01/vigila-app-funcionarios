import 'package:flutter_test/flutter_test.dart';
import 'package:vigila_funcionarios/core/actualizacion/comparar_versiones.dart';

void main() {
  test('detecta versiones más nuevas', () {
    expect(esVersionMasNueva('1.0.1', '1.0.0'), isTrue);
    expect(esVersionMasNueva('1.1.0', '1.0.9'), isTrue);
    expect(esVersionMasNueva('2.0.0', '1.9.9'), isTrue);
    expect(esVersionMasNueva('1.10.0', '1.9.0'), isTrue); // numérico, no por texto
  });

  test('misma versión o más vieja no cuenta', () {
    expect(esVersionMasNueva('1.0.0', '1.0.0'), isFalse);
    expect(esVersionMasNueva('1.0.0+5', '1.0.0'), isFalse);
    expect(esVersionMasNueva('0.9.0', '1.0.0'), isFalse);
  });

  test('acepta prefijo v, sufijos y versiones cortas', () {
    expect(esVersionMasNueva('v1.2.0', '1.1.0'), isTrue);
    expect(esVersionMasNueva('1.2', '1.1.5'), isTrue);
    expect(esVersionMasNueva('1.2.0-beta', '1.1.0'), isTrue);
  });

  test('versiones inválidas nunca bloquean', () {
    expect(esVersionMasNueva('abc', '1.0.0'), isFalse);
    expect(esVersionMasNueva('1.0.0', 'xyz'), isFalse);
    expect(esVersionMasNueva('', '1.0.0'), isFalse);
  });
}

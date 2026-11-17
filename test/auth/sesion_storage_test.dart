import 'package:flutter_test/flutter_test.dart';
import 'package:vigila_funcionarios/core/auth/sesion.dart';
import 'package:vigila_funcionarios/core/auth/sesion_storage.dart';

Sesion _sesion(String token) => Sesion(
      token: token,
      expiraEn: DateTime.utc(2026, 11, 24, 12),
      funcionario: const Funcionario(id: '1', email: 'a@b.cl', nombre: 'Ana'),
    );

void main() {
  test('MemorySesionStorage: leer inicial devuelve null', () async {
    expect(await MemorySesionStorage().leer(), isNull);
  });

  test('MemorySesionStorage: guardar y leer devuelve la misma sesión', () async {
    final storage = MemorySesionStorage();

    await storage.guardar(_sesion('abc'));

    expect(await storage.leer(), _sesion('abc'));
  });

  test('MemorySesionStorage: guardar de nuevo reemplaza la sesión anterior', () async {
    final storage = MemorySesionStorage();

    await storage.guardar(_sesion('uno'));
    await storage.guardar(_sesion('dos'));

    expect((await storage.leer())?.token, 'dos');
  });

  test('MemorySesionStorage: borrar deja el almacenamiento vacío', () async {
    final storage = MemorySesionStorage();
    await storage.guardar(_sesion('abc'));

    await storage.borrar();

    expect(await storage.leer(), isNull);
  });
}

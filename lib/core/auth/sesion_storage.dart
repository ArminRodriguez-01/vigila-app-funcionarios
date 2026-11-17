import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'sesion.dart';

/// Dónde se guarda la sesión entre aperturas de la app.
abstract class SesionStorage {
  Future<Sesion?> leer();
  Future<void> guardar(Sesion sesion);
  Future<void> borrar();
}

/// Para tests y para el modo mock: no persiste nada entre ejecuciones.
class MemorySesionStorage implements SesionStorage {
  Sesion? _sesion;

  @override
  Future<Sesion?> leer() async => _sesion;

  @override
  Future<void> guardar(Sesion sesion) async => _sesion = sesion;

  @override
  Future<void> borrar() async => _sesion = null;
}

/// Guarda la sesión cifrada (Keystore en Android, Keychain en iOS).
class SecureSesionStorage implements SesionStorage {
  SecureSesionStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const clave = 'sesion_funcionario';

  final FlutterSecureStorage _storage;

  @override
  Future<Sesion?> leer() async {
    try {
      final raw = await _storage.read(key: clave);
      if (raw == null) return null;
      final sesion = Sesion.tryParse(raw);
      // Valor corrupto: se descarta para no volver a leerlo.
      if (sesion == null) await _storage.delete(key: clave);
      return sesion;
    } catch (e) {
      // Si el almacenamiento seguro falla (ej.: llave del dispositivo invalidada),
      // se trata como «sin sesión»: el funcionario vuelve a ingresar, la app no se cae.
      debugPrint('No se pudo leer la sesión guardada: $e');
      return null;
    }
  }

  @override
  Future<void> guardar(Sesion sesion) => _storage.write(key: clave, value: sesion.toJsonString());

  @override
  Future<void> borrar() => _storage.delete(key: clave);
}

import 'package:flutter/foundation.dart';

import 'auth_repository.dart';
import 'http_auth_repository.dart';
import 'mock_auth_repository.dart';
import 'sesion_storage.dart';

/// Duración de la sesión: 7 días desde el último ingreso.
const Duration kDuracionSesion = Duration(days: 7);

/// El mock solo vale si se pidió y NO es un build release: un APK publicado jamás
/// debe aceptar las credenciales de demostración.
bool resolverUsarMock({required bool solicitado, required bool esRelease}) =>
    solicitado && !esRelease;

class AuthConfig {
  AuthConfig._();

  static const bool _mockSolicitado = bool.fromEnvironment('USAR_MOCK_AUTH');

  /// Para desarrollar: `flutter run --dart-define=USAR_MOCK_AUTH=true`.
  static bool get usarMock =>
      resolverUsarMock(solicitado: _mockSolicitado, esRelease: kReleaseMode);
}

/// Repositorio que usa la app: el mock solo en desarrollo, el backend real en el resto.
AuthRepository crearAuthRepository() =>
    AuthConfig.usarMock ? MockAuthRepository() : HttpAuthRepository();

/// Con el mock no se persiste nada (sus tokens viven solo en memoria); si no, almacenamiento seguro.
SesionStorage crearSesionStorage() =>
    AuthConfig.usarMock ? MemorySesionStorage() : SecureSesionStorage();

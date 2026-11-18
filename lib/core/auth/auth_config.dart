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

  /// Servicio de autenticación de funcionarios (AuthService, .NET). Los reportes siguen en
  /// [CuadrillaApiService.baseUrl] (FastAPI). Para apuntar a otro servidor:
  /// `flutter run --dart-define=AUTH_BASE_URL=http://10.0.2.2:8080/api/v1`.
  static const String baseUrl = String.fromEnvironment(
    'AUTH_BASE_URL',
    defaultValue: 'https://authlogin-7abx.onrender.com/api/v1',
  );

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

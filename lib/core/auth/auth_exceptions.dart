/// Errores del flujo de autenticación. `mensaje` está en español y se puede mostrar tal cual.
sealed class AuthException implements Exception {
  const AuthException(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Correo o contraseña incorrectos (401 `credenciales_invalidas`).
final class CredencialesInvalidasException extends AuthException {
  const CredencialesInvalidasException([String? mensaje])
      : super(mensaje ?? 'Correo o contraseña incorrectos.');
}

/// El token venció, es inválido o fue revocado (401 `sesion_expirada` / `no_autenticado`).
final class SesionExpiradaException extends AuthException {
  const SesionExpiradaException([String? mensaje])
      : super(mensaje ?? 'Tu sesión expiró. Ingresa de nuevo.');
}

/// La cuenta del funcionario fue desactivada (401 `cuenta_inactiva`).
final class CuentaInactivaException extends AuthException {
  const CuentaInactivaException([String? mensaje])
      : super(mensaje ?? 'Tu cuenta está desactivada. Contacta a tu administrador.');
}

/// Demasiados intentos de login (429).
final class DemasiadosIntentosException extends AuthException {
  const DemasiadosIntentosException([String? mensaje])
      : super(mensaje ?? 'Hiciste demasiados intentos. Espera un minuto e intenta de nuevo.');
}

/// No se pudo contactar al servidor (sin internet, timeout).
final class SinConexionException extends AuthException {
  const SinConexionException([String? mensaje])
      : super(mensaje ?? 'No hay conexión con el servidor. Revisa tu internet.');
}

/// El servidor respondió con un error inesperado (5xx o cuerpo inválido).
final class ErrorServidorException extends AuthException {
  const ErrorServidorException(this.status, [String? mensaje])
      : super(mensaje ?? 'El servidor tuvo un problema (código $status). Intenta más tarde.');

  final int status;
}

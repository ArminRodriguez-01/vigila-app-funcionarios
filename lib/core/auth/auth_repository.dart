import 'sesion.dart';

/// Puerto hacia el backend de autenticación de la cuadrilla.
/// Todos los métodos lanzan una `AuthException` (ver `auth_exceptions.dart`) ante un error.
abstract class AuthRepository {
  /// `POST /cuadrilla/login`.
  Future<Sesion> iniciarSesion(String email, String password);

  /// `POST /cuadrilla/sesion/renovar`: cambia un token aún vigente por uno nuevo de 7 días.
  Future<Sesion> renovar(String token);

  /// `POST /cuadrilla/logout`: invalida el token en el servidor.
  Future<void> cerrarSesion(String token);
}

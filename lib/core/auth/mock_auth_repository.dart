import 'auth_config.dart';
import 'auth_exceptions.dart';
import 'auth_repository.dart';
import 'sesion.dart';

/// Backend simulado en memoria, solo para desarrollo (`--dart-define=USAR_MOCK_AUTH=true`).
/// Imita el contrato de `docs/contratos-backend-auth.md`: sesiones de 7 días y renovación.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({
    DateTime Function()? ahora,
    this.latencia = Duration.zero,
    Map<String, String>? usuarios,
  })  : _ahora = ahora ?? DateTime.now,
        _usuarios = usuarios ?? const {'demo@victoria.cl': 'demo-1234'};

  final DateTime Function() _ahora;
  final Duration latencia;
  final Map<String, String> _usuarios;

  /// token -> instante en que vence.
  final Map<String, DateTime> _tokens = {};
  int _contador = 0;

  Future<void> _simularRed() async {
    if (latencia > Duration.zero) await Future<void>.delayed(latencia);
  }

  Sesion _emitir(String email) {
    final expiraEn = _ahora().add(kDuracionSesion);
    final token = 'mock-token-${_contador++}';
    _tokens[token] = expiraEn;
    return Sesion(
      token: token,
      expiraEn: expiraEn,
      funcionario: Funcionario(id: 'mock-${email.hashCode}', email: email, nombre: 'Funcionario Demo'),
    );
  }

  @override
  Future<Sesion> iniciarSesion(String email, String password) async {
    await _simularRed();
    final correo = email.trim().toLowerCase();
    if (_usuarios[correo] != password) throw const CredencialesInvalidasException();
    return _emitir(correo);
  }

  @override
  Future<Sesion> renovar(String token) async {
    await _simularRed();
    final expiraEn = _tokens[token];
    if (expiraEn == null || !expiraEn.isAfter(_ahora())) {
      throw const SesionExpiradaException();
    }
    return _emitir('demo@victoria.cl');
  }

  @override
  Future<void> cerrarSesion(String token) async {
    await _simularRed();
    _tokens.remove(token);
  }
}

import 'dart:convert';

/// Datos del funcionario que inició sesión (los que entrega el backend).
class Funcionario {
  const Funcionario({
    required this.id,
    required this.email,
    required this.nombre,
    this.rol = 'funcionario',
  });

  final String id;
  final String email;
  final String nombre;
  final String rol;

  factory Funcionario.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email'];
    final nombre = json['nombre'];
    if (id is! String || email is! String || nombre is! String) {
      throw const FormatException('Funcionario incompleto');
    }
    final rol = json['rol'];
    return Funcionario(
      id: id,
      email: email,
      nombre: nombre,
      rol: rol is String && rol.isNotEmpty ? rol : 'funcionario',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'email': email, 'nombre': nombre, 'rol': rol};

  @override
  bool operator ==(Object other) =>
      other is Funcionario &&
      other.id == id &&
      other.email == email &&
      other.nombre == nombre &&
      other.rol == rol;

  @override
  int get hashCode => Object.hash(id, email, nombre, rol);
}

/// Sesión activa: token del backend, cuándo vence y a quién pertenece.
class Sesion {
  const Sesion({required this.token, required this.expiraEn, required this.funcionario});

  final String token;
  final DateTime expiraEn;
  final Funcionario funcionario;

  /// Construye la sesión desde la respuesta de `/login` o `/sesion/renovar`.
  /// El vencimiento se calcula con `expira_en_segundos` y el reloj local [ahora].
  /// Lanza [FormatException] si la respuesta no trae los campos esperados.
  factory Sesion.desdeRespuesta(Map<String, dynamic> json, DateTime ahora) {
    final token = json['access_token'];
    final segundos = json['expira_en_segundos'];
    final funcionario = json['funcionario'];
    if (token is! String ||
        token.isEmpty ||
        segundos is! num ||
        funcionario is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de sesión incompleta');
    }
    return Sesion(
      token: token,
      expiraEn: ahora.add(Duration(seconds: segundos.toInt())),
      funcionario: Funcionario.fromJson(funcionario),
    );
  }

  /// Vencida desde el instante exacto de [expiraEn].
  bool estaVencida(DateTime ahora) => !expiraEn.isAfter(ahora);

  String toJsonString() => jsonEncode({
        'token': token,
        'expira_en': expiraEn.toUtc().toIso8601String(),
        'funcionario': funcionario.toJson(),
      });

  /// Lee una sesión guardada. Devuelve null si el texto está corrupto o incompleto
  /// (se trata como «sin sesión», nunca lanza).
  static Sesion? tryParse(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final token = json['token'];
      final expiraEn = json['expira_en'];
      final funcionario = json['funcionario'];
      if (token is! String ||
          token.isEmpty ||
          expiraEn is! String ||
          funcionario is! Map<String, dynamic>) {
        return null;
      }
      return Sesion(
        token: token,
        expiraEn: DateTime.parse(expiraEn),
        funcionario: Funcionario.fromJson(funcionario),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Sesion &&
      other.token == token &&
      other.expiraEn.isAtSameMomentAs(expiraEn) &&
      other.funcionario == funcionario;

  @override
  int get hashCode => Object.hash(token, expiraEn.toUtc().microsecondsSinceEpoch, funcionario);
}

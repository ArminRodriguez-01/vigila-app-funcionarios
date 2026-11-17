import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../services/cuadrilla_api_service.dart';
import 'auth_exceptions.dart';
import 'auth_repository.dart';
import 'sesion.dart';

/// Habla con el backend real. El contrato completo está en `docs/contratos-backend-auth.md`.
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({http.Client? client, DateTime Function()? ahora, String? baseUrl})
      : _client = client ?? http.Client(),
        _ahora = ahora ?? DateTime.now,
        _baseUrl = baseUrl ?? CuadrillaApiService.baseUrl;

  static const _timeout = Duration(seconds: 15);

  final http.Client _client;
  final DateTime Function() _ahora;
  final String _baseUrl;

  @override
  Future<Sesion> iniciarSesion(String email, String password) async {
    final respuesta = await _post(
      '/cuadrilla/login',
      cuerpo: {'email': email, 'password': password},
      esLogin: true,
    );
    return _leerSesion(respuesta);
  }

  @override
  Future<Sesion> renovar(String token) async {
    final respuesta = await _post('/cuadrilla/sesion/renovar', token: token);
    return _leerSesion(respuesta);
  }

  @override
  Future<void> cerrarSesion(String token) async {
    await _post('/cuadrilla/logout', token: token);
  }

  Future<http.Response> _post(
    String ruta, {
    Map<String, dynamic>? cuerpo,
    String? token,
    bool esLogin = false,
  }) async {
    final http.Response respuesta;
    try {
      respuesta = await _client
          .post(
            Uri.parse('$_baseUrl$ruta'),
            headers: {
              'Accept': 'application/json',
              if (cuerpo != null) 'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: cuerpo == null ? null : jsonEncode(cuerpo),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const SinConexionException();
    } on SocketException {
      throw const SinConexionException();
    } on http.ClientException {
      throw const SinConexionException();
    }

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) return respuesta;
    throw _errorDe(respuesta, esLogin: esLogin);
  }

  AuthException _errorDe(http.Response respuesta, {required bool esLogin}) {
    final cuerpo = _jsonODefecto(respuesta.body);
    final codigo = cuerpo['codigo'];
    final mensajeServidor = cuerpo['mensaje'];
    final mensaje = mensajeServidor is String && mensajeServidor.isNotEmpty ? mensajeServidor : null;

    switch (respuesta.statusCode) {
      case 401:
        return switch (codigo) {
          'credenciales_invalidas' => CredencialesInvalidasException(mensaje),
          'cuenta_inactiva' => CuentaInactivaException(mensaje),
          'sesion_expirada' || 'no_autenticado' => SesionExpiradaException(mensaje),
          _ => esLogin
              ? CredencialesInvalidasException(mensaje)
              : SesionExpiradaException(mensaje),
        };
      case 429:
        return DemasiadosIntentosException(mensaje);
      default:
        return ErrorServidorException(respuesta.statusCode);
    }
  }

  Sesion _leerSesion(http.Response respuesta) {
    try {
      final json = jsonDecode(respuesta.body);
      if (json is! Map<String, dynamic>) throw const FormatException('Se esperaba un objeto');
      return Sesion.desdeRespuesta(json, _ahora());
    } on FormatException {
      throw ErrorServidorException(respuesta.statusCode);
    }
  }

  Map<String, dynamic> _jsonODefecto(String texto) {
    try {
      final json = jsonDecode(texto);
      return json is Map<String, dynamic> ? json : const {};
    } catch (_) {
      return const {};
    }
  }
}

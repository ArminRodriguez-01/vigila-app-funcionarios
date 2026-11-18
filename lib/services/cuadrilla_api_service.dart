import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/incidencia.dart';

class CuadrillaApiService {
  CuadrillaApiService({http.Client? client}) : _client = client ?? http.Client();
  static final CuadrillaApiService instance = CuadrillaApiService();

  /// URL del backend en Render
  static const String baseUrl = 'https://vigila-app.onrender.com/api/v1';

  static const String _mensajeSesionExpirada = 'Tu sesión expiró. Ingresa de nuevo.';

  final http.Client _client;

  /// Devuelve el token de la sesión activa (o null si no hay). Se asigna al iniciar la app.
  String? Function()? tokenProvider;

  /// Se llama cuando el servidor responde 401: el token ya no sirve y hay que volver al login.
  void Function()? onNoAutorizado;

  Map<String, String> _headers({bool json = false}) {
    final token = tokenProvider?.call();
    return {
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Si la respuesta es 401 avisa a [onNoAutorizado] y corta con el mensaje de sesión expirada.
  http.Response _revisarSesion(http.Response respuesta) {
    if (respuesta.statusCode == 401) {
      onNoAutorizado?.call();
      throw _mensajeSesionExpirada;
    }
    return respuesta;
  }

  /// Obtiene la lista completa de todas las incidencias de Victoria
  Future<List<Incidencia>> listarIncidencias({String? estado}) async {
    String urlStr = '$baseUrl/cuadrilla/reportes?limit=100';
    if (estado != null && estado.isNotEmpty) {
      urlStr += '&estado=$estado';
    }

    final respuesta = _revisarSesion(
      await _client.get(Uri.parse(urlStr), headers: _headers()).timeout(const Duration(seconds: 15)),
    );

    if (respuesta.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(respuesta.body);
      final List<dynamic> items = data['items'] ?? [];
      return items.map((j) => Incidencia.fromJson(j as Map<String, dynamic>)).toList();
    } else {
      throw 'Error al obtener incidencias (${respuesta.statusCode})';
    }
  }

  /// Obtiene el detalle completo de una incidencia (con mapa y fotos)
  Future<Incidencia> obtenerDetalle(String id) async {
    final respuesta = _revisarSesion(
      await _client
          .get(Uri.parse('$baseUrl/cuadrilla/reportes/$id'), headers: _headers())
          .timeout(const Duration(seconds: 15)),
    );

    if (respuesta.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(respuesta.body);
      return Incidencia.fromJson(data);
    } else {
      throw 'No se pudo cargar la incidencia';
    }
  }

  /// Actualiza el estado de la incidencia (ej: "en_revision" o "resuelto")
  Future<Incidencia> actualizarEstado({
    required String id,
    required String nuevoEstado,
    String? respuestaMunicipal,
  }) async {
    final respuesta = _revisarSesion(
      await _client
          .post(
            Uri.parse('$baseUrl/cuadrilla/reportes/$id/estado'),
            headers: _headers(json: true),
            body: jsonEncode({
              'estado': nuevoEstado,
              'respuesta_municipal': respuestaMunicipal,
            }),
          )
          .timeout(const Duration(seconds: 15)),
    );

    if (respuesta.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(respuesta.body);
      return Incidencia.fromJson(data);
    } else {
      throw 'No se pudo actualizar el estado de la incidencia';
    }
  }
}

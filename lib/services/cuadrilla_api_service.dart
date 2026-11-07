import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/incidencia.dart';

class CuadrillaApiService {
  CuadrillaApiService._();
  static final CuadrillaApiService instance = CuadrillaApiService._();

  /// URL del backend en Render
  static const String baseUrl = 'https://vigila-app.onrender.com/api/v1';

  /// Obtiene la lista completa de todas las incidencias de Victoria
  Future<List<Incidencia>> listarIncidencias({String? estado}) async {
    String urlStr = '$baseUrl/cuadrilla/reportes?limit=100';
    if (estado != null && estado.isNotEmpty) {
      urlStr += '&estado=$estado';
    }

    final respuesta = await http.get(
      Uri.parse(urlStr),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));

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
    final respuesta = await http.get(
      Uri.parse('$baseUrl/cuadrilla/reportes/$id'),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));

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
    final respuesta = await http.post(
      Uri.parse('$baseUrl/cuadrilla/reportes/$id/estado'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'estado': nuevoEstado,
        'respuesta_municipal': respuestaMunicipal,
      }),
    ).timeout(const Duration(seconds: 15));

    if (respuesta.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(respuesta.body);
      return Incidencia.fromJson(data);
    } else {
      throw 'No se pudo actualizar el estado de la incidencia';
    }
  }
}

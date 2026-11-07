import 'package:flutter/material.dart';

enum EstadoIncidencia {
  enviado,
  enRevision,
  resuelto,
}

class Incidencia {
  final String id;
  final String categoriaCodigo;
  final String categoriaNombre;
  final String direccionTexto;
  final double latitud;
  final double longitud;
  final EstadoIncidencia estado;
  final String? respuestaMunicipal;
  final DateTime creadoEn;
  final List<String> fotos;

  const Incidencia({
    required this.id,
    required this.categoriaCodigo,
    required this.categoriaNombre,
    required this.direccionTexto,
    required this.latitud,
    required this.longitud,
    required this.estado,
    this.respuestaMunicipal,
    required this.creadoEn,
    this.fotos = const [],
  });

  factory Incidencia.fromJson(Map<String, dynamic> json) {
    // 1. Categoría
    String cod = 'otra_situacion';
    String nom = 'Incidencia reportada';
    if (json['categoria'] is Map) {
      cod = json['categoria']['codigo'] ?? cod;
      nom = json['categoria']['nombre'] ?? nom;
    } else if (json['categoria'] is String) {
      cod = json['categoria'];
      nom = cod;
    }

    // 2. Estado
    EstadoIncidencia est = EstadoIncidencia.enviado;
    final estadoStr = (json['estado'] ?? '').toString();
    if (estadoStr == 'en_revision' || estadoStr == 'enRevision') {
      est = EstadoIncidencia.enRevision;
    } else if (estadoStr == 'resuelto') {
      est = EstadoIncidencia.resuelto;
    }

    // 3. Fotos
    final List<String> listaFotos = [];
    if (json['fotos'] is List) {
      for (final f in json['fotos']) {
        if (f is Map && f['url'] != null) {
          String url = f['url'] as String;
          // Sanitización localhost si aplica
          if (url.contains('localhost:8000')) {
            url = url.replaceFirst('http://localhost:8000', 'https://vigila-app.onrender.com');
          }
          listaFotos.add(url);
        }
      }
    }

    // 4. Fechas
    DateTime fecha = DateTime.now();
    if (json['creado_en'] != null) {
      try {
        fecha = DateTime.parse(json['creado_en']);
      } catch (_) {}
    }

    return Incidencia(
      id: json['id']?.toString() ?? '',
      categoriaCodigo: cod,
      categoriaNombre: nom,
      direccionTexto: json['direccion_texto'] ?? 'Victoria, Región de la Araucanía',
      latitud: (json['latitud'] as num?)?.toDouble() ?? -38.2325,
      longitud: (json['longitud'] as num?)?.toDouble() ?? -72.3333,
      estado: est,
      respuestaMunicipal: json['respuesta_municipal'],
      creadoEn: fecha,
      fotos: listaFotos,
    );
  }

  bool get tieneFoto => fotos.isNotEmpty;
  String get direccion => direccionTexto;

  IconData get categoriaIcono {
    switch (categoriaCodigo) {
      case 'tapa_desague_abierta':
        return Icons.grid_view_rounded;
      case 'luminaria_apagada':
        return Icons.lightbulb_outline_rounded;
      case 'choque_vehiculo':
        return Icons.car_crash_outlined;
      case 'semaforo_apagado':
        return Icons.traffic_rounded;
      case 'hoyo_calzada':
        return Icons.drive_eta_outlined;
      case 'otra_situacion':
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color get categoriaColor {
    switch (categoriaCodigo) {
      case 'tapa_desague_abierta':
        return const Color(0xFF0284C7); // Celeste / azul agua
      case 'luminaria_apagada':
        return const Color(0xFFD97706); // Ámbar / amarillo
      case 'choque_vehiculo':
        return const Color(0xFFDC2626); // Rojo alerta
      case 'semaforo_apagado':
        return const Color(0xFFEA580C); // Naranja
      case 'hoyo_calzada':
        return const Color(0xFF7C3AED); // Púrpura calle
      default:
        return const Color(0xFF475569); // Gris oscuro
    }
  }

  Color get estadoColor {
    switch (estado) {
      case EstadoIncidencia.enviado:
        return const Color(0xFFDC2626); // Rojo pendiente
      case EstadoIncidencia.enRevision:
        return const Color(0xFFD97706); // Ámbar cuadrilla asignada
      case EstadoIncidencia.resuelto:
        return const Color(0xFF0B6649); // Verde esmeralda resuelto
    }
  }

  String get estadoTexto {
    switch (estado) {
      case EstadoIncidencia.enviado:
        return 'Pendiente';
      case EstadoIncidencia.enRevision:
        return 'En cuadrilla';
      case EstadoIncidencia.resuelto:
        return 'Resuelto';
    }
  }

  String tiempoTranscurrido() {
    final diff = DateTime.now().difference(creadoEn);
    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    return 'Hace ${diff.inDays} d';
  }
}

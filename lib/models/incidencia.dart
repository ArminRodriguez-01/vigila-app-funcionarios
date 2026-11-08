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
    String nom = '';
    if (json['categoria'] is Map) {
      final mapCat = json['categoria'] as Map;
      cod = mapCat['codigo']?.toString() ?? cod;
      nom = mapCat['titulo']?.toString() ?? mapCat['nombre']?.toString() ?? '';
    } else if (json['categoria'] is String) {
      cod = json['categoria'] as String;
    }

    if (nom.isEmpty || nom == cod || nom == 'Incidencia reportada') {
      nom = nombreAmigableCategoria(cod);
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

  String get descripcionTipo => descripcionTipoIncidencia(categoriaCodigo);
  String get cuadrilla => cuadrillaSugerida(categoriaCodigo);

  static String nombreAmigableCategoria(String codigo) {
    switch (codigo) {
      case 'tapa_desague_abierta':
        return 'Tapa de alcantarilla o desagüe abierta';
      case 'luminaria_apagada':
        return 'Problemas de iluminación pública';
      case 'choque_vehiculo':
        return 'Choque o accidente de tránsito';
      case 'semaforo_apagado':
        return 'Semáforo apagado o defectuoso';
      case 'hoyo_calzada':
        return 'Hoyo o bache en la calzada';
      case 'otra_situacion':
      default:
        return 'Otra situación en la vía pública';
    }
  }

  static String descripcionTipoIncidencia(String codigo) {
    switch (codigo) {
      case 'tapa_desague_abierta':
        return 'Peligro de caída o daño vehicular por tapa de sumidero rota o faltante.';
      case 'luminaria_apagada':
        return 'Luminaria apagada, foco intermitente o calle a oscuras.';
      case 'choque_vehiculo':
        return 'Accidente o colisión vehicular requiriendo despeje o apoyo vial.';
      case 'semaforo_apagado':
        return 'Cruce peligroso por semáforo fuera de servicio o defectuoso.';
      case 'hoyo_calzada':
        return 'Deformación, bache o grieta profunda en la calzada.';
      case 'otra_situacion':
      default:
        return 'Incidencia en vía pública reportada por vecino para inspección.';
    }
  }

  static String cuadrillaSugerida(String codigo) {
    switch (codigo) {
      case 'tapa_desague_abierta':
        return 'Obras Públicas / Aguas';
      case 'luminaria_apagada':
        return 'Alumbrado Público';
      case 'choque_vehiculo':
        return 'Seguridad Ciudadana / Tránsito';
      case 'semaforo_apagado':
        return 'Señalización y Tránsito';
      case 'hoyo_calzada':
        return 'Vialidad y Pavimentación';
      case 'otra_situacion':
      default:
        return 'Cuadrilla General';
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

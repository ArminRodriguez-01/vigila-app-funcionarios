import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/incidencia.dart';
import '../services/cuadrilla_api_service.dart';

class DetalleIncidenciaScreen extends StatefulWidget {
  final Incidencia incidencia;

  const DetalleIncidenciaScreen({super.key, required this.incidencia});

  @override
  State<DetalleIncidenciaScreen> createState() => _DetalleIncidenciaScreenState();
}

class _DetalleIncidenciaScreenState extends State<DetalleIncidenciaScreen> {
  late Incidencia _incidencia;
  bool _actualizando = false;
  final TextEditingController _respuestaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _incidencia = widget.incidencia;
  }

  @override
  void dispose() {
    _respuestaController.dispose();
    super.dispose();
  }

  /// Abre la ruta hacia la incidencia en Google Maps
  Future<void> _abrirGoogleMaps() async {
    final lat = _incidencia.latitud;
    final lon = _incidencia.longitud;
    final Uri urlNative = Uri.parse('google.navigation:q=$lat,$lon');
    final Uri urlWeb = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lon');

    try {
      if (await canLaunchUrl(urlNative)) {
        await launchUrl(urlNative, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(urlWeb, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir Google Maps: $e')),
        );
      }
    }
  }

  /// Abre la ruta hacia la incidencia en Waze
  Future<void> _abrirWaze() async {
    final lat = _incidencia.latitud;
    final lon = _incidencia.longitud;
    final Uri urlWazeApp = Uri.parse('waze://?ll=$lat,$lon&navigate=yes');
    final Uri urlWazeWeb = Uri.parse('https://waze.com/ul?ll=$lat,$lon&navigate=yes');

    try {
      if (await canLaunchUrl(urlWazeApp)) {
        await launchUrl(urlWazeApp, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(urlWazeWeb, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir Waze: $e')),
        );
      }
    }
  }

  /// Despliega el menú modal para elegir entre Google Maps y Waze
  void _mostrarSelectorNavegacion() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.near_me_rounded, color: Color(0xFF0F766E), size: 26),
                  SizedBox(width: 10),
                  Text(
                    '¿Cómo deseas llegar?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _incidencia.direccionTexto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4285F4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.map_rounded, color: Color(0xFF4285F4), size: 28),
                ),
                title: const Text(
                  'Google Maps',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text('Ruta recomendada y navegación paso a paso'),
                trailing: const Icon(Icons.chevron_right),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirGoogleMaps();
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF33CCFF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.directions_car_rounded, color: Color(0xFF0099FF), size: 28),
                ),
                title: const Text(
                  'Waze',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text('Ruta en tiempo real para cuadrilla vehicular'),
                trailing: const Icon(Icons.chevron_right),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _abrirWaze();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(String nuevoEstado, {String? respuesta}) async {
    setState(() {
      _actualizando = true;
    });

    try {
      final actualizada = await CuadrillaApiService.instance.actualizarEstado(
        id: _incidencia.id,
        nuevoEstado: nuevoEstado,
        respuestaMunicipal: respuesta,
      );

      if (mounted) {
        setState(() {
          _incidencia = actualizada;
          _actualizando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nuevoEstado == 'en_revision'
                  ? 'Incidencia tomada en cuadrilla'
                  : 'Incidencia marcada como resuelta exitosamente',
            ),
            backgroundColor: const Color(0xFF0B6649),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _actualizando = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar estado: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _mostrarDialogoResolver() {
    _respuestaController.text = 'Situación atendida y resuelta en terreno por la cuadrilla municipal.';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF0B6649), size: 28),
                SizedBox(width: 10),
                Text(
                  'Resolver Incidencia',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Ingresa una nota o descripción breve de la solución aplicada en terreno:',
              style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _respuestaController,
              maxLines: 3,
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Ej: Bache reparado con mezcla en frío...',
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _cambiarEstado('resuelto', respuesta: _respuestaController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B6649),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirmar y Marcar Resuelto', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final puntoGps = LatLng(_incidencia.latitud, _incidencia.longitud);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _incidencia.categoriaNombre,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const Text(
              'Detalle de Incidencia • Terreno',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F766E), // Mismo color verde esmeralda institucional
        foregroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // 1. Tarjeta de Tipo de Incidencia y Estado
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _incidencia.categoriaColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _incidencia.categoriaIcono,
                          color: _incidencia.categoriaColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _incidencia.categoriaNombre,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cuadrilla: ${_incidencia.cuadrilla}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _incidencia.estadoColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _incidencia.estadoTexto.toUpperCase(),
                          style: TextStyle(
                            color: _incidencia.estadoColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¿De qué se trata?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _incidencia.descripcionTipo,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF334155),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _incidencia.tiempoTranscurrido(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        DateFormat('d MMMM, HH:mm', 'es').format(_incidencia.creadoEn.toLocal()),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Ubicación y Botón GPS
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Dirección de la Incidencia',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _incidencia.direccionTexto,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.3),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _mostrarSelectorNavegacion,
                    icon: const Icon(Icons.navigation_rounded, size: 20),
                    label: const Text(
                      'Cómo llegar (Waze / Google Maps)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E), // Mismo verde esmeralda
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Mapa Interactivo con mejor visibilidad del entorno
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: puntoGps,
                    initialZoom: 14.8, // Zoom más amplio para que el funcionario aprecie calles aledañas y el barrio
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'cl.muni.victoria.vigila_funcionarios',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: puntoGps,
                          width: 50,
                          height: 50,
                          child: const Icon(
                            Icons.location_pin,
                            size: 48,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Fotografía de la incidencia
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.camera_alt_rounded, color: Color(0xFF0F766E), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Fotografía reportada',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_incidencia.fotos.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: InteractiveViewer(
                        panEnabled: true,
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Image.network(
                          _incidencia.fotos.first,
                          width: double.infinity,
                          height: 260,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 160,
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: Text('No se pudo cargar la imagen remota'),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'El vecino no adjuntó fotografía en este reporte',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 5. Botones de Acción (Cambiar Estado)
            if (_incidencia.estado != EstadoIncidencia.resuelto) ...[
              if (_actualizando)
                const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
              else ...[
                if (_incidencia.estado == EstadoIncidencia.enviado)
                  ElevatedButton.icon(
                    onPressed: () => _cambiarEstado('en_revision'),
                    icon: const Icon(Icons.handyman_rounded),
                    label: const Text('Tomar Incidencia (En Cuadrilla)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _mostrarDialogoResolver,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Marcar como Resuelto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B6649),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ],
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: Color(0xFF0B6649), size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Incidencia Resuelta',
                            style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          if (_incidencia.respuestaMunicipal != null)
                            Text(
                              _incidencia.respuestaMunicipal!,
                              style: const TextStyle(color: Color(0xFF047857), fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
  }
}

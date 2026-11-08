import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/incidencia.dart';
import '../services/cuadrilla_api_service.dart';
import 'detalle_incidencia_screen.dart';

class ListaIncidenciasScreen extends StatefulWidget {
  const ListaIncidenciasScreen({super.key});

  @override
  State<ListaIncidenciasScreen> createState() => _ListaIncidenciasScreenState();
}

class _ListaIncidenciasScreenState extends State<ListaIncidenciasScreen> {
  final CuadrillaApiService _apiService = CuadrillaApiService.instance;

  List<Incidencia> _todasLasIncidencias = [];
  bool _cargando = true;
  String? _error;
  String _filtroEstado = 'todos'; // 'todos', 'enviado', 'en_revision', 'resuelto'
  String _busqueda = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _cargarIncidencias();
    // Auto-refresco cada 25 segundos para tener datos al día en terreno
    _pollingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (mounted) {
        _cargarIncidencias(silencioso: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarIncidencias({bool silencioso = false}) async {
    if (!silencioso) {
      setState(() {
        _cargando = true;
        _error = null;
      });
    }

    try {
      // Siempre pedimos todas las incidencias al backend para que los contadores
      // globales de cada etiqueta ("Todas", "Pendientes", "En Cuadrilla", "Resueltas")
      // muestren la cantidad total real sin verse afectados por la tarjeta activa.
      final lista = await _apiService.listarIncidencias();
      if (mounted) {
        setState(() {
          _todasLasIncidencias = lista;
          _cargando = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted && !silencioso) {
        setState(() {
          _error = 'No se pudo conectar con el servidor municipal.\n$e';
          _cargando = false;
        });
      }
    }
  }

  // Contadores globales calculados siempre sobre el total de incidencias
  int get _totalCount => _todasLasIncidencias.length;
  int get _pendientesCount =>
      _todasLasIncidencias.where((i) => i.estado == EstadoIncidencia.enviado).length;
  int get _enCuadrillaCount =>
      _todasLasIncidencias.where((i) => i.estado == EstadoIncidencia.enRevision).length;
  int get _resueltasCount =>
      _todasLasIncidencias.where((i) => i.estado == EstadoIncidencia.resuelto).length;

  List<Incidencia> get _incidenciasFiltradas {
    // 1. Filtrar según la pestaña/chip seleccionado
    List<Incidencia> lista;
    switch (_filtroEstado) {
      case 'enviado':
        lista = _todasLasIncidencias.where((i) => i.estado == EstadoIncidencia.enviado).toList();
        break;
      case 'en_revision':
        lista = _todasLasIncidencias.where((i) => i.estado == EstadoIncidencia.enRevision).toList();
        break;
      case 'resuelto':
        lista = _todasLasIncidencias.where((i) => i.estado == EstadoIncidencia.resuelto).toList();
        break;
      case 'todos':
      default:
        lista = _todasLasIncidencias;
        break;
    }

    // 2. Filtrar por búsqueda
    if (_busqueda.trim().isEmpty) {
      return lista;
    }
    final q = _busqueda.toLowerCase().trim();
    return lista.where((inc) {
      final matchCat = inc.categoriaNombre.toLowerCase().contains(q);
      final matchDesc = inc.descripcionTipo.toLowerCase().contains(q);
      final matchCuadrilla = inc.cuadrilla.toLowerCase().contains(q);
      final matchDir = inc.direccion.toLowerCase().contains(q);
      final matchRespuesta = (inc.respuestaMunicipal ?? '').toLowerCase().contains(q);
      return matchCat || matchDesc || matchCuadrilla || matchDir || matchRespuesta;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // Slate 100
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vigila Funcionarios',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Municipalidad de Victoria • Cuadrilla',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.85),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F766E), // Teal 700 / Esmeralda municipal
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refrescar datos',
            onPressed: () => _cargarIncidencias(),
          ),
        ],
      ),
      body: SafeArea(
        top: false, // El AppBar ya protege la zona superior
        child: Column(
          children: [
            // Banner resumen y buscador
            _buildTopBanner(theme),

            // Chips de filtro por estado
            _buildFilterChips(),

            // Lista de incidencias con márgenes cómodos
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _cargarIncidencias(),
                color: const Color(0xFF0F766E),
                child: _buildListaContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBanner(ThemeData theme) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por dirección o categoría...',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.black45),
              prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF0F766E)),
              suffixIcon: _busqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _busqueda = '';
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _busqueda = val;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterChip('todos', 'Todas ($_totalCount)'),
            const SizedBox(width: 8),
            _filterChip('enviado', '🚨 Pendientes ($_pendientesCount)',
                badgeColor: const Color(0xFFEF4444)),
            const SizedBox(width: 8),
            _filterChip('en_revision', '👷 En Cuadrilla ($_enCuadrillaCount)',
                badgeColor: const Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            _filterChip('resuelto', '✅ Resueltas ($_resueltasCount)',
                badgeColor: const Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String estadoKey, String label, {Color? badgeColor}) {
    final seleccionado = _filtroEstado == estadoKey;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: seleccionado ? FontWeight.bold : FontWeight.w500,
          color: seleccionado ? Colors.white : Colors.black87,
        ),
      ),
      selected: seleccionado,
      selectedColor: badgeColor ?? const Color(0xFF0F766E),
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: seleccionado
              ? (badgeColor ?? const Color(0xFF0F766E))
              : const Color(0xFFCBD5E1),
        ),
      ),
      onSelected: (selected) {
        if (selected && _filtroEstado != estadoKey) {
          setState(() {
            _filtroEstado = estadoKey;
          });
        }
      },
    );
  }

  Widget _buildListaContent() {
    if (_cargando && _todasLasIncidencias.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0F766E)),
            SizedBox(height: 16),
            Text(
              'Cargando incidencias comunales...',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      );
    }

    if (_error != null && _todasLasIncidencias.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black87, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _cargarIncidencias(),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar conexión'),
              ),
            ],
          ),
        ),
      );
    }

    final lista = _incidenciasFiltradas;

    if (lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.teal.shade200),
            const SizedBox(height: 16),
            Text(
              _busqueda.isNotEmpty
                  ? 'No hay incidencias que coincidan con "$_busqueda"'
                  : 'No hay incidencias registradas en este estado',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.black54, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      itemCount: lista.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final inc = lista[index];
        return _buildIncidenciaCard(inc);
      },
    );
  }

  Widget _buildIncidenciaCard(Incidencia inc) {
    final fechaFormatted = DateFormat('dd/MM/yyyy HH:mm', 'es').format(inc.creadoEn.toLocal());
    final esPendiente = inc.estado == EstadoIncidencia.enviado;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: esPendiente ? Colors.red.shade200 : const Color(0xFFE2E8F0),
          width: esPendiente ? 1.5 : 1.0,
        ),
      ),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final cambio = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleIncidenciaScreen(incidencia: inc),
            ),
          );
          if (cambio == true) {
            _cargarIncidencias(silencioso: true);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado: Categoría, qué se trata y Badge de Estado
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: inc.categoriaColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(inc.categoriaIcono, color: inc.categoriaColor, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inc.categoriaNombre,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          inc.descripcionTipo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF475569),
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                inc.cuadrilla,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              fechaFormatted,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: inc.estadoColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: inc.estadoColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: inc.estadoColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          inc.estadoTexto,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: inc.estadoColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Dirección de la incidencia (Destacada)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 18, color: Color(0xFFE11D48)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      inc.direccion,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),

              // Respuesta municipal si existe
              if (inc.respuestaMunicipal != null && inc.respuestaMunicipal!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 24.0),
                  child: Text(
                    'Nota: ${inc.respuestaMunicipal!}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF475569),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Fila inferior: Miniatura de la foto + Botón ver detalle
              Row(
                children: [
                  if (inc.tieneFoto) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 52,
                        height: 52,
                        color: Colors.grey.shade200,
                        child: Image.network(
                          inc.fotos.first,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.broken_image,
                            size: 24,
                            color: Colors.grey,
                          ),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${inc.fotos.length} ${inc.fotos.length == 1 ? 'foto' : 'fotos'}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ] else ...[
                    Row(
                      children: const [
                        Icon(Icons.no_photography_outlined, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'Sin foto adjunta',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],

                  const Spacer(),

                  // Botón "Ver detalle y mapa"
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () async {
                      final cambio = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetalleIncidenciaScreen(incidencia: inc),
                        ),
                      );
                      if (cambio == true) {
                        _cargarIncidencias(silencioso: true);
                      }
                    },
                    icon: const Icon(Icons.arrow_forward_ios, size: 13),
                    label: const Text(
                      'Ver detalle y mapa',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

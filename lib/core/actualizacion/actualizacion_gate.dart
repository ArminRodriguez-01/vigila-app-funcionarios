import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'actualizacion_config.dart';
import 'actualizacion_service.dart';

/// Envuelve la app: si hay un release más nuevo, reemplaza todo por una pantalla de
/// "nueva versión disponible" que no se puede cerrar. Revisa al abrir y al volver de
/// segundo plano.
class ActualizacionGate extends StatefulWidget {
  const ActualizacionGate({super.key, required this.child});

  final Widget child;

  @override
  State<ActualizacionGate> createState() => _ActualizacionGateState();
}

class _ActualizacionGateState extends State<ActualizacionGate> with WidgetsBindingObserver {
  // GitHub permite 60 consultas por hora por IP sin sesión: no insistir de más.
  static const _minimoEntreConsultas = Duration(minutes: 2);

  InfoActualizacion? _pendiente;
  DateTime? _ultimaConsulta;
  bool _consultando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _verificar();
  }

  Future<void> _verificar() async {
    if (_pendiente != null || _consultando) return;
    final ultima = _ultimaConsulta;
    if (ultima != null && DateTime.now().difference(ultima) < _minimoEntreConsultas) return;

    _consultando = true;
    _ultimaConsulta = DateTime.now();
    final info = await ActualizacionService.buscar();
    _consultando = false;
    if (mounted && info != null) setState(() => _pendiente = info);
  }

  @override
  Widget build(BuildContext context) {
    final info = _pendiente;
    if (info == null) return widget.child;
    // canPop: false -> el botón "atrás" del teléfono no sale de esta pantalla.
    return PopScope(canPop: false, child: _PantallaActualizacion(info: info));
  }
}

class _PantallaActualizacion extends StatelessWidget {
  const _PantallaActualizacion({required this.info});

  final InfoActualizacion info;

  Future<void> _actualizar(BuildContext context) async {
    final mensajero = ScaffoldMessenger.of(context);
    final abierto = await launchUrl(
      Uri.parse(info.urlDescarga),
      mode: LaunchMode.externalApplication,
    );
    if (!abierto) {
      mensajero.showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la descarga. Intenta de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update_rounded, size: 84, color: color),
                const SizedBox(height: 24),
                const Text(
                  'Hay una nueva versión disponible',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Para seguir usando ${ActualizacionConfig.nombreApp} debes actualizar '
                  'a la versión ${info.versionNueva}. Tienes la ${info.versionInstalada}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _actualizar(context),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Actualizar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: color,
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Al terminar la descarga, abre el archivo para instalarlo. Si Android lo '
                  'pide, permite instalar aplicaciones desde tu navegador.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

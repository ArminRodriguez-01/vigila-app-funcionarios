import 'dart:async';

import 'package:flutter/material.dart';

import '../../screens/login_screen.dart';
import 'auth_controller.dart';

/// Decide qué ve el funcionario: carga, login o la app. Al volver a primer plano renueva la
/// sesión, y si la sesión se cierra descarta las pantallas abiertas encima (detalle, diálogos).
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.controller, required this.child});

  final AuthController controller;
  final Widget child;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  late EstadoAuth _estadoPrevio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _estadoPrevio = widget.controller.estado;
    widget.controller.addListener(_alCambiarSesion);
  }

  @override
  void didUpdateWidget(AuthGate anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.controller != widget.controller) {
      anterior.controller.removeListener(_alCambiarSesion);
      _estadoPrevio = widget.controller.estado;
      widget.controller.addListener(_alCambiarSesion);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_alCambiarSesion);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.renovarSiCorresponde());
    }
  }

  void _alCambiarSesion() {
    final estado = widget.controller.estado;
    final seCerro = _estadoPrevio == EstadoAuth.autenticado && estado == EstadoAuth.noAutenticado;
    _estadoPrevio = estado;
    if (seCerro) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((ruta) => ruta.isFirst);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => switch (widget.controller.estado) {
        EstadoAuth.iniciando => const _Cargando(),
        EstadoAuth.noAutenticado => LoginScreen(controller: widget.controller),
        EstadoAuth.autenticado => widget.child,
      },
    );
  }
}

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator(color: Color(0xFF0F766E))),
    );
  }
}

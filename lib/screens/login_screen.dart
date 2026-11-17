import 'package:flutter/material.dart';

import '../core/auth/auth_controller.dart';
import '../core/auth/auth_exceptions.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _verde = Color(0xFF0F766E);

  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _verClave = false;
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ingresar() async {
    if (_cargando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await widget.controller.iniciarSesion(_correo.text, _clave.text);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo iniciar sesión. Intenta de nuevo.');
    } finally {
      // Si el login funcionó, AuthGate ya reemplazó esta pantalla y no hay nada que actualizar.
      if (mounted) setState(() => _cargando = false);
    }
  }

  String? _avisoDeCierre(MotivoCierre? motivo) => switch (motivo) {
        MotivoCierre.sesionExpirada => 'Tu sesión expiró. Ingresa de nuevo.',
        MotivoCierre.cuentaInactiva => 'Tu cuenta fue desactivada. Contacta a tu administrador.',
        null => null,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _verde,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.engineering_rounded, size: 64, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text(
                    'Vigila Funcionarios',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Acceso para funcionarios municipales',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: _formulario(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulario() {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                final aviso = _avisoDeCierre(widget.controller.motivoCierre);
                if (aviso == null) return const SizedBox.shrink();
                return _Mensaje(texto: aviso, color: const Color(0xFFB45309), fondo: const Color(0xFFFEF3C7));
              },
            ),
            TextFormField(
              key: const Key('campo_correo'),
              controller: _correo,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username, AutofillHints.email],
              autocorrect: false,
              decoration: _decoracion('Correo institucional', Icons.mail_outline_rounded),
              validator: (valor) {
                final correo = (valor ?? '').trim();
                if (correo.isEmpty) return 'Ingresa tu correo';
                if (!correo.contains('@')) return 'Ingresa un correo válido';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('campo_clave'),
              controller: _clave,
              obscureText: !_verClave,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) => _ingresar(),
              decoration: _decoracion('Contraseña', Icons.lock_outline_rounded).copyWith(
                suffixIcon: IconButton(
                  tooltip: _verClave ? 'Ocultar contraseña' : 'Mostrar contraseña',
                  icon: Icon(_verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _verClave = !_verClave),
                ),
              ),
              validator: (valor) =>
                  (valor == null || valor.isEmpty) ? 'Ingresa tu contraseña' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              _Mensaje(texto: _error!, color: const Color(0xFFB91C1C), fondo: const Color(0xFFFEE2E2)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('boton_ingresar'),
              onPressed: _cargando ? null : _ingresar,
              style: FilledButton.styleFrom(
                backgroundColor: _verde,
                minimumSize: const Size.fromHeight(50),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              child: _cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    )
                  : const Text('Ingresar'),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoracion(String etiqueta, IconData icono) => InputDecoration(
        labelText: etiqueta,
        prefixIcon: Icon(icono),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}

class _Mensaje extends StatelessWidget {
  const _Mensaje({required this.texto, required this.color, required this.fondo});

  final String texto;
  final Color color;
  final Color fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(10)),
      child: Text(texto, style: TextStyle(color: color, fontSize: 13.5, height: 1.3)),
    );
  }
}

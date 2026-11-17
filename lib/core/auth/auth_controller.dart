import 'dart:async';

import 'package:flutter/foundation.dart';

import 'auth_exceptions.dart';
import 'auth_repository.dart';
import 'sesion.dart';
import 'sesion_storage.dart';

enum EstadoAuth { iniciando, noAutenticado, autenticado }

/// Por qué se cerró la sesión sin que el funcionario lo pidiera (para avisarle en el login).
enum MotivoCierre { sesionExpirada, cuentaInactiva }

/// Política de sesión: dura 7 días desde el último ingreso. Cada apertura o vuelta a primer
/// plano la renueva; si pasan 7 días sin abrir la app, la sesión se cierra. Sin conexión
/// nunca se cierra (cuadrilla en terreno): solo por vencimiento local o 401 del servidor.
class AuthController extends ChangeNotifier {
  AuthController({
    required this._repositorio,
    required this._storage,
    DateTime Function()? ahora,
    this.renovarCadaMinimo = const Duration(minutes: 5),
  }) : _ahora = ahora ?? DateTime.now;

  final AuthRepository _repositorio;
  final SesionStorage _storage;
  final DateTime Function() _ahora;
  final Duration renovarCadaMinimo;

  EstadoAuth _estado = EstadoAuth.iniciando;
  Sesion? _sesion;
  MotivoCierre? _motivoCierre;
  DateTime? _ultimaRenovacion;
  Future<void>? _renovando;

  EstadoAuth get estado => _estado;
  Sesion? get sesion => _sesion;
  String? get token => _sesion?.token;
  MotivoCierre? get motivoCierre => _motivoCierre;

  /// Lee la sesión guardada al abrir la app. No espera a la red: si la sesión sigue vigente
  /// queda autenticado de inmediato y la renovación corre en segundo plano.
  Future<void> restaurar() async {
    final guardada = await _storage.leer();
    if (guardada == null) {
      _cambiarEstado(EstadoAuth.noAutenticado);
      return;
    }
    if (guardada.estaVencida(_ahora())) {
      await _cerrarLocalmente(MotivoCierre.sesionExpirada);
      return;
    }
    _sesion = guardada;
    _cambiarEstado(EstadoAuth.autenticado);
    unawaited(renovarSiCorresponde());
  }

  /// Lanza una [AuthException] si el login falla; en ese caso el estado no cambia.
  Future<void> iniciarSesion(String email, String password) async {
    final nueva = await _repositorio.iniciarSesion(email.trim(), password);
    await _guardar(nueva);
    _sesion = nueva;
    _motivoCierre = null;
    _ultimaRenovacion = _ahora();
    _cambiarEstado(EstadoAuth.autenticado);
  }

  /// Renueva la sesión por otros 7 días. Se puede llamar cuantas veces se quiera: no hace nada
  /// sin sesión, comparte la renovación en curso y espera [renovarCadaMinimo] entre intentos.
  Future<void> renovarSiCorresponde() {
    final enCurso = _renovando;
    if (enCurso != null) return enCurso;

    final actual = _sesion;
    if (_estado != EstadoAuth.autenticado || actual == null) return Future<void>.value();

    final ahora = _ahora();
    if (actual.estaVencida(ahora)) return _cerrarLocalmente(MotivoCierre.sesionExpirada);

    final ultima = _ultimaRenovacion;
    if (ultima != null && ahora.difference(ultima) < renovarCadaMinimo) {
      return Future<void>.value();
    }

    _ultimaRenovacion = ahora;
    return _renovando = _renovar(actual).whenComplete(() => _renovando = null);
  }

  /// Cierra la sesión. Sin [motivo] es voluntario: además se avisa al servidor (best-effort).
  Future<void> cerrarSesion({MotivoCierre? motivo}) async {
    final actual = _sesion;
    await _cerrarLocalmente(motivo);
    if (motivo == null && actual != null) {
      try {
        await _repositorio.cerrarSesion(actual.token);
      } catch (_) {
        // Sin red o servidor caído: la sesión local ya se cerró, el token vence solo.
      }
    }
  }

  Future<void> _renovar(Sesion actual) async {
    try {
      final nueva = await _repositorio.renovar(actual.token);
      if (_sesion?.token != actual.token) return; // se cerró o cambió mientras esperábamos
      await _guardar(nueva);
      _sesion = nueva;
      notifyListeners();
    } on SesionExpiradaException {
      if (_sesion?.token == actual.token) await _cerrarLocalmente(MotivoCierre.sesionExpirada);
    } on CuentaInactivaException {
      if (_sesion?.token == actual.token) await _cerrarLocalmente(MotivoCierre.cuentaInactiva);
    } catch (e) {
      // Sin conexión o error del servidor: se conserva la sesión y se reintenta al volver.
      debugPrint('No se pudo renovar la sesión: $e');
    }
  }

  Future<void> _cerrarLocalmente(MotivoCierre? motivo) async {
    _sesion = null;
    _motivoCierre = motivo;
    _ultimaRenovacion = null;
    _cambiarEstado(EstadoAuth.noAutenticado);
    try {
      await _storage.borrar();
    } catch (e) {
      debugPrint('No se pudo borrar la sesión guardada: $e');
    }
  }

  Future<void> _guardar(Sesion sesion) async {
    try {
      await _storage.guardar(sesion);
    } catch (e) {
      // Si el almacenamiento falla la sesión sigue activa en memoria; solo se pierde al reiniciar.
      debugPrint('No se pudo guardar la sesión: $e');
    }
  }

  void _cambiarEstado(EstadoAuth estado) {
    _estado = estado;
    notifyListeners();
  }
}

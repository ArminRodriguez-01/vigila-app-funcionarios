import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vigila_funcionarios/core/auth/auth_config.dart';
import 'package:vigila_funcionarios/core/auth/auth_controller.dart';
import 'package:vigila_funcionarios/core/auth/auth_exceptions.dart';
import 'package:vigila_funcionarios/core/auth/auth_repository.dart';
import 'package:vigila_funcionarios/core/auth/mock_auth_repository.dart';
import 'package:vigila_funcionarios/core/auth/sesion.dart';
import 'package:vigila_funcionarios/core/auth/sesion_storage.dart';

const _ana = Funcionario(id: '1', email: 'ana@victoria.cl', nombre: 'Ana');

/// Repositorio falso: cuenta llamadas y permite forzar fallas o dejar una renovación en espera.
class RepoFalso implements AuthRepository {
  RepoFalso(this.ahora);

  final DateTime Function() ahora;
  int llamadasLogin = 0;
  int llamadasRenovar = 0;
  int llamadasCerrar = 0;
  String? ultimoCorreo;
  Exception? fallaRenovar;
  Exception? fallaCerrar;
  Completer<void>? bloqueoRenovar;
  int _n = 0;

  Sesion _nueva() =>
      Sesion(token: 'tok-${_n++}', expiraEn: ahora().add(kDuracionSesion), funcionario: _ana);

  @override
  Future<Sesion> iniciarSesion(String email, String password) async {
    llamadasLogin++;
    ultimoCorreo = email;
    if (password != 'ok') throw const CredencialesInvalidasException();
    return _nueva();
  }

  @override
  Future<Sesion> renovar(String token) async {
    llamadasRenovar++;
    final bloqueo = bloqueoRenovar;
    if (bloqueo != null) await bloqueo.future;
    final falla = fallaRenovar;
    if (falla != null) throw falla;
    return _nueva();
  }

  @override
  Future<void> cerrarSesion(String token) async {
    llamadasCerrar++;
    final falla = fallaCerrar;
    if (falla != null) throw falla;
  }
}

void main() {
  late DateTime ahora;
  late RepoFalso repo;
  late MemorySesionStorage storage;

  AuthController crear() => AuthController(
        repositorio: repo,
        storage: storage,
        ahora: () => ahora,
      );

  Sesion guardada({Duration vence = const Duration(days: 3)}) =>
      Sesion(token: 'guardado', expiraEn: ahora.add(vence), funcionario: _ana);

  setUp(() {
    ahora = DateTime.utc(2026, 11, 17, 12);
    repo = RepoFalso(() => ahora);
    storage = MemorySesionStorage();
  });

  test('antes de restaurar el estado es iniciando', () {
    expect(crear().estado, EstadoAuth.iniciando);
  });

  test('restaurar sin sesión guardada -> noAutenticado y motivoCierre null', () async {
    final c = crear();

    await c.restaurar();

    expect(c.estado, EstadoAuth.noAutenticado);
    expect(c.motivoCierre, isNull);
    expect(c.token, isNull);
  });

  test('restaurar con sesión vigente queda autenticado de inmediato, sin esperar la red', () async {
    await storage.guardar(guardada());
    repo.bloqueoRenovar = Completer<void>(); // la red "no responde"
    final c = crear();

    await c.restaurar();

    expect(c.estado, EstadoAuth.autenticado);
    expect(c.token, 'guardado');
    repo.bloqueoRenovar!.complete();
    await c.renovarSiCorresponde();
  });

  test('tras restaurar, la sesión vigente se renueva a ahora + 7 días y se guarda', () async {
    await storage.guardar(guardada(vence: const Duration(days: 1)));
    final c = crear();

    await c.restaurar();
    await c.renovarSiCorresponde();

    expect(c.token, 'tok-0');
    expect(c.sesion!.expiraEn, ahora.add(kDuracionSesion));
    expect((await storage.leer())!.token, 'tok-0');
  });

  test('restaurar con sesión vencida -> noAutenticado, sesionExpirada, storage vacío y sin llamar al servidor', () async {
    await storage.guardar(guardada(vence: const Duration(seconds: -1)));
    final c = crear();

    await c.restaurar();

    expect(c.estado, EstadoAuth.noAutenticado);
    expect(c.motivoCierre, MotivoCierre.sesionExpirada);
    expect(await storage.leer(), isNull);
    expect(repo.llamadasRenovar, 0);
  });

  test('sin red (SinConexionException) con sesión vigente sigue autenticado y conserva el token', () async {
    await storage.guardar(guardada());
    repo.fallaRenovar = const SinConexionException();
    final c = crear();

    await c.restaurar();
    await c.renovarSiCorresponde();

    expect(c.estado, EstadoAuth.autenticado);
    expect(c.token, 'guardado');
    expect((await storage.leer())!.token, 'guardado');
  });

  test('un error 5xx al renovar tampoco cierra la sesión', () async {
    await storage.guardar(guardada());
    repo.fallaRenovar = const ErrorServidorException(500);
    final c = crear();

    await c.restaurar();
    await c.renovarSiCorresponde();

    expect(c.estado, EstadoAuth.autenticado);
  });

  test('SesionExpiradaException al renovar -> noAutenticado, sesionExpirada y storage vacío', () async {
    await storage.guardar(guardada());
    repo.fallaRenovar = const SesionExpiradaException();
    final c = crear();

    await c.restaurar();
    await c.renovarSiCorresponde();

    expect(c.estado, EstadoAuth.noAutenticado);
    expect(c.motivoCierre, MotivoCierre.sesionExpirada);
    expect(await storage.leer(), isNull);
  });

  test('CuentaInactivaException al renovar -> motivo cuentaInactiva', () async {
    await storage.guardar(guardada());
    repo.fallaRenovar = const CuentaInactivaException();
    final c = crear();

    await c.restaurar();
    await c.renovarSiCorresponde();

    expect(c.estado, EstadoAuth.noAutenticado);
    expect(c.motivoCierre, MotivoCierre.cuentaInactiva);
  });

  test('renovaciones simultáneas llaman al servidor una sola vez', () async {
    await storage.guardar(guardada());
    repo.bloqueoRenovar = Completer<void>();
    final c = crear();

    await c.restaurar(); // lanza la primera renovación
    final a = c.renovarSiCorresponde();
    final b = c.renovarSiCorresponde();
    repo.bloqueoRenovar!.complete();
    await Future.wait([a, b]);

    expect(repo.llamadasRenovar, 1);
  });

  test('no renueva de nuevo antes de 5 minutos; pasados 5 minutos sí', () async {
    await storage.guardar(guardada());
    final c = crear();
    await c.restaurar();
    await c.renovarSiCorresponde();
    expect(repo.llamadasRenovar, 1);

    ahora = ahora.add(const Duration(minutes: 4, seconds: 59));
    await c.renovarSiCorresponde();
    expect(repo.llamadasRenovar, 1);

    ahora = ahora.add(const Duration(seconds: 1));
    await c.renovarSiCorresponde();
    expect(repo.llamadasRenovar, 2);
  });

  test('app en segundo plano más de 7 días: al volver cierra la sesión sin llamar al servidor', () async {
    final c = crear();
    await c.iniciarSesion('ana@victoria.cl', 'ok');

    ahora = ahora.add(kDuracionSesion + const Duration(minutes: 1));
    await c.renovarSiCorresponde();

    expect(c.estado, EstadoAuth.noAutenticado);
    expect(c.motivoCierre, MotivoCierre.sesionExpirada);
    expect(repo.llamadasRenovar, 0);
  });

  test('renovarSiCorresponde sin sesión no hace nada', () async {
    final c = crear();
    await c.restaurar();

    await c.renovarSiCorresponde();

    expect(repo.llamadasRenovar, 0);
  });

  test('cerrar sesión mientras hay una renovación en vuelo no la resucita', () async {
    await storage.guardar(guardada());
    repo.bloqueoRenovar = Completer<void>();
    final c = crear();
    await c.restaurar();

    await c.cerrarSesion();
    repo.bloqueoRenovar!.complete();
    await c.renovarSiCorresponde();

    expect(c.estado, EstadoAuth.noAutenticado);
    expect(await storage.leer(), isNull);
  });

  test('iniciarSesion correcto -> autenticado, guarda la sesión y limpia el motivo de cierre', () async {
    await storage.guardar(guardada(vence: const Duration(seconds: -1)));
    final c = crear();
    await c.restaurar();
    expect(c.motivoCierre, MotivoCierre.sesionExpirada);

    await c.iniciarSesion('ana@victoria.cl', 'ok');

    expect(c.estado, EstadoAuth.autenticado);
    expect(c.motivoCierre, isNull);
    expect((await storage.leer())!.token, c.token);
  });

  test('iniciarSesion recorta los espacios del correo', () async {
    final c = crear();

    await c.iniciarSesion('  ana@victoria.cl  ', 'ok');

    expect(repo.ultimoCorreo, 'ana@victoria.cl');
  });

  test('iniciarSesion con clave mala lanza CredencialesInvalidasException y sigue noAutenticado', () async {
    final c = crear();
    await c.restaurar();

    await expectLater(c.iniciarSesion('ana@victoria.cl', 'mala'), throwsA(isA<CredencialesInvalidasException>()));

    expect(c.estado, EstadoAuth.noAutenticado);
    expect(await storage.leer(), isNull);
  });

  test('cerrarSesion limpia estado y storage y avisa al servidor', () async {
    final c = crear();
    await c.iniciarSesion('ana@victoria.cl', 'ok');

    await c.cerrarSesion();

    expect(c.estado, EstadoAuth.noAutenticado);
    expect(c.token, isNull);
    expect(c.motivoCierre, isNull);
    expect(await storage.leer(), isNull);
    expect(repo.llamadasCerrar, 1);
  });

  test('cerrarSesion cierra igual si el servidor no responde', () async {
    repo.fallaCerrar = const SinConexionException();
    final c = crear();
    await c.iniciarSesion('ana@victoria.cl', 'ok');

    await c.cerrarSesion();

    expect(c.estado, EstadoAuth.noAutenticado);
    expect(await storage.leer(), isNull);
  });

  test('cerrar por expiración o cuenta inactiva no llama /logout y deja el motivo', () async {
    final c = crear();
    await c.iniciarSesion('ana@victoria.cl', 'ok');

    await c.cerrarSesion(motivo: MotivoCierre.cuentaInactiva);

    expect(c.motivoCierre, MotivoCierre.cuentaInactiva);
    expect(repo.llamadasCerrar, 0);
  });

  test('los cambios de estado avisan a los oyentes', () async {
    final c = crear();
    var avisos = 0;
    c.addListener(() => avisos++);

    await c.restaurar();
    await c.iniciarSesion('ana@victoria.cl', 'ok');
    await c.cerrarSesion();

    expect(avisos, greaterThanOrEqualTo(3));
  });

  test('ciclo de 7 días: abrir a los 6 y a los 12 días extiende la sesión; 8 días sin abrir la cierra', () async {
    final inicio = DateTime.utc(2026, 11, 17, 12);
    ahora = inicio;
    final mock = MockAuthRepository(ahora: () => ahora);
    final almacen = MemorySesionStorage();
    AuthController abrirApp() => AuthController(repositorio: mock, storage: almacen, ahora: () => ahora);

    // Día 0: login (vence día 7).
    final dia0 = abrirApp();
    await dia0.restaurar();
    await dia0.iniciarSesion('demo@victoria.cl', 'demo-1234');
    expect(dia0.sesion!.expiraEn, inicio.add(const Duration(days: 7)));

    // Día 6: abre la app -> sigue dentro y se renueva (vence día 13).
    ahora = inicio.add(const Duration(days: 6));
    final dia6 = abrirApp();
    await dia6.restaurar();
    await dia6.renovarSiCorresponde();
    expect(dia6.estado, EstadoAuth.autenticado);
    expect(dia6.sesion!.expiraEn, inicio.add(const Duration(days: 13)));

    // Día 12: abre otra vez (sin la renovación del día 6 habría vencido en el día 7).
    ahora = inicio.add(const Duration(days: 12));
    final dia12 = abrirApp();
    await dia12.restaurar();
    await dia12.renovarSiCorresponde();
    expect(dia12.estado, EstadoAuth.autenticado);
    expect(dia12.sesion!.expiraEn, inicio.add(const Duration(days: 19)));

    // Día 20: pasaron 8 días sin abrir -> la sesión se cierra.
    ahora = inicio.add(const Duration(days: 20));
    final dia20 = abrirApp();
    await dia20.restaurar();
    expect(dia20.estado, EstadoAuth.noAutenticado);
    expect(dia20.motivoCierre, MotivoCierre.sesionExpirada);
    expect(await almacen.leer(), isNull);
  });
}

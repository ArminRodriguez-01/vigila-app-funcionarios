# Login de funcionarios con sesión de 7 días — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** La app de funcionarios exige login contra el backend, mantiene la sesión 7 días desde el último ingreso (cada apertura la renueva) y la cierra si pasan 7 días sin abrirla; el backend aún no cumple el contrato, así que se trabaja contra un mock y se entrega el contrato escrito.

**Architecture:** Un `AuthController` (ChangeNotifier, sin paquetes de estado nuevos) aplica la política de sesión sobre dos puertos intercambiables: `AuthRepository` (mock o HTTP) y `SesionStorage` (memoria o almacenamiento seguro). `AuthGate` decide qué pantalla se ve. `CuadrillaApiService` envía el token y avisa al controller cuando recibe 401.

**Tech Stack:** Flutter 3.50.0 / Dart ^3.13.7, `http` (+ `http/testing.dart` para tests), `flutter_secure_storage` ^11.2.0, `flutter_test`.

**Spec:** Solicitud del usuario del 2026-11-17 (sesión de 7 días con renovación al ingresar, cierre tras 7 días sin entrar, backend inexistente → mocks + documento de contratos). El contrato del backend vive en la sección «Contrato del backend» de este plan y se publica en `docs/contratos-backend-auth.md` (Task 7).

## Global Constraints

- Sesión: **7 días** (`kDuracionSesion = Duration(days: 7)`) contados desde el último ingreso; cada apertura o vuelta a primer plano la renueva, con **mínimo 5 minutos** entre renovaciones.
- Sin conexión **nunca** se cierra la sesión (cuadrilla en terreno); solo se cierra por expiración local o por 401 del servidor.
- El token se guarda solo con `flutter_secure_storage`; nunca en `SharedPreferences` ni en logs.
- La expiración se calcula con `expira_en_segundos` del servidor + reloj local al recibir la respuesta; el servidor es la autoridad final.
- Errores del backend: `{"codigo": "...", "mensaje": "..."}` (formato ya usado por `vigila-app/backend`).
- El mock **jamás** se activa en builds release (`kReleaseMode`).
- Textos de la interfaz en español; commits en conventional commits, en español, terminando con `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Rama de trabajo: `feat/login-funcionarios`, desde `main` (que ya incluye AGP 9.3.1 / built-in Kotlin).

## Contrato del backend (fuente de verdad para Tasks 2, 3, 5 y 7)

Base: `https://vigila-app.onrender.com/api/v1/cuadrilla`. Todas las respuestas de error: `{"codigo","mensaje"}`.

| Método y ruta | Estado | Request | Respuesta OK | Errores |
|---|---|---|---|---|
| `POST /login` | **existe**, hoy token de 15 min | `{"email","password"}` | `200 {"access_token","token_type":"bearer","expira_en_segundos":604800,"funcionario":{"id","email","nombre","rol","activo"}}` | `401 credenciales_invalidas`, `429` (límite de intentos) |
| `POST /sesion/renovar` | **nuevo** | header `Authorization: Bearer <token>` | `200` mismo cuerpo que `/login`, token nuevo con 7 días completos | `401 sesion_expirada` (vencido, inválido o revocado), `401 cuenta_inactiva` |
| `POST /logout` | **nuevo**, best-effort | header `Authorization: Bearer <token>` | `204`, idempotente | se ignoran |
| `GET/POST /reportes*` | existe, hoy **sin** auth | header `Authorization: Bearer <token>` | sin cambios | `401 no_autenticado` (sin token), `401 sesion_expirada` |

Reglas del servidor: JWT HS256 con `sub`=id del funcionario, `rol`, `iat`, `exp = iat + 7 días`, `jti`; `/sesion/renovar` solo renueva tokens **aún vigentes** de cuentas activas; las peticiones normales **no** extienden la sesión; configurable con `VIGILA_CUADRILLA_SESION_DIAS=7` (hoy `crear_access_token` usa `jwt_access_minutos=15` compartido con vecinos y admin).

## Review Focus

1. Abrir la app **sin red** con sesión vigente: no cierra la sesión ni borra el token (Task 4).
2. Abrir con la sesión **vencida localmente** (más de 7 días): muestra el login con aviso «Tu sesión expiró», sin llamar al servidor (Task 4, Task 6).
3. Servidor responde **401** a la renovación o a un endpoint de reportes (token revocado, cuenta desactivada): cierra sesión y vuelve al login (Task 4, Task 5).
4. Abrir la app y volver a primer plano casi a la vez: **una sola** renovación en vuelo, y no más de una cada 5 minutos (Task 4).
5. **APK release con mock**: el mock nunca se activa aunque se pase `USAR_MOCK_AUTH=true`; y un valor corrupto en el almacenamiento se trata como «sin sesión», no como cierre (Task 1, Task 2).

---

### Task 1: Modelo `Sesion` y almacenamiento

**Files:**
- Modify: `pubspec.yaml` (agregar `flutter_secure_storage: ^11.2.0`)
- Create: `lib/core/auth/sesion.dart`
- Create: `lib/core/auth/sesion_storage.dart`
- Test: `test/auth/sesion_test.dart`
- Test: `test/auth/sesion_storage_test.dart`

**Interfaces:**
- Produces:
  - `class Funcionario { final String id, email, nombre, rol; const Funcionario({required id, required email, required nombre, this.rol = 'funcionario'}); factory Funcionario.fromJson(Map<String, dynamic>); Map<String, dynamic> toJson(); }`
  - `class Sesion { final String token; final DateTime expiraEn; final Funcionario funcionario; const Sesion({required token, required expiraEn, required funcionario}); factory Sesion.desdeRespuesta(Map<String, dynamic> json, DateTime ahora); bool estaVencida(DateTime ahora); String toJsonString(); static Sesion? tryParse(String raw); }` (`==`/`hashCode` por valor).
  - `abstract class SesionStorage { Future<Sesion?> leer(); Future<void> guardar(Sesion s); Future<void> borrar(); }`, `class MemorySesionStorage implements SesionStorage`, `class SecureSesionStorage implements SesionStorage` (clave `sesion_funcionario`).

- [ ] **Step 1: Crear la rama**

Run: `git switch -c feat/login-funcionarios main`
Expected: `Switched to a new branch 'feat/login-funcionarios'`

- [ ] **Step 2: Write the failing tests** (`test/auth/sesion_test.dart`)

```dart
test('desdeRespuesta calcula expiraEn con expira_en_segundos', () {
  final s = Sesion.desdeRespuesta({
    'access_token': 't', 'token_type': 'bearer', 'expira_en_segundos': 604800,
    'funcionario': {'id': '1', 'email': 'a@b.cl', 'nombre': 'Ana', 'rol': 'funcionario', 'activo': true},
  }, DateTime.utc(2026, 11, 17, 12));
  expect(s.token, 't');
  expect(s.expiraEn, DateTime.utc(2026, 11, 24, 12));
  expect(s.funcionario.nombre, 'Ana');
});
test('estaVencida: en el instante exacto de expiración ya está vencida', () {
  // expiraEn = X → estaVencida(X) true; estaVencida(X - 1 s) false
});
test('toJsonString/tryParse ida y vuelta devuelve una Sesion igual', () {});
test('tryParse devuelve null con texto corrupto, JSON sin token o expiraEn inválido', () {
  expect(Sesion.tryParse('basura'), isNull);
  expect(Sesion.tryParse('{"token": 1}'), isNull);
});
```
`sesion_storage_test.dart`: `MemorySesionStorage` — `guardar` luego `leer` devuelve la misma sesión; `borrar` luego `leer` devuelve `null`; `leer` inicial `null`.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/auth`
Expected: FAIL (archivos `sesion.dart` / `sesion_storage.dart` no existen).

- [ ] **Step 4: Implement** `Sesion`, `Funcionario`, `SesionStorage`, `MemorySesionStorage`, `SecureSesionStorage` según las firmas de Interfaces. `tryParse` captura cualquier excepción de decodificación y devuelve `null`. `SecureSesionStorage.leer` usa `Sesion.tryParse` (y borra la clave si está corrupta).

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter pub get` y luego `flutter test test/auth`
Expected: PASS.

- [ ] **Step 6: Verificar que el plugin compila en release (riesgo conocido con AGP 9 / built-in Kotlin)**

Run: `flutter build apk --release`
Expected: `Built build\app\outputs\flutter-apk\app-release.apk`, sin warnings de «plugins that apply Kotlin Gradle Plugin». Si falla, parar y reportar el error antes de seguir.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/auth test/auth linux windows macos
git commit -m "feat(auth): agregar modelo de sesión y almacenamiento seguro"
```

---

### Task 2: `AuthRepository`, excepciones, configuración y mock

**Files:**
- Create: `lib/core/auth/auth_exceptions.dart`
- Create: `lib/core/auth/auth_repository.dart`
- Create: `lib/core/auth/auth_config.dart`
- Create: `lib/core/auth/mock_auth_repository.dart`
- Test: `test/auth/mock_auth_repository_test.dart`
- Test: `test/auth/auth_config_test.dart`

**Interfaces:**
- Consumes: `Sesion`, `Funcionario` (Task 1).
- Produces:
  - `sealed class AuthException implements Exception { String get mensaje; }` con subclases `CredencialesInvalidasException`, `SesionExpiradaException`, `CuentaInactivaException`, `DemasiadosIntentosException`, `SinConexionException`, `ErrorServidorException(int status)`; cada una con `mensaje` en español (ej.: «Correo o contraseña incorrectos.»).
  - `abstract class AuthRepository { Future<Sesion> iniciarSesion(String email, String password); Future<Sesion> renovar(String token); Future<void> cerrarSesion(String token); }`
  - `const Duration kDuracionSesion = Duration(days: 7);`
  - `bool resolverUsarMock({required bool solicitado, required bool esRelease})`; `class AuthConfig { static bool get usarMock; }` (usa `bool.fromEnvironment('USAR_MOCK_AUTH')` y `kReleaseMode`); `AuthRepository crearAuthRepository()` (Mock si `AuthConfig.usarMock`, si no `HttpAuthRepository` — se agrega en Task 3).
  - `class MockAuthRepository implements AuthRepository { MockAuthRepository({DateTime Function()? ahora, Duration latencia = Duration.zero, Map<String, String>? usuarios}); }` — usuario por defecto `demo@victoria.cl` / `demo-1234`; guarda en memoria `token → expiración`.

- [ ] **Step 1: Write the failing tests** (`mock_auth_repository_test.dart`, reloj controlado con una variable `DateTime ahora`)

```dart
test('login correcto devuelve sesión de 7 días', () async {
  final s = await repo.iniciarSesion('demo@victoria.cl', 'demo-1234');
  expect(s.expiraEn, ahora.add(kDuracionSesion));
});
test('login con clave incorrecta lanza CredencialesInvalidasException', () {});
test('renovar a los 3 días entrega token nuevo y expiración día 3 + 7', () async {
  // login día 0; ahora = día 3; renovar → token != anterior; expiraEn == día 10
});
test('renovar con la sesión vencida (7 días + 1 s) lanza SesionExpiradaException', () {});
test('renovar con token desconocido lanza SesionExpiradaException', () {});
test('tras cerrarSesion el token ya no se puede renovar', () {});
```
`auth_config_test.dart`: `resolverUsarMock(solicitado: true, esRelease: true)` → `false`; `(true, false)` → `true`; `(false, false)` → `false`; y `AuthConfig.usarMock` es `false` en tests sin `--dart-define`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/auth/mock_auth_repository_test.dart test/auth/auth_config_test.dart`
Expected: FAIL (símbolos no definidos).

- [ ] **Step 3: Implement** las excepciones, `AuthRepository`, `auth_config.dart` y `MockAuthRepository` (emite siempre un token nuevo en `renovar`; el reloj se lee solo vía `ahora()`). `crearAuthRepository()` queda referenciando `HttpAuthRepository`: dejarlo comentado hasta Task 3 y devolver el mock mientras tanto solo en este commit.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/auth`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/auth test/auth
git commit -m "feat(auth): agregar repositorio de autenticación, excepciones y mock"
```

---

### Task 3: `HttpAuthRepository`

**Files:**
- Create: `lib/core/auth/http_auth_repository.dart`
- Modify: `lib/core/auth/auth_config.dart` (activar `crearAuthRepository()` con la rama HTTP)
- Test: `test/auth/http_auth_repository_test.dart`

**Interfaces:**
- Consumes: `AuthRepository`, excepciones (Task 2), `Sesion.desdeRespuesta` (Task 1), `CuadrillaApiService.baseUrl` (existente, `https://vigila-app.onrender.com/api/v1`).
- Produces: `class HttpAuthRepository implements AuthRepository { HttpAuthRepository({http.Client? client, DateTime Function()? ahora, String? baseUrl}); }` — timeout de 15 s por petición.

- [ ] **Step 1: Write the failing tests** (con `MockClient` de `package:http/testing.dart`)

```dart
test('iniciarSesion hace POST a /cuadrilla/login con email y password', () {
  // verifica método, URL '$base/cuadrilla/login', body JSON {'email','password'} y que devuelve Sesion
});
test('renovar hace POST a /cuadrilla/sesion/renovar con Authorization: Bearer <token>', () {});
test('cerrarSesion hace POST a /cuadrilla/logout con el Bearer y acepta 204', () {});
test('401 credenciales_invalidas -> CredencialesInvalidasException', () {});
test('401 sesion_expirada y 401 no_autenticado en renovar -> SesionExpiradaException', () {});
test('401 cuenta_inactiva -> CuentaInactivaException', () {});
test('429 -> DemasiadosIntentosException', () {});
test('ClientException o TimeoutException -> SinConexionException', () {});
test('500 -> ErrorServidorException con status 500', () {});
test('cuerpo no JSON con 200 -> ErrorServidorException (no revienta)', () {});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/auth/http_auth_repository_test.dart`
Expected: FAIL (clase no definida).

- [ ] **Step 3: Implement** `HttpAuthRepository`. Mapeo de errores por `status` y `codigo` según la tabla del contrato; en `iniciarSesion` un 401 sin `codigo` se trata como `CredencialesInvalidasException`, en `renovar` como `SesionExpiradaException`. Dejar `crearAuthRepository()` devolviendo `AuthConfig.usarMock ? MockAuthRepository() : HttpAuthRepository()`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/auth`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/auth test/auth
git commit -m "feat(auth): agregar repositorio HTTP para login, renovación y cierre de sesión"
```

---

### Task 4: `AuthController` (política de 7 días)

**Files:**
- Create: `lib/core/auth/auth_controller.dart`
- Test: `test/auth/auth_controller_test.dart`

**Interfaces:**
- Consumes: `AuthRepository`, excepciones (Task 2), `Sesion`, `SesionStorage` (Task 1).
- Produces:
  - `enum EstadoAuth { iniciando, noAutenticado, autenticado }`, `enum MotivoCierre { sesionExpirada, cuentaInactiva }`
  - `class AuthController extends ChangeNotifier { AuthController({required AuthRepository repositorio, required SesionStorage storage, DateTime Function()? ahora, Duration renovarCadaMinimo = const Duration(minutes: 5)}); EstadoAuth get estado; Sesion? get sesion; String? get token; MotivoCierre? get motivoCierre; Future<void> restaurar(); Future<void> iniciarSesion(String email, String password); Future<void> renovarSiCorresponde(); Future<void> cerrarSesion({MotivoCierre? motivo}); }`
  - Reglas: `restaurar` lee el storage → sin sesión: `noAutenticado`; vencida: borra, `noAutenticado` + `sesionExpirada` **sin llamar** al repositorio; vigente: `autenticado` de inmediato y luego `renovarSiCorresponde()`. En `renovarSiCorresponde`: si ya hay una renovación en vuelo devuelve ese mismo `Future`; si la última renovación fue hace menos de `renovarCadaMinimo`, no hace nada; `SesionExpiradaException` → cierra con `sesionExpirada`; `CuentaInactivaException` → cierra con `cuentaInactiva`; cualquier otra excepción (sin red, 5xx) se ignora y conserva la sesión. `cerrarSesion` limpia storage y estado primero y luego llama al repositorio de forma best-effort (ignora errores). `iniciarSesion` relanza la `AuthException` y no cambia el estado si falla.

- [ ] **Step 1: Write the failing tests** (repositorio falso `RepoFalso` en el archivo de test: cuenta llamadas y permite fijar `Exception? falla`; reloj `DateTime ahora` mutable)

```dart
test('restaurar sin sesión guardada -> noAutenticado y motivoCierre null', () {});
test('restaurar con sesión vigente -> autenticado y token renovado con expiración ahora+7d', () {});
test('restaurar con sesión vencida -> noAutenticado, motivo sesionExpirada, storage vacío, repo.renovar NO llamado', () {});
test('sin red (SinConexionException) con sesión vigente sigue autenticado y conserva el token', () {});
test('SesionExpiradaException al renovar -> noAutenticado + sesionExpirada + storage vacío', () {});
test('CuentaInactivaException al renovar -> motivo cuentaInactiva', () {});
test('dos renovarSiCorresponde simultáneos llaman al repo una sola vez', () {});
test('renovar de nuevo antes de 5 min no llama; pasados 5 min sí', () {});
test('iniciarSesion correcto -> autenticado y guarda en storage', () {});
test('iniciarSesion con clave mala lanza CredencialesInvalidasException y sigue noAutenticado', () {});
test('cerrarSesion limpia storage y estado aunque repo.cerrarSesion falle', () {});
test('ciclo de 7 días: login día 0; abre día 6 (vence día 13); abre día 12 (vence día 19); sin abrir hasta día 20 -> restaurar cierra la sesión', () {});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/auth/auth_controller_test.dart`
Expected: FAIL (clase no definida).

- [ ] **Step 3: Implement** `AuthController` con las reglas de Interfaces; la renovación en vuelo se guarda en un `Future<void>? _renovando`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/auth`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/auth test/auth
git commit -m "feat(auth): agregar controlador con sesión de 7 días renovable"
```

---

### Task 5: `CuadrillaApiService` envía el token y detecta 401

**Files:**
- Modify: `lib/services/cuadrilla_api_service.dart` (todo el archivo: 3 métodos hoy usan `http.get/post` globales)
- Test: `test/cuadrilla_api_service_test.dart`

**Interfaces:**
- Produces: `CuadrillaApiService({http.Client? client})`; se mantiene `static final CuadrillaApiService instance`; campos `String? Function()? tokenProvider` y `void Function()? onNoAutorizado`; `baseUrl` pasa a ser `static const` accesible (ya lo es).

- [ ] **Step 1: Write the failing tests** (`MockClient`)

```dart
test('listarIncidencias envía Authorization: Bearer tok cuando tokenProvider devuelve tok', () {});
test('sin token no envía el header Authorization', () {});
test('obtenerDetalle y actualizarEstado también envían el Bearer', () {});
test('una respuesta 401 llama a onNoAutorizado una vez y lanza error', () {});
test('una respuesta 200 no llama a onNoAutorizado', () {});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/cuadrilla_api_service_test.dart`
Expected: FAIL (no existe el constructor con `client` ni `tokenProvider`).

- [ ] **Step 3: Implement** usando un `http.Client` inyectable y un método privado que arma los headers (`Accept`, `Content-Type` en POST, y `Authorization` solo si hay token) y revisa el 401 antes de interpretar la respuesta. Los mensajes de error existentes no cambian salvo el 401: «Tu sesión expiró. Ingresa de nuevo.»

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test`
Expected: PASS (incluye los tests previos).

- [ ] **Step 5: Commit**

```bash
git add lib/services/cuadrilla_api_service.dart test/cuadrilla_api_service_test.dart
git commit -m "feat(api): enviar el token de sesión y cerrar sesión ante 401"
```

---

### Task 6: Pantalla de login, `AuthGate`, cierre de sesión y cableado en `main`

**Files:**
- Create: `lib/core/auth/auth_gate.dart`
- Create: `lib/screens/login_screen.dart`
- Modify: `lib/main.dart` (crear controller, cablear `CuadrillaApiService`, `home: AuthGate(...)`, parámetro `auth` en `VigilaFuncionariosApp`)
- Modify: `lib/screens/lista_incidencias_screen.dart` (botón «Cerrar sesión» con confirmación)
- Modify: `test/widget_test.dart` (el smoke test debe construir `VigilaFuncionariosApp(auth: ...)`)
- Test: `test/auth/login_screen_test.dart`, `test/auth/auth_gate_test.dart`

**Interfaces:**
- Consumes: `AuthController`, `EstadoAuth`, `MotivoCierre` (Task 4), excepciones (Task 2), `CuadrillaApiService.instance.tokenProvider/onNoAutorizado` (Task 5), `crearAuthRepository()` (Task 3), `SecureSesionStorage` (Task 1).
- Produces: `class AuthGate extends StatefulWidget { const AuthGate({super.key, required this.controller, required this.child}); }` (observa el ciclo de vida: al volver a primer plano llama `controller.renovarSiCorresponde()`); `class LoginScreen extends StatefulWidget { const LoginScreen({super.key, required this.controller}); }`; `VigilaFuncionariosApp({super.key, required this.auth})`; `ListaIncidenciasScreen({super.key, required this.auth})`.

- [ ] **Step 1: Write the failing tests** (controller con `MockAuthRepository` y `MemorySesionStorage`)

```dart
// login_screen_test.dart
testWidgets('campos vacíos muestran "Ingresa tu correo" y "Ingresa tu contraseña" y no llaman al repo', ...);
testWidgets('clave incorrecta muestra "Correo o contraseña incorrectos."', ...);
testWidgets('con motivoCierre sesionExpirada muestra "Tu sesión expiró"', ...);
testWidgets('mientras inicia sesión el botón queda deshabilitado', ...);
// auth_gate_test.dart
testWidgets('estado iniciando muestra CircularProgressIndicator', ...);
testWidgets('noAutenticado muestra el login; tras login correcto muestra el hijo', ...);
testWidgets('cerrarSesion desde el hijo vuelve al login', ...);
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/auth/login_screen_test.dart test/auth/auth_gate_test.dart`
Expected: FAIL (clases no definidas).

- [ ] **Step 3: Implement `LoginScreen` y `AuthGate`** con el estilo existente (verde `0xFF0F766E`, `SafeArea`); campos correo (`keyboardType: emailAddress`, `autofillHints`) y contraseña con botón mostrar/ocultar; errores mostrados desde `AuthException.mensaje`.

- [ ] **Step 4: Cablear `main.dart`**: crear `AuthController(repositorio: crearAuthRepository(), storage: SecureSesionStorage())` y llamar `restaurar()` antes de `runApp`; asignar `CuadrillaApiService.instance.tokenProvider = () => auth.token` y `onNoAutorizado = () => auth.cerrarSesion(motivo: MotivoCierre.sesionExpirada)`; `home: AuthGate(controller: auth, child: ListaIncidenciasScreen(auth: auth))`. En el handler de toque de notificación: si `auth.estado != EstadoAuth.autenticado`, ignorar el toque (no mostrar incidencias sin sesión). Agregar en `ListaIncidenciasScreen` un `IconButton(Icons.logout, tooltip: 'Cerrar sesión')` con `AlertDialog` «¿Cerrar sesión?» que llama `auth.cerrarSesion()`. Actualizar `widget_test.dart`.

- [ ] **Step 5: Run the whole suite**

Run: `flutter test` y `flutter analyze`
Expected: tests PASS; `flutter analyze` sin errores (solo avisos informativos de `material.dart` obsoleto).

- [ ] **Step 6: Verificación manual con el mock**

Run: `flutter run --dart-define=USAR_MOCK_AUTH=true`
Expected: aparece el login; `demo@victoria.cl` / `demo-1234` entra a la lista; «Cerrar sesión» vuelve al login; al reabrir la app con sesión activa entra directo.

- [ ] **Step 7: Commit**

```bash
git add lib test
git commit -m "feat(auth): agregar pantalla de login y proteger la app con AuthGate"
```

---

### Task 7: Documento de contratos del backend y cierre

**Files:**
- Create: `docs/contratos-backend-auth.md`
- Modify: `RELEASES.md` (una línea: los builds de release usan el backend real, el mock es solo para desarrollo)

**Interfaces:**
- Consumes: la sección «Contrato del backend» de este plan y el comportamiento de Tasks 2–5.

- [ ] **Step 1: Escribir `docs/contratos-backend-auth.md`** con estas secciones, tomando los valores exactos de este plan: (1) Resumen y política de sesión (7 días deslizantes, quién renueva, qué pasa sin red); (2) endpoints con ejemplos de request/response JSON y tabla de códigos de error por endpoint; (3) formato del token (claims, `jti`, duración) y configuración `VIGILA_CUADRILLA_SESION_DIAS`; (4) cambios concretos en `vigila-app/backend` (`config.py`: setting nuevo; `security.crear_access_token`: parámetro de duración; `cuadrilla/router.py`: `/sesion/renovar`, `/logout`, dependencia `funcionario_actual` que protege `/reportes*`; `admin/service.py`: reutilizar `iniciar_sesion`); (5) reglas de seguridad (HTTPS, límite de intentos ya existente en `/login`, rechazar tokens de cuentas desactivadas, no registrar tokens en logs); (6) casos de prueba que el backend debe pasar (renueva dentro de 7 días; rechaza vencido; rechaza cuenta inactiva; peticiones normales no extienden; `/reportes` sin token → 401); (7) cómo usar el mock (`--dart-define=USAR_MOCK_AUTH=true`, credenciales falsas de demo, nunca en release) y cómo pasar al backend real (quitar el define).

- [ ] **Step 2: Verificación final**

Run: `flutter analyze`, `flutter test`, `flutter build apk --release`
Expected: sin errores de análisis; todos los tests PASS; `Built ...app-release.apk`.

- [ ] **Step 3: Commit**

```bash
git add docs RELEASES.md
git commit -m "docs(auth): agregar contrato del backend para el login con sesión de 7 días"
```

---

## Self-review

- **Cobertura del pedido:** login contra backend (Tasks 3, 6), sesión ≥7 días (constante `kDuracionSesion`, Task 2), renovación al ingresar (Task 4: `restaurar` + `AuthGate` en primer plano), cierre tras 7 días sin entrar (Task 4: sesión vencida y test «ciclo de 7 días»), mocks para endpoints futuros (Task 2), documento de contratos (Task 7).
- **Consistencia de tipos:** `Sesion`, `Funcionario`, `SesionStorage` (Task 1) → `AuthRepository` y excepciones (Task 2) → `HttpAuthRepository` (Task 3) → `AuthController` (Task 4) → `AuthGate`/`LoginScreen` (Task 6); nombres de métodos (`iniciarSesion`, `renovar`, `cerrarSesion`, `renovarSiCorresponde`) iguales en todas las tareas.
- **Dependencia con el backend:** la renovación real (`/sesion/renovar`) todavía no existe; con el backend actual el login funciona pero la renovación devuelve 404 y el controller la ignora (conserva la sesión) hasta que el backend cumpla el contrato.
- **Riesgo conocido:** `flutter_secure_storage` con AGP 9.3.1 / built-in Kotlin; se comprueba al final de Task 1 antes de construir encima.

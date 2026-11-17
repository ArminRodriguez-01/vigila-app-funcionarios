# Contrato del backend: login de funcionarios con sesión de 7 días

Documento para quien implemente el backend (`vigila-app/backend`, FastAPI). La app de funcionarios
(`vigila-app-funcionarios`) ya está lista y funciona con un mock; este documento dice qué debe
cumplir el backend para reemplazarlo.

- Base de las rutas: `https://vigila-app.onrender.com/api/v1/cuadrilla`
- Formato de errores (ya existe en el backend): `{"codigo": "...", "mensaje": "..."}`
- `mensaje` se muestra tal cual al funcionario: en español y sin detalles técnicos.

## 1. Política de sesión

| Regla | Valor |
|---|---|
| Duración del token | **7 días** completos desde que se emite |
| Renovación | La app llama a `/sesion/renovar` **cada vez que se abre** o vuelve a primer plano (máximo una vez cada 5 minutos) |
| Efecto de renovar | El token nuevo vale otros **7 días completos** desde ese momento |
| 7 días sin abrir la app | El token vence y la sesión se cierra: al abrir, la app muestra el login con «Tu sesión expiró» |
| Peticiones normales (`/reportes`…) | **No** extienden la sesión: solo `/sesion/renovar` lo hace |
| Sin conexión | La app **no** cierra la sesión; reintenta al volver a abrirla. Solo cierra por vencimiento local o por un 401 |
| Cuenta desactivada | Al renovar, el servidor responde 401 y la app cierra la sesión |

El vencimiento lo decide el servidor. La app calcula cuándo vence con `expira_en_segundos` y su
reloj local solo para no mostrar una pantalla inútil; si el reloj del teléfono estuviera mal, el
servidor igual rechaza el token vencido con 401 y la app vuelve al login.

## 2. Qué existe hoy y qué falta

| Pieza | Estado en `backend-api` | Acción |
|---|---|---|
| `POST /cuadrilla/login` | Existe. Entrega un token de **15 minutos** (`jwt_access_minutos`) | Cambiar la duración a 7 días (misma forma de respuesta) |
| `POST /cuadrilla/sesion/renovar` | No existe | **Crear** |
| `POST /cuadrilla/logout` | No existe | **Crear** (puede ser un no-op, ver §3.3) |
| `GET/POST /cuadrilla/reportes*` | Existen, **sin autenticación** | **Exigir** `Authorization: Bearer` |
| Dependencia `funcionario_actual` (`admin/deps.py`) | Existe; rechaza roles distintos de `funcionario` con 403 | Ajustar roles (ver §5) |

## 3. Endpoints

### 3.1 `POST /login` (existe; cambia la duración)

Request:
```json
{ "email": "ana@victoria.cl", "password": "********" }
```
Response `200`:
```json
{
  "access_token": "eyJhbGciOi...",
  "token_type": "bearer",
  "expira_en_segundos": 604800,
  "funcionario": {
    "id": "f3a1...",
    "email": "ana@victoria.cl",
    "nombre": "Ana Pérez",
    "rol": "funcionario",
    "activo": true
  }
}
```
La forma **no cambia** respecto a `TokenAdminOut`; solo `expira_en_segundos` pasa de `900` a `604800`.

| Status | `codigo` | Cuándo |
|---|---|---|
| 401 | `credenciales_invalidas` | Correo o clave incorrectos, o cuenta inactiva (no revelar cuál) |
| 429 | cualquiera | Demasiados intentos (límite existente) |

### 3.2 `POST /sesion/renovar` (nuevo)

Header: `Authorization: Bearer <token vigente>`. Sin cuerpo.

Response `200`: **mismo cuerpo que `/login`**, con un `access_token` nuevo y
`expira_en_segundos: 604800`. Lo que debe hacer el servidor, en orden:

1. Validar el token (firma, `exp`, rol). Un token **vencido no se renueva**.
2. Buscar al funcionario y comprobar que sigue **activo**.
3. Emitir un token nuevo (`iat` ahora, `exp` ahora + 7 días, `jti` nuevo).

| Status | `codigo` | Cuándo | Reacción de la app |
|---|---|---|---|
| 401 | `no_autenticado` o `sesion_expirada` | Sin header, token inválido o vencido | Cierra la sesión y muestra «Tu sesión expiró» |
| 401 | `cuenta_inactiva` | El funcionario fue desactivado | Cierra la sesión y muestra «Tu cuenta fue desactivada» |
| 5xx / timeout | — | Servidor caído o dormido | **No** cierra la sesión; reintenta después |

Hoy `decodificar_access_token` y `funcionario_actual` responden `no_autenticado` en todos los
casos 401; la app lo trata igual que `sesion_expirada`. `cuenta_inactiva` es opcional pero da un
mensaje más claro al funcionario.

### 3.3 `POST /logout` (nuevo, best-effort)

Header: `Authorization: Bearer <token>`. Response `204`, sin cuerpo. Debe ser **idempotente** y no
fallar con un token ya vencido (la app ignora cualquier error de esta llamada).

- Mínimo aceptable: no hacer nada (el token vence solo).
- Recomendado: guardar el `jti` en una lista de tokens revocados hasta su `exp`, y rechazarlo con
  `401 no_autenticado` en `funcionario_actual` y en `/sesion/renovar`.

### 3.4 Rutas de reportes (`/reportes`, `/reportes/{id}`, `/reportes/{id}/estado`)

Exigir `Authorization: Bearer <token>` con la dependencia de funcionario. La app **ya envía** el
header en todas las peticiones. Sin cambios en los cuerpos de request y response.

| Status | `codigo` | Reacción de la app |
|---|---|---|
| 401 | `no_autenticado` / `sesion_expirada` | Cierra la sesión, descarta las pantallas abiertas y vuelve al login |
| 403 | `sin_permiso` | Muestra el error; no cierra la sesión |

## 4. Formato del token

JWT HS256 firmado con `VIGILA_JWT_SECRETO` (ya existe).

| Claim | Valor |
|---|---|
| `sub` | `id` del funcionario |
| `rol` | `funcionario`, `cuadrilla` o `superadmin` (el del funcionario) |
| `iat` | instante de emisión |
| `exp` | `iat` + 7 días |
| `jti` | identificador único (recomendado: permite revocar y distinguir tokens) |

Configuración nueva: `VIGILA_CUADRILLA_SESION_DIAS=7`. **No cambiar** `jwt_access_minutos` (15):
lo usan también los vecinos y el panel de administración.

## 5. Cambios concretos en `vigila-app/backend`

- `app/core/config.py`: agregar `cuadrilla_sesion_dias: int = 7`.
- `app/core/security.py`: `crear_access_token(...)` acepta una duración opcional (por ejemplo
  `duracion: timedelta | None = None`, por defecto la de hoy) y agrega el claim `jti`.
- `app/features/cuadrilla/router.py`:
  - `login_cuadrilla`: usar la duración de 7 días y devolver `expira_en_segundos = dias * 86400`.
  - Agregar `POST /sesion/renovar` y `POST /logout`.
  - Agregar `Depends(funcionario_actual)` a las tres rutas de `/reportes*`.
- `app/features/admin/deps.py`: `funcionario_actual` hoy llama a
  `payload_con_rol(..., ROL_FUNCIONARIO)` y rechaza con 403 a quien tenga rol `superadmin` o
  `cuadrilla`, aunque `iniciar_sesion` les entregue token. Para `/cuadrilla/*` aceptar los tres
  roles de funcionario (`funcionario`, `cuadrilla`, `superadmin`) y seguir rechazando el rol de
  vecino (`usuario`) con 403.
- Límite de uso: `/sesion/renovar` **no** debe compartir el límite de `/login` (10 por minuto por
  IP): varias cuadrillas comparten la misma red móvil y se bloquearían entre sí. Usar un límite
  aparte, por funcionario (por ejemplo 30 por minuto).
- Migración: no hace falta tabla nueva salvo que se implemente la lista de revocados del §3.3.

## 6. Seguridad

- Solo HTTPS (Render ya lo fuerza).
- Nunca registrar tokens ni contraseñas en logs.
- Un token de funcionario no debe servir en rutas de vecinos ni al revés (los roles ya lo separan).
- Responder igual a «correo inexistente» y «clave incorrecta» (ya lo hace `iniciar_sesion`).
- Si se desactiva a un funcionario, su sesión debe dejar de funcionar a más tardar en su próxima
  renovación; `funcionario_actual` ya lo comprueba en cada petición.
- Considerar la instancia dormida de Render (plan gratuito): la primera renovación del día puede
  tardar 30–60 s. La app no bloquea su arranque por eso, pero conviene mantener el servicio
  despierto (ya existe el keep-alive en `app/core/keepalive.py`).

## 7. Casos de prueba que el backend debe pasar

Para fijar la hora en los tests, parchear `ahora_utc` (usado al emitir `iat`/`exp`) y, para que
PyJWT valide con la misma hora, usar `freezegun` o emitir tokens con `exp` explícito en el pasado.

1. `/login` correcto: `expira_en_segundos == 604800` y el JWT tiene `exp - iat == 7 días`.
2. `/sesion/renovar` con un token del día 3: responde 200, token distinto (otro `jti`) y
   `exp` = día 3 + 7 días.
3. `/sesion/renovar` con un token de 7 días y 1 segundo: 401 (`no_autenticado` o `sesion_expirada`).
4. `/sesion/renovar` sin header o con un token inventado: 401.
5. `/sesion/renovar` de un funcionario desactivado después de iniciar sesión: 401 `cuenta_inactiva`.
6. Una petición normal (`GET /reportes`) no modifica el `exp` ni devuelve un token nuevo.
7. `/reportes` sin token: 401. Con token válido: 200. Con token de vecino: 403 `sin_permiso`.
8. `/reportes` con token de `superadmin` o `cuadrilla`: 200.
9. `/logout`: 204 con token válido, 204 repetido y 204 con token vencido; si hay lista de revocados,
   luego `/sesion/renovar` con ese token responde 401.
10. 11 logins por minuto desde una IP bloquean el siguiente `/login`, pero no bloquean
    `/sesion/renovar`.

## 8. Cómo se comporta la app (para depurar)

| Momento | Qué hace la app |
|---|---|
| Abrir con sesión guardada y vigente | Entra de inmediato a la lista y renueva en segundo plano |
| Abrir con la sesión vencida (más de 7 días) | Borra la sesión, muestra el login con «Tu sesión expiró»; **no** llama al servidor |
| Volver a primer plano | Si pasaron 5 minutos desde la última renovación, renueva; si la sesión ya venció localmente, cierra |
| Respuesta 401 en cualquier llamada de reportes | Cierra la sesión y vuelve al login |
| Sin red o 5xx al renovar | Conserva la sesión y reintenta en la siguiente apertura |
| Cerrar sesión (botón) | Borra la sesión local y llama a `/logout` (si falla, la ignora) |

La sesión se guarda cifrada en el dispositivo (Keystore de Android). Si ese almacenamiento
fallara, la app lo trata como «sin sesión» y pide ingresar de nuevo.

## 9. El mock y cómo pasar al backend real

Mientras el backend no cumpla este contrato se puede desarrollar con el mock:

```bash
flutter run --dart-define=USAR_MOCK_AUTH=true
```

- Credenciales de demostración del mock: `demo@victoria.cl` / `demo-1234` (solo existen en el mock).
- El mock imita este contrato: sesiones de 7 días, renovación y cierre. No guarda nada entre
  ejecuciones: al reiniciar la app hay que ingresar de nuevo.
- **El mock nunca se activa en una compilación release**, aunque se pase el parámetro.
- Para usar el backend real basta con **no** pasar `USAR_MOCK_AUTH`. Con el backend actual
  (token de 15 minutos y sin `/sesion/renovar`) el login funciona, pero la renovación recibe un
  404 que la app ignora: la sesión dura lo que dure el token del servidor.

Código relevante en la app: `lib/core/auth/` (`auth_controller.dart` aplica la política de
sesión; `http_auth_repository.dart` implementa este contrato; `mock_auth_repository.dart` lo
simula) y `test/auth/` (los tests que fijan cada regla de este documento).

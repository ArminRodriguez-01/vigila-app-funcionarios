# Publicar una versión (releases y actualización obligatoria)

La app consulta los Releases de este repositorio al abrirse. Si existe uno con una versión
**mayor** que la instalada, muestra "Hay una nueva versión disponible" y no deja usarla hasta
actualizar. Por eso, **publicar un release equivale a obligar a todos a actualizar**.

## Una sola vez: llave de firma

Android solo permite actualizar un APK si está firmado con la **misma llave** que el instalado.
Si se pierde la llave, nadie podrá actualizar (habría que desinstalar e instalar de nuevo).

1. Crear la llave (guárdala en un lugar seguro y haz una copia; **nunca** la subas al repo):

   ```bash
   keytool -genkey -v -keystore vigila-funcionarios.jks -keyalg RSA -keysize 2048 -validity 10000 -alias vigila
   ```

2. En GitHub: *Settings → Secrets and variables → Actions → New repository secret*:

   | Secreto | Valor |
   |---|---|
   | `ANDROID_KEYSTORE_BASE64` | contenido de la llave en base64 (ver abajo) |
   | `ANDROID_STORE_PASSWORD` | contraseña del keystore |
   | `ANDROID_KEY_PASSWORD` | contraseña de la llave |
   | `ANDROID_KEY_ALIAS` | `vigila` (el alias usado arriba) |

   Para obtener el base64 en PowerShell:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("vigila-funcionarios.jks")) | Set-Clipboard
   ```

   (En Linux/macOS: `base64 -w0 vigila-funcionarios.jks`.)

3. Opcional, para compilar un release firmado en tu computador: crea `android/key.properties`
   (ya está en `.gitignore`) con `storeFile`, `storePassword`, `keyPassword` y `keyAlias`.

## Cada release

1. Sube la versión en `pubspec.yaml`. El número después del `+` debe aumentar siempre:
   `version: 1.1.0+2`.
2. Haz commit y push a `main`.
3. Crea y sube la etiqueta, con **el mismo número** que `pubspec.yaml` y precedido de `v`:

   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

4. El workflow `release` compila el APK firmado y lo publica en *Releases*. Si la etiqueta no
   coincide con `pubspec.yaml` o faltan los secretos, falla sin publicar nada.

## Cómo se comporta la app
- Revisa al abrir y al volver de segundo plano (como máximo cada 2 minutos).
- Si no hay internet o GitHub no responde, **no bloquea**.
- Ignora releases en borrador o marcados como pre-release; sirven para probar sin bloquear a nadie.
- En modo debug no bloquea. Para probar la pantalla:
  `flutter run --dart-define=PROBAR_ACTUALIZACION=true`.
- La primera versión con este sistema debe instalarse a mano; las apps anteriores no lo incluyen.

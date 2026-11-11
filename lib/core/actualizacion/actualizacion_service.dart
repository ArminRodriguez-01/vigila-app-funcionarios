import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import 'actualizacion_config.dart';
import 'comparar_versiones.dart';

class InfoActualizacion {
  const InfoActualizacion({
    required this.versionNueva,
    required this.versionInstalada,
    required this.urlDescarga,
  });

  final String versionNueva;
  final String versionInstalada;
  final String urlDescarga;
}

class ActualizacionService {
  ActualizacionService._();

  /// Busca en los releases de GitHub una versión más nueva que la instalada.
  /// Devuelve null si está al día o si no se pudo consultar (sin internet, límite de
  /// GitHub, etc.): ante la duda la app sigue funcionando.
  static Future<InfoActualizacion?> buscar() async {
    if (kDebugMode && !ActualizacionConfig.probarEnDebug) return null;
    try {
      final instalada = (await PackageInfo.fromPlatform()).version;
      final respuesta = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/${ActualizacionConfig.repositorio}/releases?per_page=20',
            ),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));
      if (respuesta.statusCode != 200) return null;

      InfoActualizacion? mejor;
      for (final item in jsonDecode(respuesta.body) as List<dynamic>) {
        final release = item as Map<String, dynamic>;
        if (release['draft'] == true || release['prerelease'] == true) continue;

        final tag = (release['tag_name'] ?? '').toString();
        if (!tag.startsWith(ActualizacionConfig.prefijoTag)) continue;
        final version = tag.substring(ActualizacionConfig.prefijoTag.length);

        if (!esVersionMasNueva(version, instalada)) continue;
        if (mejor != null && !esVersionMasNueva(version, mejor.versionNueva)) continue;

        mejor = InfoActualizacion(
          versionNueva: version,
          versionInstalada: instalada,
          urlDescarga: _urlApk(release),
        );
      }
      return mejor;
    } catch (e) {
      debugPrint('No se pudo buscar actualizaciones: $e');
      return null;
    }
  }

  /// Enlace directo al APK del release; si no hay, la página del release.
  static String _urlApk(Map<String, dynamic> release) {
    final assets = release['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map && (asset['name'] ?? '').toString().toLowerCase().endsWith('.apk')) {
          final url = asset['browser_download_url']?.toString();
          if (url != null && url.isNotEmpty) return url;
        }
      }
    }
    return (release['html_url'] ?? '').toString();
  }
}

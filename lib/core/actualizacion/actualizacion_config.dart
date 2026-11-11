/// Datos propios de esta app para el sistema de actualización obligatoria.
class ActualizacionConfig {
  ActualizacionConfig._();

  /// Repositorio de GitHub donde se publican los releases con el APK.
  static const String repositorio = 'ArminRodriguez-01/vigila-app-funcionarios';

  /// Prefijo de las etiquetas de release de esta app (ej: v1.2.0).
  static const String prefijoTag = 'v';

  static const String nombreApp = 'Vigila Funcionarios';

  /// En modo debug no se bloquea (un build local siempre parecería "viejo").
  /// Para probar la pantalla: flutter run --dart-define=PROBAR_ACTUALIZACION=true
  static const bool probarEnDebug = bool.fromEnvironment('PROBAR_ACTUALIZACION');
}

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // App ID de OneSignal vinculado al panel de funcionarios
  static const String oneSignalAppId = "9d230673-ad1e-4559-8056-bd9f70db2fd8";

  Function(String reporteId)? onIncidenciaRecibida;

  Future<void> inicializar() async {
    try {
      if (oneSignalAppId != "ONESIGNAL_APP_ID_AQUI") {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
        OneSignal.initialize(oneSignalAppId);

        // Solicitar permisos de notificación (Android 13+)
        await OneSignal.Notifications.requestPermission(true);

        // Listener cuando el usuario toca la notificación (incluso con app cerrada)
        OneSignal.Notifications.addClickListener((event) {
          final data = event.notification.additionalData;
          if (data != null && data.containsKey('reporte_id')) {
            final reporteId = data['reporte_id'].toString();
            onIncidenciaRecibida?.call(reporteId);
          }
        });
      }
    } catch (e) {
      debugPrint('Aviso OneSignal inicialización: $e');
    }
  }
}

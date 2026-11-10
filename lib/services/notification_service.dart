import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // App ID de OneSignal vinculado al panel de funcionarios
  static const String oneSignalAppId = "9d230673-ad1e-4559-8056-bd9f70db2fd8";

  Function(String reporteId)? _onIncidenciaRecibida;

  // Si la notificación se toca con la app cerrada, el aviso puede llegar antes de que
  // exista quien lo atienda. Se guarda aquí y se entrega apenas haya un receptor.
  String? _reportePendiente;

  set onIncidenciaRecibida(Function(String reporteId)? callback) {
    _onIncidenciaRecibida = callback;
    _entregarPendiente();
  }

  void _recibirToque(String reporteId) {
    _reportePendiente = reporteId;
    _entregarPendiente();
  }

  void _entregarPendiente() {
    final callback = _onIncidenciaRecibida;
    final reporteId = _reportePendiente;
    if (callback == null || reporteId == null) return;
    _reportePendiente = null;
    callback(reporteId);
  }

  Future<void> inicializar() async {
    try {
      if (oneSignalAppId != "ONESIGNAL_APP_ID_AQUI") {
        // Logs detallados solo al desarrollar; en la app publicada solo advertencias.
        OneSignal.Debug.setLogLevel(kDebugMode ? OSLogLevel.verbose : OSLogLevel.warn);
        OneSignal.initialize(oneSignalAppId);

        // Listener cuando el usuario toca la notificación (incluso con app cerrada)
        OneSignal.Notifications.addClickListener((event) {
          final data = event.notification.additionalData;
          if (data != null && data.containsKey('reporte_id')) {
            _recibirToque(data['reporte_id'].toString());
          }
        });

        // Solicitar permisos de notificación (Android 13+)
        await OneSignal.Notifications.requestPermission(true);
      }
    } catch (e) {
      debugPrint('Aviso OneSignal inicialización: $e');
    }
  }
}

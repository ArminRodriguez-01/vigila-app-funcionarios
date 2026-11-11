import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/actualizacion/actualizacion_gate.dart';
import 'screens/lista_incidencias_screen.dart';
import 'screens/detalle_incidencia_screen.dart';
import 'services/cuadrilla_api_service.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pantalla completa "de borde a borde" en todas las versiones de Android.
  // Android 15+ lo impone igual; activarlo siempre hace que la app se vea igual en todos
  // los teléfonos. Las barras quedan transparentes y cada pantalla usa SafeArea para no
  // quedar debajo de la cámara, la barra de estado ni los botones/gestos del sistema.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // el AppBar verde se dibuja detrás
      statusBarIconBrightness: Brightness.light, // íconos blancos sobre el verde (Android)
      statusBarBrightness: Brightness.dark, // íconos blancos (iOS)
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Inicializar localización para fechas en español
  await initializeDateFormatting('es', null);

  // Inicializar servicio de notificaciones Push (OneSignal)
  final notifService = NotificationService.instance;
  await notifService.inicializar();

  // Configurar apertura directa de incidencia al pulsar notificación push
  notifService.onIncidenciaRecibida = (reporteId) async {
    try {
      final incidencia = await CuadrillaApiService.instance.obtenerDetalle(reporteId);
      final navegador = await _esperarNavegador();
      navegador?.push(
        MaterialPageRoute(
          builder: (_) => DetalleIncidenciaScreen(incidencia: incidencia),
        ),
      );
    } catch (e) {
      debugPrint('No se pudo abrir la incidencia de la notificación: $e');
    }
  };

  runApp(const VigilaFuncionariosApp());
}

/// Al abrir la app desde una notificación, la pantalla puede no estar lista todavía.
/// Espera hasta 10 segundos a que exista el navegador antes de abrir la incidencia.
Future<NavigatorState?> _esperarNavegador() async {
  for (var intento = 0; intento < 100; intento++) {
    final navegador = navigatorKey.currentState;
    if (navegador != null) return navegador;
    await Future.delayed(const Duration(milliseconds: 100));
  }
  debugPrint('La app no quedó lista a tiempo para abrir la incidencia de la notificación.');
  return null;
}

class VigilaFuncionariosApp extends StatelessWidget {
  const VigilaFuncionariosApp({super.key});

  @override
  Widget build(BuildContext context) {
    const Color colorInstitucional = Color(0xFF0F766E); // Verde Esmeralda Municipal de Victoria

    return MaterialApp(
      title: 'Vigila Funcionarios',
      navigatorKey: navigatorKey,
      // Bloquea el uso de la app si hay un release más nuevo en GitHub.
      builder: (context, child) => ActualizacionGate(child: child ?? const SizedBox.shrink()),
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: colorInstitucional,
          primary: colorInstitucional,
          secondary: const Color(0xFF2563EB),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 2,
          backgroundColor: colorInstitucional,
          foregroundColor: Colors.white,
          // Barra de estado transparente con íconos blancos sobre el verde, en todas las pantallas.
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const ListaIncidenciasScreen(),
    );
  }
}

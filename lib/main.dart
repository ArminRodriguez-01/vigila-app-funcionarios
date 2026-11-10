import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/lista_incidencias_screen.dart';
import 'screens/detalle_incidencia_screen.dart';
import 'services/cuadrilla_api_service.dart';
import 'services/notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configurar la barra superior del sistema (Status Bar) para que coincida con el verde institucional
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF0F766E), // Mismo verde esmeralda institucional
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
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

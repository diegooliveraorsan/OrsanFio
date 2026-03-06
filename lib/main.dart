import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'log_in_log_up/login_screen.dart';
import 'dashboard_screen.dart';
import 'notification_handler.dart';
import 'document_reader/document_reader_service.dart';
import 'face_api/face_api_service.dart';
import 'log_in_log_up/registro.dart';
import 'animaciones/simple_loading_dialog.dart';
import 'variables_globales.dart';

import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';

// CONFIGURAR navigatorKey GLOBAL A NIVEL DE MAIN
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // CONFIGURAR EL NAVIGATOR KEY EN EL HANDLER ANTES DE INICIALIZAR
  NotificationHandler.navigatorKey = navigatorKey;

  // INICIALIZAR NOTIFICACIONES DESPUÉS DE FIREBASE
  NotificationHandler.initializeNotifications();

  runApp(const OrsanfioApp());
}

class OrsanfioApp extends StatelessWidget {
  const OrsanfioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Orsanfio',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(
          primary: GlobalVariables.blueDarkColor,
          secondary: GlobalVariables.blueDarkColor,
        ),
        // Color del cursor en campos de texto
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: GlobalVariables.blueDarkColor,
        ),
        // Estilo de borde para inputs enfocados
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: GlobalVariables.blueDarkColor, width: 2),
          ),
        ),
      ),
      navigatorKey: navigatorKey,
      home: const UpdateCheckScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// NUEVA PANTALLA PARA VERIFICAR ACTUALIZACIÓN
class UpdateCheckScreen extends StatefulWidget {
  const UpdateCheckScreen({super.key});

  @override
  State<UpdateCheckScreen> createState() => _UpdateCheckScreenState();
}

class _UpdateCheckScreenState extends State<UpdateCheckScreen> {
  bool _isChecking = true;
  bool _updateAvailable = false;
  Map<String, dynamic>? _updateData;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  Future<void> _checkForUpdates() async {
    try {
      GlobalVariables.debugPrint('🔍 Verificando actualizaciones de la app...');

      String currentVersion = GlobalVariables.appVersion;
      String platform = Platform.isAndroid ? "android" : "ios";

      GlobalVariables.debugPrint('📱 Información del dispositivo:');
      GlobalVariables.debugPrint('   - Versión actual: $currentVersion');
      GlobalVariables.debugPrint('   - Plataforma: $platform');
      GlobalVariables.debugPrint('   - URL API: ${GlobalVariables.baseUrl}/ActualizacionDisponible/api/v1/');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/ActualizacionDisponible/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "tipo_dispositivo": platform,
          "codigo_version": currentVersion,
        }),
      ).timeout(const Duration(seconds: 10));

      GlobalVariables.debugPrint('📥 Response ActualizacionDisponible:');
      GlobalVariables.debugPrint('   - Status: ${response.statusCode}');
      GlobalVariables.debugPrint('   - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          bool updateAvailable = responseData['actualizacion'] == true;

          GlobalVariables.debugPrint('🎯 Resultado verificación:');
          GlobalVariables.debugPrint('   - Actualización disponible: $updateAvailable');
          GlobalVariables.debugPrint('   - Versión actual: ${responseData['version_actual']}');
          GlobalVariables.debugPrint('   - Versión nueva: ${responseData['version_nueva']}');
          GlobalVariables.debugPrint('   - URL actualización: ${responseData['url_actualizacion']}');

          if (updateAvailable) {
            setState(() {
              _updateAvailable = true;
              _updateData = responseData;
              _isChecking = false;
            });
          } else {
            setState(() {
              _isChecking = false;
              _updateAvailable = false;
            });

            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SplashScreen()),
              );
            });
          }
        } else {
          GlobalVariables.debugPrint('⚠️ Error en API de actualización: ${responseData['mensaje']}');
          _continueWithNormalFlow();
        }
      } else {
        GlobalVariables.debugPrint('❌ Error HTTP en verificación de actualización: ${response.statusCode}');
        _continueWithNormalFlow();
      }
    } catch (e) {
      GlobalVariables.debugPrint('❌ Error verificando actualización: $e');
      _continueWithNormalFlow();
    }
  }

  void _continueWithNormalFlow() {
    setState(() {
      _isChecking = false;
      _updateAvailable = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SplashScreen()),
      );
    });
  }

  Future<void> _launchUpdateURL() async {
    if (_updateData != null && _updateData!['url_actualizacion'] != null) {
      final url = _updateData!['url_actualizacion'];
      GlobalVariables.debugPrint('🚀 Intentando abrir URL: $url');

      try {
        if (await canLaunch(url)) {
          await launch(url);
        } else {
          _showErrorDialog('No se puede abrir la URL de actualización');
        }
      } catch (e) {
        GlobalVariables.debugPrint('❌ Error al abrir URL: $e');
        _showErrorDialog('Error al abrir la tienda de aplicaciones');
      }
    } else {
      _showErrorDialog('No hay URL de actualización disponible');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _skipUpdate() {
    _continueWithNormalFlow();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _isChecking
            ? _buildCheckingUI()
            : _updateAvailable
            ? _buildUpdateAvailableUI()
            : const SizedBox(),
      ),
    );
  }

  Widget _buildCheckingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(GlobalVariables.blueDarkColor),
        ),
        const SizedBox(height: 20),
        Text(
          'Verificando actualizaciones...',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateAvailableUI() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.system_update,
            size: 80,
            color: GlobalVariables.blueDarkColor,
          ),
          const SizedBox(height: 24),
          Text(
            'Actualización disponible',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: GlobalVariables.blueDarkColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Versión actual: ${GlobalVariables.appVersion}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          if (_updateData != null && _updateData!['version_nueva'] != null)
            Text(
              'Nueva versión: ${_updateData!['version_nueva']}',
              style: TextStyle(
                fontSize: 16,
                color: GlobalVariables.blueDarkColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Es necesario actualizar la aplicación para continuar.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          const Divider(color: Colors.grey, thickness: 1),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _launchUpdateURL,
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalVariables.blueDarkColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Actualizar ahora',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _checkExistingSession();
        });
      }
    });
  }

  Future<void> _checkExistingSession() async {
    try {
      GlobalVariables.debugPrint('🔍 Verificando si hay sesión iniciada...');

      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      final String deviceToken =
          fcmToken ?? 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';

      GlobalVariables.debugPrint('📱 Token del dispositivo: $deviceToken');
      GlobalVariables.debugPrint('🌐 Llamando a API SesionIniciada...');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/SesionIniciada/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "token_dispositivo": deviceToken,
        }),
      ).timeout(const Duration(seconds: 10));

      GlobalVariables.debugPrint('📥 Response SesionIniciada - Status: ${response.statusCode}');
      GlobalVariables.debugPrint('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final bool sesionIniciada = responseData['sesion_iniciada'] == true;

        GlobalVariables.debugPrint('🎯 Sesión iniciada: $sesionIniciada');

        if (sesionIniciada) {
          GlobalVariables.debugPrint('🚀 Sesión activa detectada, navegando al dashboard...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(userData: responseData),
            ),
          );
        } else {
          GlobalVariables.debugPrint('🔐 No hay sesión activa, mostrando onboarding...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      } else {
        GlobalVariables.debugPrint('⚠️ Error en API SesionIniciada, mostrando onboarding...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    } catch (e) {
      GlobalVariables.debugPrint('❌ Error verificando sesión: $e');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/logo_fio.png',
                height: 150,
                width: 150,
                fit: BoxFit.contain,
              ),
              if (GlobalVariables.isDebugMode) ...[
                const SizedBox(height: 20),
                Text(
                  'Versión: ${GlobalVariables.appVersion}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// ONBOARDING SCREEN
// ---------------------------------------------------------------------
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final List<Map<String, dynamic>> _cards = [
    {
      'icon': Icons.credit_card,
      'title': 'Línea de Crédito',
      'description': 'Accede a crédito preaprobado al instante',
    },
    {
      'icon': Icons.payment,
      'title': 'Pagos Instantáneos',
      'description': 'Procesa tus transacciones en segundos',
    },
    {
      'icon': Icons.face,
      'title': 'Seguridad Biométrica',
      'description': 'Protección avanzada con reconocimiento facial',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationHandler.initializeNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 40.0),
              child: Text(
                'Bienvenido',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                itemCount: _cards.length,
                itemBuilder: (context, index) {
                  final card = _cards[index];
                  return _buildCard(
                    icon: card['icon'],
                    title: card['title'],
                    description: card['description'],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _navigateToAuthScreen(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalVariables.blueDarkColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GlobalVariables.blueDarkColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 30, color: GlobalVariables.blueDarkColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: GlobalVariables.blueDarkColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToAuthScreen(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthSelectionScreen()),
    );
  }
}

// ---------------------------------------------------------------------
// AUTENTICACIÓN: SELECCIÓN (INGRESAR / CREAR CUENTA)
// ---------------------------------------------------------------------
class AuthSelectionScreen extends StatefulWidget {
  const AuthSelectionScreen({super.key});

  @override
  State<AuthSelectionScreen> createState() => _AuthSelectionScreenState();
}

class _AuthSelectionScreenState extends State<AuthSelectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Image.asset(
                    'assets/images/logo_fio.png',
                    height: 100,
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 30),
                const Center(
                  child: Text(
                    'Pagos seguros y rápidos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.black,
                    indicator: BoxDecoration(
                      color: GlobalVariables.blueDarkColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    padding: const EdgeInsets.all(4),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 0),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 16,
                    ),
                    tabs: [
                      Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: const Text('Ingresar'),
                      ),
                      Container(
                        width: double.infinity,
                        alignment: Alignment.center,
                        child: const Text('Crear cuenta'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: TabBarView(
                    controller: _tabController,
                    children: const [
                      LoginContent(),
                      RegisterFormContent(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// LOGIN (INGRESAR) CON INDICADOR LOCAL Y NAVEGACIÓN CON GLOBAL KEY
// ---------------------------------------------------------------------
class LoginContent extends StatefulWidget {
  const LoginContent({super.key});

  @override
  State<LoginContent> createState() => _LoginContentState();
}

class _LoginContentState extends State<LoginContent> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _deviceToken = 'generando...';
  bool _mostrarPassword = false;

  String? _emailErrorText;
  String? _passwordErrorText;

  @override
  void initState() {
    super.initState();
    _initializeFCMToken();
    _emailController.addListener(_validarEmailEnTiempoReal);
    _passwordController.addListener(_validarPasswordEnTiempoReal);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validarEmailEnTiempoReal);
    _passwordController.removeListener(_validarPasswordEnTiempoReal);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validarEmailEnTiempoReal() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailErrorText = null);
    } else {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      setState(() {
        _emailErrorText = emailRegex.hasMatch(email) ? null : 'Formato de email inválido';
      });
    }
  }

  void _validarPasswordEnTiempoReal() {
    final password = _passwordController.text;
    setState(() {
      _passwordErrorText = password.isEmpty ? 'La contraseña no puede estar vacía' : null;
    });
  }

  String _getPlatform() {
    if (Platform.isAndroid) return "android";
    if (Platform.isIOS) return "ios";
    return "unknown";
  }

  Future<String> _getFCMToken() async {
    try {
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      GlobalVariables.debugPrint('✅ Token FCM obtenido: $fcmToken');
      return fcmToken ?? 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      GlobalVariables.debugPrint('❌ Error obteniendo token FCM: $e');
      return 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _initializeFCMToken() async {
    final token = await _getFCMToken();
    if (mounted) setState(() => _deviceToken = token);
  }

  Future<void> _login() async {
    _validarEmailEnTiempoReal();
    _validarPasswordEnTiempoReal();

    if (_emailErrorText != null || _passwordErrorText != null ||
        _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      GlobalSnackBars.mostrarError(context, 'Por favor completa los campos correctamente');
      return;
    }

    setState(() => _isLoading = true);

    try {
      GlobalVariables.debugPrint('🔍 Enviando solicitud de login...');
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/IniciarSesion/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "mail": _emailController.text.trim(),
          "password": _passwordController.text,
          "token_dispositivo": _deviceToken,
          "tipo_dispositivo": _getPlatform(),
        }),
      ).timeout(const Duration(seconds: 10));

      GlobalVariables.debugPrint('📥 Respuesta recibida - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        GlobalVariables.debugPrint('📦 Datos decodificados: $data');
        if (data['error'] == null) {
          GlobalSnackBars.mostrarExito(context, 'Login exitoso');
          _navigateToDashboard(data);
        } else {
          GlobalSnackBars.mostrarError(context, data['error']);
        }
      } else {
        GlobalSnackBars.mostrarError(context, 'Error ${response.statusCode}: Error del servidor');
      }
    } catch (e) {
      GlobalVariables.debugPrint('❌ Excepción en login: $e');
      GlobalSnackBars.mostrarError(context, 'Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDashboard(Map<String, dynamic> responseData) {
    GlobalVariables.debugPrint('🚀 Navegando al dashboard...');
    Map<String, dynamic> dispositivoActual = {};
    if (responseData['dispositivos'] != null && responseData['dispositivos'].isNotEmpty) {
      dispositivoActual = responseData['dispositivos'][0];
    }
    final dashboardData = {
      ...responseData,
      'sesion_iniciada': true,
      'dispositivo_actual': dispositivoActual,
    };
    GlobalVariables.debugPrint('📦 Datos para dashboard: $dashboardData');

    try {
      navigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(
          builder: (context) => ErrorBoundary(
            child: DashboardScreen(userData: dashboardData),
          ),
        ),
      );
      GlobalVariables.debugPrint('➡️ Navegación ejecutada con navigatorKey');
    } catch (e, stack) {
      GlobalVariables.debugPrint('❌ Error al navegar a DashboardScreen: $e');
      GlobalVariables.debugPrint('Stack trace: $stack');
    }
  }

  void _navigateToRecuperarContrasena() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RecuperarContrasenaScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        children: [
          // Campo Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            decoration: GlobalInputStyles.inputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'ejemplo@correo.com',
              prefixIcon: Icons.email_outlined,
            ).copyWith(errorText: _emailErrorText),
          ),
          const SizedBox(height: 15),

          // Campo Contraseña
          TextFormField(
            controller: _passwordController,
            obscureText: !_mostrarPassword,
            decoration: GlobalInputStyles.inputDecoration(
              labelText: 'Contraseña',
              hintText: 'Ingresa tu contraseña',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _mostrarPassword ? Icons.visibility_off : Icons.visibility,
                  color: GlobalVariables.blueDarkColor,
                ),
                onPressed: () => setState(() => _mostrarPassword = !_mostrarPassword),
              ),
            ).copyWith(errorText: _passwordErrorText),
          ),
          const SizedBox(height: 15),

          // Enlace "¿Olvidaste tu contraseña?"
          GestureDetector(
            onTap: _navigateToRecuperarContrasena,
            child: Container(
              alignment: Alignment.centerRight,
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                  fontSize: 14,
                  color: GlobalVariables.blueDarkColor,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),

          // Botón Ingresar
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalVariables.blueDarkColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                'Ingresar',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.05),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// REGISTRO (CREAR CUENTA) CON INDICADOR LOCAL Y NAVEGACIÓN CON GLOBAL KEY
// ---------------------------------------------------------------------
class RegisterFormContent extends StatefulWidget {
  const RegisterFormContent({super.key});

  @override
  State<RegisterFormContent> createState() => _RegisterFormContentState();
}

class _RegisterFormContentState extends State<RegisterFormContent> {
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String _deviceToken = 'generando...';

  bool _mostrarPassword = false;
  bool _mostrarConfirmPassword = false;

  String? _aliasErrorText;
  String? _telefonoErrorText;
  String? _emailErrorText;
  String? _passwordErrorText;
  String? _confirmPasswordErrorText;

  bool _passwordTieneLongitud = false;
  bool _passwordTieneMayuscula = false;
  bool _passwordTieneNumero = false;
  bool _passwordTieneSimbolo = false;

  @override
  void initState() {
    super.initState();
    _initializeFCMToken();

    _aliasController.addListener(_validarAlias);
    _telefonoController.addListener(_validarTelefono);
    _emailController.addListener(_validarEmail);
    _passwordController.addListener(_validarPassword);
    _confirmPasswordController.addListener(_validarConfirmPassword);
  }

  @override
  void dispose() {
    _aliasController.removeListener(_validarAlias);
    _telefonoController.removeListener(_validarTelefono);
    _emailController.removeListener(_validarEmail);
    _passwordController.removeListener(_validarPassword);
    _confirmPasswordController.removeListener(_validarConfirmPassword);
    _aliasController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validarAlias() {
    setState(() {
      _aliasErrorText = _aliasController.text.trim().isEmpty ? 'El alias no puede estar vacío' : null;
    });
  }

  void _validarTelefono() {
    final digits = _telefonoController.text;
    setState(() {
      if (digits.isEmpty) {
        _telefonoErrorText = 'Ingresa el teléfono';
      } else if (digits.length != 11) {
        _telefonoErrorText = 'El teléfono debe tener 11 dígitos';
      } else {
        _telefonoErrorText = null;
      }
    });
  }

  void _validarEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailErrorText = 'Ingresa un correo electrónico');
      return;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    setState(() {
      _emailErrorText = emailRegex.hasMatch(email) ? null : 'Formato de email inválido';
    });
  }

  void _validarPassword() {
    final pass = _passwordController.text;
    setState(() {
      _passwordTieneLongitud = pass.length >= 8;
      _passwordTieneMayuscula = RegExp(r'[A-Z]').hasMatch(pass);
      _passwordTieneNumero = RegExp(r'[0-9]').hasMatch(pass);
      _passwordTieneSimbolo = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass);

      if (pass.isEmpty) {
        _passwordErrorText = 'Ingresa una contraseña';
      } else if (!(_passwordTieneLongitud && _passwordTieneMayuscula && _passwordTieneNumero && _passwordTieneSimbolo)) {
        _passwordErrorText = 'La contraseña no cumple los requisitos de seguridad';
      } else {
        _passwordErrorText = null;
      }
    });
    _validarConfirmPassword();
  }

  void _validarConfirmPassword() {
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    setState(() {
      if (confirm.isEmpty) {
        _confirmPasswordErrorText = 'Confirma tu contraseña';
      } else if (pass != confirm) {
        _confirmPasswordErrorText = 'Las contraseñas no coinciden';
      } else {
        _confirmPasswordErrorText = null;
      }
    });
  }

  void _handlePhoneInput(String value) {
    final numbersOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    if (numbersOnly != value) {
      _telefonoController.text = numbersOnly;
      _telefonoController.selection = TextSelection.fromPosition(
        TextPosition(offset: numbersOnly.length),
      );
    }
  }

  Future<String> _getFCMToken() async {
    try {
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      GlobalVariables.debugPrint('✅ Token FCM obtenido: $fcmToken');
      return fcmToken ?? 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      GlobalVariables.debugPrint('❌ Error obteniendo token FCM: $e');
      return 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _initializeFCMToken() async {
    final token = await _getFCMToken();
    if (mounted) setState(() => _deviceToken = token);
  }

  String _getPlatform() {
    if (Platform.isAndroid) return "android";
    if (Platform.isIOS) return "ios";
    return "unknown";
  }

  Future<void> _loginAutomatico(String email, String password) async {
    GlobalVariables.debugPrint('🔄 Ejecutando login automático...');
    try {
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/IniciarSesion/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "mail": email,
          "password": password,
          "token_dispositivo": _deviceToken,
          "tipo_dispositivo": _getPlatform(),
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        GlobalVariables.debugPrint('✅ Login automático exitoso');
        Map<String, dynamic> dispositivoActual = {};
        if (data['dispositivos'] != null && data['dispositivos'].isNotEmpty) {
          dispositivoActual = data['dispositivos'][0];
        }
        final dashboardData = {
          ...data,
          'sesion_iniciada': true,
          'dispositivo_actual': dispositivoActual,
        };

        // Usar navigatorKey para navegar al dashboard, sin usar context
        navigatorKey.currentState?.pushReplacement(
          MaterialPageRoute(
            builder: (context) => ErrorBoundary(
              child: DashboardScreen(userData: dashboardData),
            ),
          ),
        );
      } else {
        // Si hay error, intentar mostrar mensaje con el contexto global si está disponible
        if (navigatorKey.currentContext != null) {
          GlobalSnackBars.mostrarError(navigatorKey.currentContext!, 'Error en login automático');
        } else {
          GlobalVariables.debugPrint('❌ Error en login automático: no hay contexto para mostrar snackbar');
        }
      }
    } catch (e) {
      GlobalVariables.debugPrint('❌ Error en login automático: $e');
      if (navigatorKey.currentContext != null) {
        GlobalSnackBars.mostrarError(navigatorKey.currentContext!, 'Error en login automático: $e');
      }
    }
  }

  Future<void> _crearUsuario() async {
    _validarAlias();
    _validarTelefono();
    _validarEmail();
    _validarPassword();
    _validarConfirmPassword();

    if (_aliasErrorText != null ||
        _telefonoErrorText != null ||
        _emailErrorText != null ||
        _passwordErrorText != null ||
        _confirmPasswordErrorText != null) {
      GlobalSnackBars.mostrarError(context, 'Corrige los errores antes de continuar');
      return;
    }

    setState(() => _isLoading = true);

    try {
      GlobalVariables.debugPrint('🔍 Enviando solicitud de creación de usuario...');
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CrearUsuario/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "alias_comprador": _aliasController.text.trim(),
          "telefono_comprador": _telefonoController.text,
          "mail": _emailController.text.trim(),
          "pswrd_nuevo_usuario": _passwordController.text,
          "token_dispositivo": _deviceToken,
          "tipo_dispositivo": _getPlatform(),
        }),
      ).timeout(const Duration(seconds: 15));

      GlobalVariables.debugPrint('📥 Respuesta recibida - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        GlobalVariables.debugPrint('📦 Datos decodificados: $data');
        if (data['respuesta']?['success'] == true) {
          GlobalSnackBars.mostrarExito(context, 'Cuenta creada exitosamente');
          // Llamar al login automático (que navegará al dashboard)
          await _loginAutomatico(_emailController.text, _passwordController.text);
          // No cerramos la pantalla aquí, el login automático ya navega
        } else {
          GlobalSnackBars.mostrarError(context, data['respuesta']?['message'] ?? 'Error al crear la cuenta');
        }
      } else {
        GlobalSnackBars.mostrarError(context, 'Error ${response.statusCode}: Error del servidor');
      }
    } catch (e) {
      GlobalVariables.debugPrint('❌ Excepción en creación de usuario: $e');
      GlobalSnackBars.mostrarError(context, 'Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPasswordRequirementsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, size: 16, color: GlobalVariables.blueDarkColor),
              const SizedBox(width: 8),
              Text(
                'Requisitos de seguridad',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GlobalVariables.blueDarkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRequirementItem('Mínimo 8 caracteres'),
          _buildRequirementItem('Al menos una letra mayúscula'),
          _buildRequirementItem('Al menos un número (0-9)'),
          _buildRequirementItem('Al menos un símbolo (! @ # \$ % ^ & *)'),
          const SizedBox(height: 8),
          Text(
            'Ejemplo seguro: "Passw0rd\$2026"',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    if (_passwordController.text.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Requisitos cumplidos:',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildRequirementChip('8+ caracteres', _passwordTieneLongitud),
            _buildRequirementChip('MAYÚSCULA', _passwordTieneMayuscula),
            _buildRequirementChip('NÚMERO', _passwordTieneNumero),
            _buildRequirementChip('SÍMBOLO', _passwordTieneSimbolo),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirementChip(String label, bool cumple) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cumple ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cumple ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: cumple ? Colors.green.shade800 : Colors.grey.shade600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Column(
        children: [
          TextFormField(
            controller: _aliasController,
            decoration: GlobalInputStyles.inputDecoration(
              labelText: 'Alias',
              hintText: 'Cómo quieres que te llamemos',
              prefixIcon: Icons.person_outline,
            ).copyWith(errorText: _aliasErrorText),
          ),
          const SizedBox(height: 15),

          TextFormField(
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            onChanged: _handlePhoneInput,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: GlobalInputStyles.inputDecoration(
              labelText: 'Teléfono',
              hintText: '56912345678',
              prefixIcon: Icons.phone_outlined,
            ).copyWith(
              errorText: _telefonoErrorText,
              prefix: const Text('+ '),
            ),
          ),
          const SizedBox(height: 15),

          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            decoration: GlobalInputStyles.inputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'ejemplo@correo.com',
              prefixIcon: Icons.email_outlined,
            ).copyWith(errorText: _emailErrorText),
          ),
          const SizedBox(height: 15),

          TextFormField(
            controller: _passwordController,
            obscureText: !_mostrarPassword,
            decoration: GlobalInputStyles.inputDecoration(
              labelText: 'Contraseña',
              hintText: 'Crea una contraseña segura',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _mostrarPassword ? Icons.visibility_off : Icons.visibility,
                  color: GlobalVariables.blueDarkColor,
                ),
                onPressed: () => setState(() => _mostrarPassword = !_mostrarPassword),
              ),
            ).copyWith(errorText: _passwordErrorText),
          ),
          _buildPasswordStrengthIndicator(),
          const SizedBox(height: 15),

          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_mostrarConfirmPassword,
            decoration: GlobalInputStyles.inputDecoration(
              labelText: 'Repetir contraseña',
              hintText: 'Confirma tu contraseña',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _mostrarConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  color: GlobalVariables.blueDarkColor,
                ),
                onPressed: () => setState(() => _mostrarConfirmPassword = !_mostrarConfirmPassword),
              ),
            ).copyWith(errorText: _confirmPasswordErrorText),
          ),
          const SizedBox(height: 25),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _crearUsuario,
              style: ElevatedButton.styleFrom(
                backgroundColor: GlobalVariables.blueDarkColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Text(
                'Crear cuenta',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 25),

          _buildPasswordRequirementsCard(),

          SizedBox(height: MediaQuery.of(context).size.height * 0.05),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// RECUPERAR CONTRASEÑA (con indicador local)
// ---------------------------------------------------------------------
class RecuperarContrasenaScreen extends StatefulWidget {
  const RecuperarContrasenaScreen({super.key});

  @override
  State<RecuperarContrasenaScreen> createState() => _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState extends State<RecuperarContrasenaScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _nuevaPasswordController = TextEditingController();
  final TextEditingController _confirmarPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _codigoEnviado = false;
  bool _mostrarPassword = false;
  bool _mostrarConfirmPassword = false;
  DateTime? _horaEnvioCodigo;
  int _intentosFallidos = 0;
  Timer? _timer;

  String? _emailErrorText;
  String? _codigoErrorText;
  String? _passwordErrorText;
  String? _confirmPasswordErrorText;

  bool _passwordTieneLongitud = false;
  bool _passwordTieneMayuscula = false;
  bool _passwordTieneNumero = false;
  bool _passwordTieneSimbolo = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validarEmail);
    _codigoController.addListener(_validarCodigo);
    _nuevaPasswordController.addListener(_validarPassword);
    _confirmarPasswordController.addListener(_validarConfirmPassword);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.removeListener(_validarEmail);
    _codigoController.removeListener(_validarCodigo);
    _nuevaPasswordController.removeListener(_validarPassword);
    _confirmarPasswordController.removeListener(_validarConfirmPassword);
    _emailController.dispose();
    _codigoController.dispose();
    _nuevaPasswordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
  }

  void _validarEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _emailErrorText = 'Ingresa tu correo electrónico');
    } else {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
      setState(() {
        _emailErrorText = emailRegex.hasMatch(email) ? null : 'Formato de email inválido';
      });
    }
  }

  void _validarCodigo() {
    final codigo = _codigoController.text.trim();
    setState(() {
      if (codigo.isEmpty) {
        _codigoErrorText = 'Ingresa el código';
      } else if (codigo.length != 8) {
        _codigoErrorText = 'El código debe tener 8 caracteres';
      } else {
        _codigoErrorText = null;
      }
    });
  }

  void _validarPassword() {
    final pass = _nuevaPasswordController.text;
    setState(() {
      _passwordTieneLongitud = pass.length >= 8;
      _passwordTieneMayuscula = RegExp(r'[A-Z]').hasMatch(pass);
      _passwordTieneNumero = RegExp(r'[0-9]').hasMatch(pass);
      _passwordTieneSimbolo = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(pass);

      if (pass.isEmpty) {
        _passwordErrorText = 'Ingresa una nueva contraseña';
      } else if (!(_passwordTieneLongitud && _passwordTieneMayuscula && _passwordTieneNumero && _passwordTieneSimbolo)) {
        _passwordErrorText = 'La contraseña no cumple los requisitos de seguridad';
      } else {
        _passwordErrorText = null;
      }
    });
    _validarConfirmPassword();
  }

  void _validarConfirmPassword() {
    final pass = _nuevaPasswordController.text;
    final confirm = _confirmarPasswordController.text;
    setState(() {
      if (confirm.isEmpty) {
        _confirmPasswordErrorText = 'Confirma la nueva contraseña';
      } else if (pass != confirm) {
        _confirmPasswordErrorText = 'Las contraseñas no coinciden';
      } else {
        _confirmPasswordErrorText = null;
      }
    });
  }

  bool get _botonEnviarCodigoHabilitado {
    return _emailErrorText == null && _emailController.text.isNotEmpty && !_isLoading;
  }

  bool get _botonCambiarPasswordHabilitado {
    return _codigoErrorText == null &&
        _passwordErrorText == null &&
        _confirmPasswordErrorText == null &&
        _emailErrorText == null &&
        !_isLoading;
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _horaEnvioCodigo == null) return;
      final restantes = _getSegundosRestantes();
      if (restantes <= 0) {
        timer.cancel();
        if (mounted) {
          setState(() {
            _codigoEnviado = false;
            _intentosFallidos = 0;
          });
        }
      } else {
        setState(() {});
      }
    });
  }

  int _getSegundosRestantes() {
    if (_horaEnvioCodigo == null) return 0;
    final ahora = DateTime.now();
    final diferencia = ahora.difference(_horaEnvioCodigo!);
    final restantes = (10 * 60) - diferencia.inSeconds;
    return restantes.clamp(0, 10 * 60);
  }

  String _getTiempoRestante() {
    final segundos = _getSegundosRestantes();
    final minutos = segundos ~/ 60;
    final segs = segundos % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segs.toString().padLeft(2, '0')}';
  }

  Future<void> _enviarCodigo() async {
    _validarEmail();
    if (_emailErrorText != null) {
      GlobalSnackBars.mostrarError(context, 'Corrige el email antes de continuar');
      return;
    }

    setState(() => _isLoading = true);

    try {
      GlobalVariables.debugPrint('🔍 Enviando solicitud de código a ${_emailController.text}');
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CorreoCodigoCambioPassword/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({"mail": _emailController.text.trim()}),
      ).timeout(const Duration(seconds: 15));

      setState(() => _isLoading = false);
      GlobalVariables.debugPrint('📥 Respuesta código - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _codigoEnviado = true;
            _horaEnvioCodigo = DateTime.now();
            _intentosFallidos = 0;
          });
          _iniciarTimer();
          GlobalSnackBars.mostrarExito(
            context,
            'Si el correo está registrado, recibirás un código',
          );
        } else {
          setState(() {
            _codigoEnviado = true;
            _horaEnvioCodigo = DateTime.now();
          });
          _iniciarTimer();
          GlobalSnackBars.mostrarInfo(
            context,
            'Si el correo está registrado, recibirás un código',
          );
        }
      } else {
        setState(() {
          _codigoEnviado = true;
          _horaEnvioCodigo = DateTime.now();
        });
        _iniciarTimer();
        GlobalSnackBars.mostrarInfo(
          context,
          'Si el correo está registrado, recibirás un código',
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      GlobalVariables.debugPrint('❌ Error enviando código: $e');
      setState(() {
        _codigoEnviado = true;
        _horaEnvioCodigo = DateTime.now();
      });
      _iniciarTimer();
      GlobalSnackBars.mostrarInfo(
        context,
        'Si el correo está registrado, recibirás un código',
      );
    }
  }

  Future<void> _confirmarCambioPassword() async {
    _validarEmail();
    _validarCodigo();
    _validarPassword();
    _validarConfirmPassword();

    if (_emailErrorText != null ||
        _codigoErrorText != null ||
        _passwordErrorText != null ||
        _confirmPasswordErrorText != null) {
      GlobalSnackBars.mostrarError(context, 'Corrige los errores antes de continuar');
      return;
    }

    if (_horaEnvioCodigo != null && _getSegundosRestantes() <= 0) {
      GlobalSnackBars.mostrarError(context, 'El código ha expirado. Solicita uno nuevo.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      GlobalVariables.debugPrint('🔍 Confirmando cambio de contraseña...');
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/ConfirmarCambioPassword/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "codigo_verificador": _codigoController.text.trim(),
          "mail": _emailController.text.trim(),
          "nuevo_pass": _nuevaPasswordController.text,
        }),
      ).timeout(const Duration(seconds: 15));

      setState(() => _isLoading = false);
      GlobalVariables.debugPrint('📥 Respuesta cambio - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          GlobalSnackBars.mostrarExito(context, 'Contraseña cambiada exitosamente');
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pop(context);
        } else {
          final mensaje = data['message'] ?? 'Error al cambiar contraseña';
          final codigoError = data['codigo_error'];
          if (codigoError == 'CODIGO_INCORRECTO') {
            setState(() => _intentosFallidos++);
            GlobalSnackBars.mostrarError(context, 'Código incorrecto');
          } else {
            GlobalSnackBars.mostrarError(context, mensaje);
          }
        }
      } else {
        GlobalSnackBars.mostrarError(context, 'Error del servidor');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      GlobalVariables.debugPrint('❌ Error confirmando cambio: $e');
      GlobalSnackBars.mostrarError(context, 'Error de conexión: $e');
    }
  }

  Widget _buildPasswordRequirementsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, size: 16, color: GlobalVariables.blueDarkColor),
              const SizedBox(width: 8),
              Text(
                'Requisitos de seguridad',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: GlobalVariables.blueDarkColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildRequirementItem('Mínimo 8 caracteres'),
          _buildRequirementItem('Al menos una letra mayúscula'),
          _buildRequirementItem('Al menos un número (0-9)'),
          _buildRequirementItem('Al menos un símbolo (! @ # \$ % ^ & *)'),
          const SizedBox(height: 8),
          Text(
            'Ejemplo seguro: "Passw0rd\$2026"',
            style: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    if (_nuevaPasswordController.text.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Requisitos cumplidos:',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildRequirementChip('8+ caracteres', _passwordTieneLongitud),
            _buildRequirementChip('MAYÚSCULA', _passwordTieneMayuscula),
            _buildRequirementChip('NÚMERO', _passwordTieneNumero),
            _buildRequirementChip('SÍMBOLO', _passwordTieneSimbolo),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirementChip(String label, bool cumple) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cumple ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: cumple ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: cumple ? Colors.green.shade800 : Colors.grey.shade600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final segundosRestantes = _getSegundosRestantes();
    final codigoExpirado = segundosRestantes <= 0 && _horaEnvioCodigo != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: GlobalVariables.blueDarkColor),
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Olvidaste la contraseña',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: GlobalVariables.blueDarkColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
              decoration: GlobalInputStyles.inputDecoration(
                labelText: 'Correo electrónico',
                hintText: 'ejemplo@correo.com',
                prefixIcon: Icons.email_outlined,
              ).copyWith(errorText: _emailErrorText),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _botonEnviarCodigoHabilitado ? _enviarCodigo : null,
                icon: const Icon(Icons.send, size: 20, color: Colors.white),
                label: const Text(
                  'Solicitar código de verificación',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _botonEnviarCodigoHabilitado
                      ? GlobalVariables.blueDarkColor
                      : Colors.grey.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_codigoEnviado && !codigoExpirado) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: GlobalVariables.blueDarkColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GlobalVariables.blueDarkColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitud procesada para:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: GlobalVariables.blueDarkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_emailController.text, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 18,
                              color: segundosRestantes < 60 ? Colors.red.shade700 : GlobalVariables.blueDarkColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getTiempoRestante(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: segundosRestantes < 60 ? Colors.red.shade700 : GlobalVariables.blueDarkColor,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _isLoading ? null : _enviarCodigo,
                          icon: Icon(Icons.refresh, size: 16, color: GlobalVariables.blueDarkColor),
                          label: Text(
                            'Reenviar código',
                            style: TextStyle(fontSize: 14, color: GlobalVariables.blueDarkColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            if (codigoExpirado) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El código ha expirado. Solicita uno nuevo.',
                        style: TextStyle(fontSize: 14, color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_intentosFallidos > 0 && _codigoEnviado) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Intentos fallidos: $_intentosFallidos/3',
                        style: TextStyle(fontSize: 14, color: Colors.red.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            TextFormField(
              controller: _codigoController,
              maxLength: 8,
              keyboardType: TextInputType.text,
              decoration: GlobalInputStyles.inputDecoration(
                labelText: 'Código de verificación',
                hintText: 'Ingresa el código',
                prefixIcon: Icons.code,
              ).copyWith(
                errorText: _codigoErrorText,
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _nuevaPasswordController,
              obscureText: !_mostrarPassword,
              decoration: GlobalInputStyles.inputDecoration(
                labelText: 'Nueva contraseña',
                hintText: 'Ingresa nueva contraseña',
                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarPassword ? Icons.visibility_off : Icons.visibility,
                    color: GlobalVariables.blueDarkColor,
                  ),
                  onPressed: () => setState(() => _mostrarPassword = !_mostrarPassword),
                ),
              ).copyWith(errorText: _passwordErrorText),
            ),
            _buildPasswordStrengthIndicator(),
            const SizedBox(height: 16),

            TextFormField(
              controller: _confirmarPasswordController,
              obscureText: !_mostrarConfirmPassword,
              decoration: GlobalInputStyles.inputDecoration(
                labelText: 'Confirmar contraseña',
                hintText: 'Confirma la nueva contraseña',
                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: GlobalVariables.blueDarkColor,
                  ),
                  onPressed: () => setState(() => _mostrarConfirmPassword = !_mostrarConfirmPassword),
                ),
              ).copyWith(errorText: _confirmPasswordErrorText),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _botonCambiarPasswordHabilitado ? _confirmarCambioPassword : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _botonCambiarPasswordHabilitado
                      ? GlobalVariables.blueDarkColor
                      : Colors.grey.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Text(
                  'Cambiar Contraseña',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 24),

            _buildPasswordRequirementsCard(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ================== WIDGET PARA CAPTURAR ERRORES EN DASHBOARD ==================
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  String _errorMessage = '';
  StackTrace? _stackTrace;

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error al cargar el dashboard',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    navigatorKey.currentState?.pushNamedAndRemoveUntil('/', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlobalVariables.blueDarkColor,
                  ),
                  child: const Text('Reiniciar aplicación'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Builder(
      builder: (context) {
        try {
          return widget.child;
        } catch (e, stack) {
          GlobalVariables.debugPrint('❌ Error capturado en DashboardScreen: $e');
          GlobalVariables.debugPrint('Stack trace: $stack');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = e.toString();
                _stackTrace = stack;
              });
            }
          });
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
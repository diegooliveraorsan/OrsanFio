import 'package:flutter/material.dart';
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

// ✅ CONFIGURAR navigatorKey GLOBAL A NIVEL DE MAIN
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✅ COLOR AZUL OSCURO DEFINIDO GLOBALMENTE
final Color _blueDarkColor = const Color(0xFF0055B8);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ CONFIGURAR EL NAVIGATOR KEY EN EL HANDLER ANTES DE INICIALIZAR
  NotificationHandler.navigatorKey = navigatorKey;

  // ✅ INICIALIZAR NOTIFICACIONES DESPUÉS DE FIREBASE
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
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      navigatorKey: navigatorKey, // ✅ CLAVE GLOBAL AQUÍ
      home: const UpdateCheckScreen(), // Cambiado a UpdateCheckScreen
      debugShowCheckedModeBanner: false,
    );
  }
}

// ✅ NUEVA PANTALLA PARA VERIFICAR ACTUALIZACIÓN
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
      print('🔍 Verificando actualizaciones de la app...');

      // ✅ OBTENER VERSIÓN DESDE variables_globales.dart
      String currentVersion = GlobalVariables.appVersion;
      String platform = Platform.isAndroid ? "android" : "ios";

      print('📱 Información del dispositivo:');
      print('   - Versión actual: $currentVersion');
      print('   - Plataforma: $platform');
      print('   - URL API: ${GlobalVariables.baseUrl}/ActualizacionDisponible/api/v1/');

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

      print('📥 Response ActualizacionDisponible:');
      print('   - Status: ${response.statusCode}');
      print('   - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          bool updateAvailable = responseData['actualizacion'] == true;

          print('🎯 Resultado verificación:');
          print('   - Actualización disponible: $updateAvailable');
          print('   - Versión actual: ${responseData['version_actual']}');
          print('   - Versión nueva: ${responseData['version_nueva']}');
          print('   - URL actualización: ${responseData['url_actualizacion']}');

          if (updateAvailable) {
            setState(() {
              _updateAvailable = true;
              _updateData = responseData;
              _isChecking = false;
            });
          } else {
            // No hay actualización, continuar con el flujo normal
            setState(() {
              _isChecking = false;
              _updateAvailable = false;
            });

            // Navegar al SplashScreen
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SplashScreen()),
              );
            });
          }
        } else {
          // Error en la API, continuar con flujo normal
          print('⚠️ Error en API de actualización: ${responseData['mensaje']}');
          _continueWithNormalFlow();
        }
      } else {
        // Error HTTP, continuar con flujo normal
        print('❌ Error HTTP en verificación de actualización: ${response.statusCode}');
        _continueWithNormalFlow();
      }
    } catch (e) {
      // Error de conexión, continuar con flujo normal
      print('❌ Error verificando actualización: $e');
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
      print('🚀 Intentando abrir URL: $url');

      try {
        if (await canLaunch(url)) {
          await launch(url);
        } else {
          _showErrorDialog('No se puede abrir la URL de actualización');
        }
      } catch (e) {
        print('❌ Error al abrir URL: $e');
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
    // El usuario decidió saltar la actualización
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
            : const SizedBox(), // No debería llegar aquí
      ),
    );
  }

  Widget _buildCheckingUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircularProgressIndicator(),
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
          // Icono de actualización
          Icon(
            Icons.system_update,
            size: 80,
            color: _blueDarkColor, // ✅ COLOR AZUL OSCURO
          ),

          const SizedBox(height: 24),

          // Título
          Text(
            'Actualización disponible',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _blueDarkColor, // ✅ COLOR AZUL OSCURO
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Versión actual (desde GlobalVariables)
          Text(
            'Versión actual: ${GlobalVariables.appVersion}',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 8),

          // ✅ NUEVA VERSIÓN EN AZUL OSCURO
          if (_updateData != null && _updateData!['version_nueva'] != null)
            Text(
              'Nueva versión: ${_updateData!['version_nueva']}',
              style: TextStyle(
                fontSize: 16,
                color: _blueDarkColor, // ✅ COLOR AZUL OSCURO
                fontWeight: FontWeight.bold,
              ),
            ),

          const SizedBox(height: 24),

          // Mensaje
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

          // ✅ BOTÓN DE ACTUALIZAR CON EL NUEVO ESTILO
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _launchUpdateURL,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blueDarkColor, // ✅ COLOR AZUL OSCURO
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

          const SizedBox(height: 16),

          // Botón para saltar (solo en desarrollo/testing)
          if (_updateData != null &&
              (_updateData!['version_nueva'] as String).contains('dev') ||
              (_updateData!['version_nueva'] as String).contains('test'))
            TextButton(
              onPressed: _skipUpdate,
              child: Text(
                'Continuar sin actualizar',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
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

    // ✅ VERIFICAR SI HAY SESIÓN INICIADA DESPUÉS DE LA ANIMACIÓN
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _checkExistingSession();
        });
      }
    });
  }

  // ✅ NUEVO MÉTODO PARA VERIFICAR SESIÓN EXISTENTE
  Future<void> _checkExistingSession() async {
    try {
      print('🔍 Verificando si hay sesión iniciada...');

      // Obtener token FCM
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      final String deviceToken = fcmToken ??
          'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';

      print('📱 Token del dispositivo: $deviceToken');
      print('🌐 Llamando a API SesionIniciada...');

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

      print('📥 Response SesionIniciada - Status: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final bool sesionIniciada = responseData['sesion_iniciada'] == true;

        print('🎯 Sesión iniciada: $sesionIniciada');

        if (sesionIniciada) {
          // ✅ SESIÓN ACTIVA - IR DIRECTAMENTE AL DASHBOARD
          print('🚀 Sesión activa detectada, navegando al dashboard...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DashboardScreen(userData: responseData),
            ),
          );
        } else {
          // ❌ NO HAY SESIÓN - MOSTRAR ONBOARDING
          print('🔐 No hay sesión activa, mostrando onboarding...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OnboardingScreen()),
          );
        }
      } else {
        // ⚠️ ERROR EN LA API - MOSTRAR ONBOARDING
        print('⚠️ Error en API SesionIniciada, mostrando onboarding...');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    } catch (e) {
      // ⚠️ ERROR DE CONEXIÓN - MOSTRAR ONBOARDING
      print('❌ Error verificando sesión: $e');
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
          child: Image.asset(
            'assets/images/logo_fio.png',
            height: 150,
            width: 150,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final List<Map<String, String>> onboardingData = [
    {
      'subtitle': 'Línea de Crédito',
      'description': 'Accede a crédito preaprobado al instante',
    },
    {
      'subtitle': 'Pagos Instantáneos',
      'description': 'Procesa tus transacciones en segundos',
    },
    {
      'subtitle': 'Seguridad Biométrica',
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
            // Título "Bienvenido"
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

            // Espacio para centrar el contenido
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! > 0 && _currentPage > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else if (details.primaryVelocity! < 0 &&
                      _currentPage < onboardingData.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: onboardingData.length,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  itemBuilder: (context, index) {
                    return _buildOnboardingPage(onboardingData[index]);
                  },
                ),
              ),
            ),

            // Indicadores de página
            Container(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  onboardingData.length,
                      (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? _blueDarkColor // ✅ COLOR AZUL OSCURO
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ),

            // Botón Continuar
            if (_currentPage == onboardingData.length - 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      _navigateToAuthScreen(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blueDarkColor, // ✅ COLOR AZUL OSCURO
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
              )
            else
              const SizedBox(height: 90), // Espacio reservado cuando no hay botón
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingPage(Map<String, String> data) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data['subtitle']!,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: _blueDarkColor, // ✅ COLOR AZUL OSCURO
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              data['description']!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            const Divider(
              color: Colors.grey,
              thickness: 1,
            ),
          ],
        ),
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
                // Header con logo como imagen (SIN TEXTO)
                Center(
                  child: Image.asset(
                    'assets/images/logo_fio.png',
                    height: 100,
                    width: 100,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 30),

                // Título principal
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

                // Selector de pestañas usando ToggleButtons para mejor control
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
                      color: _blueDarkColor, // ✅ COLOR AZUL OSCURO
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

                // Contenido de las pestañas
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Pestaña INGRESAR - Usando tu código original de login
                      const LoginContent(),

                      // Pestaña CREAR CUENTA
                      _RegisterFormContent(),
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

// ✅ COMPONENTE DE LOGIN ORIGINAL MODIFICADO
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

  String _getPlatform() {
    if (Platform.isAndroid) {
      return "android";
    } else if (Platform.isIOS) {
      return "ios";
    } else if (Platform.isWindows) {
      return "windows";
    } else if (Platform.isMacOS) {
      return "macos";
    } else if (Platform.isLinux) {
      return "linux";
    } else {
      return "unknown";
    }
  }

  Future<String> _getFCMToken() async {
    try {
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        print('✅ Token FCM obtenido: $fcmToken');
        return fcmToken;
      } else {
        print('⚠️ No se pudo obtener token FCM, usando fallback');
        return 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      print('❌ Error obteniendo token FCM: $e');
      return 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeFCMToken();
  }

  Future<void> _initializeFCMToken() async {
    try {
      final String fcmToken = await _getFCMToken();
      setState(() {
        _deviceToken = fcmToken;
      });
      print('🎯 Token FCM listo: $fcmToken');
    } catch (e) {
      final String fallbackToken = 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _deviceToken = fallbackToken;
      });
      print('⚠️ Usando token fallback: $fallbackToken');
    }
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Por favor ingresa email y contraseña');
      return;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(_emailController.text)) {
      _showSnackBar('Por favor ingresa un email válido');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // ✅ MOSTRAR ANIMACIÓN DE PROCESAMIENTO
    final Completer<void> loadingCompleter = Completer<void>();
    SimpleLoadingDialog.show(
      context: context,
      completer: loadingCompleter,
      message: 'Iniciando sesión...',
    );

    try {
      final String platform = _getPlatform();

      print('🔍 REQUEST COMPLETO:');
      print('URL: https://apiorsanpay.orsanevaluaciones.cl/IniciarSesion/api/v1/');
      print('Body: ${json.encode({
        "mail": _emailController.text,
        "password": _passwordController.text,
        "token_dispositivo": _deviceToken,
        "tipo_dispositivo": platform,
      })}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/IniciarSesion/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "mail": _emailController.text,
          "password": _passwordController.text,
          "token_dispositivo": _deviceToken,
          "tipo_dispositivo": platform,
        }),
      );

      // ✅ CERRAR ANIMACIÓN
      loadingCompleter.complete();

      setState(() {
        _isLoading = false;
      });

      print('📥 RESPONSE:');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // ✅ MODIFICACIÓN: SOLO NAVEGAR SI NO HAY ERROR
        if (responseData['error'] == null) {
          _showSnackBar('Login exitoso');
          _navigateToDashboard(responseData);
        } else {
          // ✅ MOSTRAR ERROR ESPECÍFICO DE LA API
          _showSnackBar('Error: ${responseData['error']}');
        }
      } else {
        print('❌ ERROR DETALLADO:');
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');

        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            _showSnackBar('Error: ${errorData['error'] ?? errorData['message'] ?? 'Error del servidor'}');
          } catch (e) {
            _showSnackBar('Error ${response.statusCode}: ${response.body}');
          }
        } else {
          _showSnackBar('Error ${response.statusCode}: Servidor no respondió');
        }
      }
    } catch (e) {
      // ✅ CERRAR ANIMACIÓN EN CASO DE ERROR
      loadingCompleter.complete();

      setState(() {
        _isLoading = false;
      });
      print('❌ ERROR DE CONEXIÓN: $e');
      _showSnackBar('Error de conexión: $e');
    }
  }

  void _navigateToDashboard(Map<String, dynamic> responseData) {
    print('🚀 Navegando al dashboard...');

    // ✅ CORREGIR: El response del login NO tiene 'dispositivo_actual'
    // pero SÍ tiene 'dispositivos' array. Tomamos el primer dispositivo.
    Map<String, dynamic> dispositivoActual = {};
    if (responseData['dispositivos'] != null &&
        responseData['dispositivos'].isNotEmpty) {
      dispositivoActual = responseData['dispositivos'][0];
      print('📱 Dispositivo actual obtenido de dispositivos[0]: $dispositivoActual');
    }

    // ✅ CREAR LA ESTRUCTURA COMPLETA QUE ESPERA DASHBOARD
    final Map<String, dynamic> dashboardData = {
      ...responseData,
      'sesion_iniciada': true,
      'dispositivo_actual': dispositivoActual, // ✅ AGREGAR ESTO
    };

    print('🎯 Datos finales para dashboard:');
    print('- comprador: ${dashboardData['comprador'] != null}');
    print('- dispositivo_actual: ${dashboardData['dispositivo_actual'] != null}');
    print('- sesion_iniciada: ${dashboardData['sesion_iniciada']}');

    // ✅ NAVEGACIÓN INMEDIATA
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            userData: dashboardData,
          ),
        ),
      );
    });

    print('✅ Navegación iniciada');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ✅ NUEVO MÉTODO: NAVEGAR A LA VISTA DE RECUPERAR CONTRASEÑA
  void _navigateToRecuperarContrasena() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RecuperarContrasenaScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.email, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Correo electrónico',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock, color: Colors.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Contraseña',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 15),

          // ✅ TEXTO PARA RECUPERAR CONTRASEÑA - AGREGADO AQUÍ
          GestureDetector(
            onTap: _navigateToRecuperarContrasena,
            child: Container(
              alignment: Alignment.centerRight,
              child: Text(
                '¿Olvidaste tu contraseña?',
                style: TextStyle(
                  fontSize: 14,
                  color: _blueDarkColor, // ✅ Mismo color azul oscuro
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blueDarkColor, // ✅ COLOR AZUL OSCURO
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
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

// ✅ COMPONENTE DE REGISTRO CON ANIMACIÓN Y VALIDACIÓN DE TELÉFONO MEJORADA
class _RegisterFormContent extends StatefulWidget {
  const _RegisterFormContent({super.key});

  @override
  State<_RegisterFormContent> createState() => __RegisterFormContentState();
}

class __RegisterFormContentState extends State<_RegisterFormContent> {
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
  TextEditingController();
  bool _isLoading = false;
  String _deviceToken = 'generando...';

  // ✅ NUEVA VARIABLE PARA CONTROLAR EL ERROR DEL TELÉFONO
  bool _telefonoError = false;
  String _telefonoErrorMessage = '';

  // ✅ NUEVA VARIABLE PARA CONTROLAR EL FOCO DEL TELÉFONO
  bool _telefonoHasFocus = false;

  // ✅ CONTROLADOR PARA MANEJAR EL SCROLL
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeFCMToken();

    // ✅ INICIALIZAR EL TELÉFONO VACÍO
    _telefonoController.text = "";

    // ✅ AGREGAR LISTENER PARA VALIDAR EN TIEMPO REAL
    _telefonoController.addListener(_validarTelefonoEnTiempoReal);
  }

  @override
  void dispose() {
    _telefonoController.removeListener(_validarTelefonoEnTiempoReal);
    _scrollController.dispose();
    _aliasController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Función para mostrar snackbar
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Obtener token FCM (igual que en login)
  Future<String> _getFCMToken() async {
    try {
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      return fcmToken ?? 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _initializeFCMToken() async {
    try {
      final String fcmToken = await _getFCMToken();
      setState(() {
        _deviceToken = fcmToken;
      });
    } catch (e) {
      final String fallbackToken = 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _deviceToken = fallbackToken;
      });
    }
  }

  // Detectar plataforma
  String _getPlatform() {
    if (Platform.isAndroid) return "android";
    if (Platform.isIOS) return "ios";
    if (Platform.isWindows) return "windows";
    if (Platform.isMacOS) return "macos";
    if (Platform.isLinux) return "linux";
    return "unknown";
  }

  // ✅ MÉTODO PARA VALIDAR TELÉFONO EN TIEMPO REAL
  void _validarTelefonoEnTiempoReal() {
    final String digitos = _telefonoController.text;
    final int longitudDigitos = digitos.length;

    if (longitudDigitos < 11 && longitudDigitos > 0) {
      setState(() {
        _telefonoError = true;
        _telefonoErrorMessage = 'El teléfono debe tener al menos 11 dígitos';
      });
    } else {
      setState(() {
        _telefonoError = false;
        _telefonoErrorMessage = '';
      });
    }
  }

  // ✅ MÉTODO PARA MANEJAR EL TELÉFONO CON "+" FIJO
  void _handlePhoneInput(String value) {
    // Solo permitir dígitos
    final String numbersOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    // Actualizar el controlador con solo números
    if (numbersOnly != value) {
      _telefonoController.text = numbersOnly;
      _telefonoController.selection = TextSelection.fromPosition(
        TextPosition(offset: _telefonoController.text.length),
      );
    }

    // Validar en tiempo real
    _validarTelefonoEnTiempoReal();
  }

  // ✅ MÉTODO PARA DESPLAZARSE AL CAMPO ACTIVO
  void _scrollToField(FocusNode focusNode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pequeño delay para asegurar que el teclado ya esté visible
      Future.delayed(const Duration(milliseconds: 300), () {
        final RenderObject? renderObject = focusNode.context?.findRenderObject();
        if (renderObject != null) {
          _scrollController.animateTo(
            _scrollController.offset + 100, // Ajusta este valor según necesites
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    });
  }

  // ✅ MÉTODO PARA LOGIN AUTOMÁTICO DESPUÉS DE CREAR CUENTA
  Future<void> _loginAutomatico(String email, String password) async {
    try {
      final String platform = _getPlatform();
      final String fcmToken = await _getFCMToken();

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
          "token_dispositivo": fcmToken,
          "tipo_dispositivo": platform,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // ✅ CORREGIR NAVEGACIÓN PARA CREAR CUENTA TAMBIÉN
        Map<String, dynamic> dispositivoActual = {};
        if (responseData['dispositivos'] != null &&
            responseData['dispositivos'].isNotEmpty) {
          dispositivoActual = responseData['dispositivos'][0];
        }

        final Map<String, dynamic> dashboardData = {
          ...responseData,
          'sesion_iniciada': true,
          'dispositivo_actual': dispositivoActual,
        };

        // ✅ NAVEGAR AL DASHBOARD SI EL LOGIN ES EXITOSO
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(userData: dashboardData),
          ),
        );
      } else {
        _showSnackBar('Cuenta creada pero error en login automático');
      }
    } catch (e) {
      _showSnackBar('Cuenta creada pero error en login automático: $e');
    }
  }

  // Método para crear usuario
  Future<void> _crearUsuario() async {
    // Validar campos vacíos
    if (_aliasController.text.isEmpty ||
        _telefonoController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showSnackBar('Por favor completa todos los campos');
      return;
    }

    // ✅ VALIDAR TELÉFONO ANTES DE ENVIAR
    if (_telefonoError) {
      _showSnackBar(_telefonoErrorMessage);
      return;
    }

    // Validar que las contraseñas coincidan
    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Las contraseñas no coinciden');
      return;
    }

    // Validar formato de email
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(_emailController.text)) {
      _showSnackBar('Por favor ingresa un email válido');
      return;
    }

    // ✅ VALIDAR TELÉFONO (mínimo 11 dígitos después del +)
    final String digitosTelefono = _telefonoController.text.substring(1);
    if (digitosTelefono.length < 10) {
      _showSnackBar('Por favor ingresa un teléfono válido (11 dígitos después del +)');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // ✅ MOSTRAR ANIMACIÓN DE PROCESAMIENTO
    final Completer<void> loadingCompleter = Completer<void>();
    SimpleLoadingDialog.show(
      context: context,
      completer: loadingCompleter,
      message: 'Creando cuenta...',
    );

    try {
      final String platform = _getPlatform();
      final String fcmToken = await _getFCMToken();

      print('🔍 REQUEST CREAR USUARIO:');
      print('URL: https://apiorsanpay.orsanevaluaciones.cl/CrearUsuario/api/v1/');
      print('Body: ${json.encode({
        "alias_comprador": _aliasController.text,
        "telefono_comprador": "+" + _telefonoController.text,
        "mail": _emailController.text,
        "pswrd_nuevo_usuario": _passwordController.text,
        "token_dispositivo": fcmToken,
        "tipo_dispositivo": platform,
      })}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CrearUsuario/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "alias_comprador": _aliasController.text,
          "telefono_comprador": _telefonoController.text,
          "mail": _emailController.text,
          "pswrd_nuevo_usuario": _passwordController.text,
          "token_dispositivo": fcmToken,
          "tipo_dispositivo": platform,
        }),
      );

      // ✅ CERRAR ANIMACIÓN
      loadingCompleter.complete();

      setState(() {
        _isLoading = false;
      });

      print('📥 RESPONSE CREAR USUARIO:');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Verificar si la creación fue exitosa
        if (responseData['respuesta'] != null && responseData['respuesta']['success'] == true) {
          _showSnackBar('Cuenta creada exitosamente');

          // ✅ AUTOMÁTICAMENTE LLAMAR AL LOGIN
          _loginAutomatico(_emailController.text, _passwordController.text);
        } else {
          // Mostrar error específico de la API
          final String errorMessage = responseData['respuesta']?['message'] ?? 'Error al crear la cuenta';
          _showSnackBar('Error: $errorMessage');
        }
      } else {
        _showSnackBar('Error ${response.statusCode}: Error del servidor');
      }
    } catch (e) {
      // ✅ CERRAR ANIMACIÓN EN CASO DE ERROR
      loadingCompleter.complete();

      setState(() {
        _isLoading = false;
      });
      print('❌ ERROR DE CONEXIÓN: $e');
      _showSnackBar('Error de conexión: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ CREAR FOCUS NODES PARA CADA CAMPO
    final aliasFocusNode = FocusNode();
    final telefonoFocusNode = FocusNode();
    final emailFocusNode = FocusNode();
    final passwordFocusNode = FocusNode();
    final confirmPasswordFocusNode = FocusNode();

    // ✅ AGREGAR LISTENERS PARA EL SCROLL AUTOMÁTICO
    aliasFocusNode.addListener(() {
      if (aliasFocusNode.hasFocus) _scrollToField(aliasFocusNode);
    });

    telefonoFocusNode.addListener(() {
      if (telefonoFocusNode.hasFocus) {
        setState(() {
          _telefonoHasFocus = true;
        });
        _scrollToField(telefonoFocusNode);

        // Si el campo está vacío, agregar el +
        if (_telefonoController.text.isEmpty) {
          _telefonoController.text = '+';
          _telefonoController.selection = TextSelection.fromPosition(
            TextPosition(offset: 1),
          );
        }
      } else {
        setState(() {
          _telefonoHasFocus = false;
        });
      }
    });

    emailFocusNode.addListener(() {
      if (emailFocusNode.hasFocus) _scrollToField(emailFocusNode);
    });
    passwordFocusNode.addListener(() {
      if (passwordFocusNode.hasFocus) _scrollToField(passwordFocusNode);
    });
    confirmPasswordFocusNode.addListener(() {
      if (confirmPasswordFocusNode.hasFocus) _scrollToField(confirmPasswordFocusNode);
    });

    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          // Campo Alias (SIN CAMBIOS - mantener como estaba)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _aliasController,
              focusNode: aliasFocusNode,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Alias',
              ),
            ),
          ),

          const SizedBox(height: 15),

          // ✅ CAMPO TELÉFONO CON + FIJO - AJUSTADO PARA MISMA ALTURA
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: _telefonoError ? Colors.red : Colors.grey.shade300,
                width: _telefonoError ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.phone, color: _telefonoError ? Colors.red : Colors.grey),
                const SizedBox(width: 10),

                // ✅ SOLUCIÓN CORREGIDA - SIN CAMBIAR EL TAMAÑO
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Texto fijo "+" - ALINEADO CORRECTAMENTE
                      const Padding(
                        padding: EdgeInsets.only(bottom: 1.0), // ✅ AJUSTE PARA CENTRAR VERTICALMENTE
                        child: Text(
                          '+',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),

                      // TextField desplazado - MISMA ALTURA QUE LOS DEMÁS
                      Padding(
                        padding: const EdgeInsets.only(left: 14.0),
                        child: TextField(
                          controller: _telefonoController,
                          keyboardType: TextInputType.phone,
                          onChanged: _handlePhoneInput,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '569 12345678',
                            hintStyle: TextStyle(
                              fontSize: 16,
                            ),
                            contentPadding: EdgeInsets.zero, // ✅ ELIMINAR PADDING INTERNO
                            isDense: false, // ✅ MANTENER false PARA ALTURA NORMAL
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ✅ MOSTRAR MENSAJE DE ERROR
          if (_telefonoError)
            Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 8.0),
              child: Text(
                _telefonoErrorMessage,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
            ),

          const SizedBox(height: 15),

          // Campo Correo electrónico (SIN CAMBIOS)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _emailController,
              focusNode: emailFocusNode,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Correo electrónico',
              ),
            ),
          ),

          const SizedBox(height: 15),

          // Campo Contraseña (SIN CAMBIOS)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _passwordController,
              focusNode: passwordFocusNode,
              obscureText: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Contraseña',
              ),
            ),
          ),

          const SizedBox(height: 15),

          // Campo Repetir contraseña (SIN CAMBIOS)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _confirmPasswordController,
              focusNode: confirmPasswordFocusNode,
              obscureText: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Repetir contraseña',
              ),
            ),
          ),

          const SizedBox(height: 30),

          const Divider(),

          const SizedBox(height: 20),

          // Botón Crear cuenta
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _crearUsuario,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blueDarkColor,
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
                'Crear cuenta',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ✅ NUEVA PANTALLA PARA RECUPERAR CONTRASEÑA SIN TOKEN
class RecuperarContrasenaScreen extends StatefulWidget {
  const RecuperarContrasenaScreen({super.key});

  @override
  State<RecuperarContrasenaScreen> createState() =>
      _RecuperarContrasenaScreenState();
}

class _RecuperarContrasenaScreenState
    extends State<RecuperarContrasenaScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _nuevaPasswordController = TextEditingController();
  final TextEditingController _confirmarPasswordController =
  TextEditingController();

  bool _isLoading = false;
  bool _codigoEnviado = false;
  bool _mostrarContrasena = false;
  bool _mostrarConfirmarContrasena = false;
  DateTime? _horaEnvioCodigo;
  int _intentosFallidos = 0;
  int _intentosRestantes = 3;

  // ✅ TIMER PARA ACTUALIZAR EL CONTADOR
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // ✅ Escuchar cambios en los campos de texto
    _emailController.addListener(_actualizarEstadoBoton);
    _codigoController.addListener(_actualizarEstadoBoton);
    _nuevaPasswordController.addListener(_actualizarEstadoBoton);
    _confirmarPasswordController.addListener(_actualizarEstadoBoton);
  }

  @override
  void dispose() {
    // ✅ CANCELAR TIMER AL SALIR
    _timer?.cancel();
    // ✅ Limpiar listeners
    _emailController.removeListener(_actualizarEstadoBoton);
    _codigoController.removeListener(_actualizarEstadoBoton);
    _nuevaPasswordController.removeListener(_actualizarEstadoBoton);
    _confirmarPasswordController.removeListener(_actualizarEstadoBoton);
    super.dispose();
  }

  // ✅ Función para actualizar el estado del botón basado en los campos
  void _actualizarEstadoBoton() {
    setState(() {});
  }

  // ✅ Verificar si el botón de ENVIAR CÓDIGO debe estar habilitado
  bool get _botonEnviarCodigoHabilitado {
    final email = _emailController.text.trim();
    return email.isNotEmpty &&
        _esEmailValido(email) && // ✅ AGREGAR VALIDACIÓN DE FORMATO
        !_isLoading;
  }

  // ✅ Verificar si el botón de CAMBIAR CONTRASEÑA debe estar habilitado
  bool get _botonCambiarPasswordHabilitado {
    final email = _emailController.text.trim();
    final codigo = _codigoController.text.trim();
    final nuevaPassword = _nuevaPasswordController.text.trim();
    final confirmarPassword = _confirmarPasswordController.text.trim();

    return email.isNotEmpty &&
        codigo.length == 8 &&
        nuevaPassword.isNotEmpty &&
        confirmarPassword.isNotEmpty &&
        nuevaPassword == confirmarPassword &&
        _esEmailValido(email) &&
        !_isLoading;
  }

  // ✅ INICIAR TIMER PARA ACTUALIZAR CONTADOR CADA SEGUNDO
  void _iniciarTimer() {
    _timer?.cancel(); // Cancelar timer anterior si existe

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _horaEnvioCodigo != null) {
        final segundosRestantes = _getSegundosRestantes();

        if (segundosRestantes <= 0) {
          // Código expirado, detener timer y actualizar estado
          timer.cancel();
          if (mounted) {
            setState(() {
              _codigoEnviado = false;
              _intentosFallidos = 0;
              _intentosRestantes = 3;
            });
          }
        } else {
          // Solo actualizar el estado para refrescar el contador
          setState(() {});
        }
      }
    });
  }

  // ✅ ENVIAR CÓDIGO POR EMAIL (MODIFICADO PARA NO MOSTRAR INFORMACIÓN ESPECÍFICA)
  Future<void> _enviarCodigo() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _mostrarError('Por favor ingresa tu correo electrónico');
      return;
    }

    // ✅ VALIDAR FORMATO DE EMAIL ANTES DE ENVIAR
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      _mostrarError('Por favor ingresa un email válido');
      return;
    }

    print('🔄 Enviando código a $email...');

    setState(() {
      _isLoading = true;
    });

    try {
      final requestBody = {
        "mail": email,
      };

      print('📤 Request EnviarCodigoRecuperacion:');
      print('🌐 URL: ${GlobalVariables.baseUrl}/CorreoCodigoCambioPassword/api/v1/');
      print('📋 Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CorreoCodigoCambioPassword/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response CorreoCodigoCambioPassword:');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      // ✅ MODIFICACIÓN: SIEMPRE MOSTRAR EL MISMO MENSAJE INDEPENDIENTE DEL RESULTADO
      // (esto es por seguridad, para no revelar información)
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          // ✅ CÓDIGO ENVIADO EXITOSAMENTE
          setState(() {
            _codigoEnviado = true;
            _horaEnvioCodigo = DateTime.now();
            _intentosFallidos = 0;
            _intentosRestantes = 3;
          });

          // ✅ INICIAR TIMER DESPUÉS DE ENVIAR CÓDIGO
          _iniciarTimer();

          // ✅ MOSTRAR MENSAJE GENÉRICO DE ÉXITO
          _mostrarExito('Si el correo está registrado, recibirás un código de verificación');
        } else {
          // ✅ API RESPONDE CON success: false (mail no existe o error)
          // PERO MOSTRAMOS EL MISMO MENSAJE POR SEGURIDAD
          setState(() {
            _codigoEnviado = true; // ✅ SIMULAMOS QUE SE ENVIÓ PARA LA UX
            _horaEnvioCodigo = DateTime.now();
            _intentosFallidos = 0;
            _intentosRestantes = 3;
          });

          // ✅ INICIAR TIMER AUNQUE SEA FALSO (para mantener consistencia UX)
          _iniciarTimer();

          // ✅ MOSTRAR EL MISMO MENSAJE PARA NO REVELAR INFORMACIÓN
          _mostrarExito('Si el correo está registrado, recibirás un código de verificación');
        }
      } else {
        // ✅ ERROR HTTP (404, 500, etc.)
        // AUN ASÍ MOSTRAMOS MENSAJE GENÉRICO PARA NO REVELAR INFORMACIÓN
        setState(() {
          _codigoEnviado = true; // ✅ SIMULAMOS PARA MANTENER FLUJO DE UX
          _horaEnvioCodigo = DateTime.now();
          _intentosFallidos = 0;
          _intentosRestantes = 3;
        });

        // ✅ INICIAR TIMER AUNQUE HAYA ERROR (para consistencia UX)
        _iniciarTimer();

        // ✅ MENSAJE GENÉRICO
        _mostrarExito('Si el correo está registrado, recibirás un código de verificación');

        // Solo loguear el error para debugging, no mostrarlo al usuario
        print('⚠️ Error HTTP ${response.statusCode} en envío de código (oculto al usuario)');
      }
    } catch (e) {
      // ✅ ERROR DE CONEXIÓN (timeout, network error, etc.)
      // AUN ASÍ MOSTRAMOS MENSAJE GENÉRICO
      setState(() {
        _codigoEnviado = true; // ✅ SIMULAMOS PARA MANTENER FLUJO DE UX
        _horaEnvioCodigo = DateTime.now();
        _intentosFallidos = 0;
        _intentosRestantes = 3;
      });

      // ✅ INICIAR TIMER AUNQUE HAYA ERROR
      _iniciarTimer();

      // ✅ MENSAJE GENÉRICO
      _mostrarExito('Si el correo está registrado, recibirás un código de verificación');

      // Solo loguear el error para debugging
      print('⚠️ Error de conexión en envío de código (oculto al usuario): $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ CONFIRMAR CAMBIO DE CONTRASEÑA CON CÓDIGO
  Future<void> _confirmarCambioPassword() async {
    final email = _emailController.text.trim();
    final codigo = _codigoController.text.trim();
    final nuevaPassword = _nuevaPasswordController.text.trim();
    final confirmarPassword = _confirmarPasswordController.text.trim();

    // Validaciones
    if (email.isEmpty) {
      _mostrarError('Ingresa tu correo electrónico');
      return;
    }

    if (codigo.isEmpty) {
      _mostrarError('Ingresa el código de verificación');
      return;
    }

    if (codigo.length != 8) {
      _mostrarError('El código debe tener 8 caracteres');
      return;
    }

    if (nuevaPassword.isEmpty || confirmarPassword.isEmpty) {
      _mostrarError('Ingresa y confirma la nueva contraseña');
      return;
    }

    if (nuevaPassword != confirmarPassword) {
      _mostrarError('Las contraseñas no coinciden');
      return;
    }

    // Verificar si el código ha expirado (10 minutos)
    if (_horaEnvioCodigo != null) {
      final ahora = DateTime.now();
      final diferencia = ahora.difference(_horaEnvioCodigo!).inMinutes;

      if (diferencia > 10) {
        _mostrarError('El código ha expirado. Debes solicitar uno nuevo.');
        return;
      }
    }

    print('🔄 Confirmando cambio de contraseña...');

    setState(() {
      _isLoading = true;
    });

    try {
      final requestBody = {
        "codigo_verificador": codigo,
        "mail": email,
        "nuevo_pass": nuevaPassword,
      };

      print('📤 Request ConfirmarCambioPasswordSinToken:');
      print('🌐 URL: ${GlobalVariables.baseUrl}/ConfirmarCambioPassword/api/v1/');
      print('📋 Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/ConfirmarCambioPassword/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response ConfirmarCambioPasswordSinToken:');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == true) {
          _mostrarExito('Contraseña cambiada exitosamente');

          // Regresar al login después de 2 segundos
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            // ✅ CANCELAR TIMER ANTES DE SALIR
            _timer?.cancel();
            Navigator.pop(context);
          }
        } else {
          final mensajeError = responseData['message'] ?? 'Error desconocido';
          final codigoError = responseData['codigo_error'];

          // ✅ MODIFICACIÓN: MENSAJES GENÉRICOS PARA NO REVELAR INFORMACIÓN
          if (codigoError == 'DEMASIADOS_INTENTOS') {
            _mostrarError('No se puede procesar la solicitud. Intenta nuevamente.');

            setState(() {
              _codigoController.clear();
              _intentosFallidos = 0;
              _intentosRestantes = 0;
            });
          } else if (codigoError == 'CODIGO_EXPIRADO') {
            _mostrarError('El código ha expirado. Solicita uno nuevo.');

            setState(() {
              _codigoController.clear();
              _codigoEnviado = false;
            });
          } else if (codigoError == 'CODIGO_INCORRECTO') {
            // ✅ MENSAJE GENÉRICO SIN ESPECIFICAR INTENTOS
            _mostrarError('Código incorrecto. Verifica e intenta nuevamente.');

            setState(() {
              // No mostramos contador específico por seguridad
              _intentosFallidos++;
              _intentosRestantes = 3 - _intentosFallidos;
            });
          } else if (codigoError == 'CONTRASENA_IGUAL') {
            _mostrarError('La nueva contraseña no es válida');
          } else if (codigoError == 'SOLICITUD_NO_ENCONTRADA') {
            _mostrarError('No se puede procesar la solicitud. Solicita un nuevo código.');

            setState(() {
              _codigoController.clear();
              _codigoEnviado = false;
            });
          } else {
            // ✅ MENSAJE GENÉRICO PARA CUALQUIER OTRO ERROR
            _mostrarError('No se pudo completar la operación. Intenta nuevamente.');
          }
        }
      } else {
        // ✅ ERROR HTTP - MENSAJE GENÉRICO
        _mostrarError('No se pudo completar la operación. Intenta nuevamente.');
        print('⚠️ Error HTTP ${response.statusCode} (oculto al usuario)');
      }
    } catch (e) {
      print('❌ Error confirmando cambio de contraseña: $e');
      _mostrarError('Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ Métodos auxiliares para mostrar mensajes
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ✅ CALCULAR SEGUNDOS RESTANTES
  int _getSegundosRestantes() {
    if (_horaEnvioCodigo == null) return 0;

    final ahora = DateTime.now();
    final diferencia = ahora.difference(_horaEnvioCodigo!);
    final segundosTranscurridos = diferencia.inSeconds;
    final segundosTotalesDisponibles = 10 * 60;
    final segundosRestantes = segundosTotalesDisponibles - segundosTranscurridos;

    return segundosRestantes.clamp(0, segundosTotalesDisponibles);
  }

  // ✅ Calcular tiempo restante para expiración del código
  String _getTiempoRestante() {
    final segundosRestantes = _getSegundosRestantes();

    if (segundosRestantes <= 0) {
      return '00:00';
    }

    final minutosRestantes = segundosRestantes ~/ 60;
    final segundosEnMinuto = segundosRestantes % 60;

    return '${minutosRestantes.toString().padLeft(2, '0')}:${segundosEnMinuto.toString().padLeft(2, '0')}';
  }

  // ✅ MÉTODO AUXILIAR PARA VERIFICAR EMAIL
  bool _esEmailValido(String email) {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegex.hasMatch(email.trim());
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
          icon: Icon(Icons.arrow_back, color: _blueDarkColor),
          onPressed: () {
            // ✅ CANCELAR TIMER ANTES DE SALIR
            _timer?.cancel();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Recuperar Contraseña',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _blueDarkColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ BOTÓN PARA ENVIAR CÓDIGO EN LA PARTE SUPERIOR
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _botonEnviarCodigoHabilitado ? _enviarCodigo : null,
                icon: const Icon(Icons.send, size: 20, color: Colors.white),
                label: const Text(
                  'Solicitar código de verificación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _botonEnviarCodigoHabilitado
                      ? _blueDarkColor
                      : Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ✅ INFORMACIÓN DEL CÓDIGO ENVIADO (si se ha enviado)
            if (_codigoEnviado && !codigoExpirado) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _blueDarkColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _blueDarkColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitud procesada para:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _blueDarkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _emailController.text,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 18,
                              color: segundosRestantes < 60
                                  ? Colors.red.shade700
                                  : _blueDarkColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getTiempoRestante(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: segundosRestantes < 60
                                    ? Colors.red.shade700
                                    : _blueDarkColor,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _isLoading ? null : _enviarCodigo,
                          icon:
                          Icon(Icons.refresh, size: 16, color: _blueDarkColor),
                          label: Text(
                            'Reenviar código',
                            style: TextStyle(
                              fontSize: 14,
                              color: _blueDarkColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // ✅ ADVERTENCIA SI EL CÓDIGO HA EXPIRADO
            if (codigoExpirado && _horaEnvioCodigo != null) ...[
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
                    Icon(
                      Icons.warning,
                      color: Colors.orange.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El código ha expirado. Presiona "Solicitar código de verificación" para obtener uno nuevo.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ✅ ADVERTENCIA DE INTENTOS FALLIDOS
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
                    Icon(
                      Icons.warning,
                      color: Colors.red.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Intentos fallidos: $_intentosFallidos/3',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ✅ CAMPO DE EMAIL - SIEMPRE VISIBLE
            const Text(
              'Correo electrónico',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'ejemplo@dominio.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _blueDarkColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: Icon(Icons.email,
                    size: 20, color: Colors.grey.shade600),
                // ✅ AGREGAR ICONO DE VALIDACIÓN SI ES NECESARIO
                suffixIcon: _emailController.text.isNotEmpty
                    ? Icon(
                  Icons.check_circle,
                  size: 20,
                  color: _esEmailValido(_emailController.text)
                      ? Colors.green
                      : Colors.grey,
                )
                    : null,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              // ✅ AGREGAR VALIDADOR OPCIONAL
              onChanged: (value) {
                // Forzar redibujado para actualizar el icono
                setState(() {});
              },
            ),

            const SizedBox(height: 24),

            // ✅ CAMPO PARA CÓDIGO DE VERIFICACIÓN - SIEMPRE VISIBLE
            const Text(
              'Código de verificación',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _codigoController,
              maxLength: 8,
              decoration: InputDecoration(
                hintText: 'Ingresa el código de 8 dígitos',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _blueDarkColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                counterText: '',
                prefixIcon: Icon(Icons.code,
                    size: 20, color: Colors.grey.shade600),
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 24),

            // ✅ CAMPO PARA NUEVA CONTRASEÑA - SIEMPRE VISIBLE
            const Text(
              'Nueva contraseña',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nuevaPasswordController,
              obscureText: !_mostrarContrasena,
              decoration: InputDecoration(
                hintText: 'Ingresa nueva contraseña',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _blueDarkColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: Icon(Icons.lock_outline,
                    size: 20, color: Colors.grey.shade600),
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarContrasena
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _mostrarContrasena = !_mostrarContrasena;
                    });
                  },
                ),
              ),
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 16),

            // ✅ CAMPO PARA CONFIRMAR CONTRASEÑA - SIEMPRE VISIBLE
            const Text(
              'Confirmar contraseña',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmarPasswordController,
              obscureText: !_mostrarConfirmarContrasena,
              decoration: InputDecoration(
                hintText: 'Confirma la nueva contraseña',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _blueDarkColor, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
                prefixIcon: Icon(Icons.lock_outline,
                    size: 20, color: Colors.grey.shade600),
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarConfirmarContrasena
                        ? Icons.visibility_off
                        : Icons.visibility,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _mostrarConfirmarContrasena = !_mostrarConfirmarContrasena;
                    });
                  },
                ),
              ),
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 32),

            // ✅ BOTÓN PARA CONFIRMAR CAMBIO DE CONTRASEÑA
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _botonCambiarPasswordHabilitado
                    ? _confirmarCambioPassword
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _botonCambiarPasswordHabilitado
                      ? _blueDarkColor
                      : Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  'Cambiar Contraseña',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
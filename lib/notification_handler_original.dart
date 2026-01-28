import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'dart:async'; // ✅ IMPORTACIÓN AGREGADA
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import 'dashboard_screen2.dart';
import 'variables_globales.dart';

class NotificationHandler {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ✅ VARIABLE PARA CONTROLAR EL SNACKBAR ACTUAL
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _currentSnackBar;

  // ✅ INICIALIZAR CON EL navigatorKey DEL MAIN
  static void initializeNotifications() {
    print('🔔 Inicializando notificaciones...');

    // Configurar notificaciones en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Notificación en primer plano recibida!');
      print('📋 Título: ${message.notification?.title}');
      print('📋 Cuerpo: ${message.notification?.body}');
      print('📋 Datos: ${message.data}');

      // ✅ MOSTRAR SNACKBAR EN PRIMER PLANO Y NAVEGAR AL TOCAR
      _showForegroundNotification(message);
    });

    // Configurar cuando se abre la notificación (app en segundo plano/cerrada)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🚀 Notificación abierta desde segundo plano/cerrada');
      print('📋 Título: ${message.notification?.title}');
      print('📋 Cuerpo: ${message.notification?.body}');
      print('📋 Datos: ${message.data}');

      // ✅ CERRAR SNACKBAR SI ESTÁ ABIERTO
      _closeCurrentSnackBar();
      _navigateToNotificationDetail(message);
    });

    // Manejar notificación cuando la app está totalmente cerrada
    _handleTerminatedNotification();

    // Solicitar permisos
    _requestPermissions();
  }

  // ✅ MÉTODO PARA CERRAR EL SNACKBAR ACTUAL
  static void _closeCurrentSnackBar() {
    if (_currentSnackBar != null) {
      try {
        _currentSnackBar!.close();
        _currentSnackBar = null;
        print('✅ SnackBar cerrado manualmente');
      } catch (e) {
        print('❌ Error cerrando SnackBar: $e');
      }
    }
  }

  static Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('📋 Permisos de notificación: ${settings.authorizationStatus}');

      // Obtener token FCM
      String? token = await _firebaseMessaging.getToken();
      print('🔑 Token FCM: $token');

    } catch (e) {
      print('❌ Error solicitando permisos: $e');
    }
  }

  static void _showForegroundNotification(RemoteMessage message) {
    print('🎬 Mostrando notificación en primer plano...');

    if (navigatorKey.currentContext != null) {
      print('✅ Contexto disponible para SnackBar');

      // ✅ CERRAR SNACKBAR ANTERIOR SI EXISTE
      _closeCurrentSnackBar();

      // Mostrar SnackBar que al tocarlo abre la vista
      _currentSnackBar = ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.notification?.title ?? 'Nueva compra',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                message.notification?.body ?? 'Toca para ver detalles',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          duration: const Duration(seconds: 25),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () {
              print('👆 SnackBar action presionado');
              _closeCurrentSnackBar(); // ✅ CERRAR AL HACER CLICK EN "VER"
              _navigateToNotificationDetail(message);
            },
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          onVisible: () {
            print('👀 SnackBar visible');
          },
        ),
      );

      // ✅ LIMPIAR REFERENCIA CUANDO EL SNACKBAR SE CIERRE AUTOMÁTICAMENTE
      _currentSnackBar?.closed.then((reason) {
        print('📭 SnackBar cerrado: $reason');
        _currentSnackBar = null;
      });

    } else {
      print('❌ No hay contexto disponible para SnackBar');
      // Si no hay contexto, navegar directamente
      _navigateToNotificationDetail(message);
    }
  }

  static void _navigateToNotificationDetail(RemoteMessage message) {
    print('🧭 Navegando a detalle de notificación...');
    print('🔍 NavigatorKey estado: ${navigatorKey.currentState}');

    if (navigatorKey.currentState != null) {
      try {
        // ✅ USAR pushReplacement EN LUGAR DE push
        navigatorKey.currentState!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => NotificationDetailScreen(
              notificationData: message.data,
              notificationTitle: message.notification?.title ?? 'Notificación',
              notificationBody: message.notification?.body ?? '',
            ),
          ),
        );
        print('✅ Navegación exitosa a NotificationDetailScreen (reemplazando ruta actual)');
      } catch (e) {
        print('❌ Error en navegación: $e');
      }
    } else {
      print('❌ No se puede navegar: navigatorKey.currentState es null');
      print('⚠️ Verifica que el navigatorKey esté configurado en MaterialApp');
    }
  }

  static Future<void> _handleTerminatedNotification() async {
    print('🔍 Verificando notificaciones de app terminada...');
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('🔓 App abierta desde notificación (estado terminado)');
      print('📋 Título: ${initialMessage.notification?.title}');
      print('📋 Cuerpo: ${initialMessage.notification?.body}');
      print('📋 Datos: ${initialMessage.data}');
      // Esperar un poco para que la app se inicialice completamente
      await Future.delayed(const Duration(milliseconds: 2000));
      _navigateToNotificationDetail(initialMessage);
    } else {
      print('📭 No hay notificaciones de app terminada');
    }
  }
}

// ✅ PANTALLA DE DETALLE DE NOTIFICACIÓN MEJORADA CON LLAMADA REAL A LA API
class NotificationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> notificationData;
  final String notificationTitle;
  final String notificationBody;

  const NotificationDetailScreen({
    super.key,
    required this.notificationData,
    required this.notificationTitle,
    required this.notificationBody,
  });

  @override
  State<NotificationDetailScreen> createState() => _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> with SingleTickerProviderStateMixin {
  bool _aceptoPoliticas = false;
  bool _showResultAnimation = false;
  bool _isApproved = false;
  bool _isLoading = false;
  String _apiResponseMessage = '';
  Map<String, dynamic> _apiResponseData = {};
  late Timer _autoRejectTimer; // ✅ TIMER CORREGIDO

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // ✅ IMPRIMIR DATOS DE LA NOTIFICACIÓN PARA DEBUG
    print('📋 Datos de notificación recibidos:');
    widget.notificationData.forEach((key, value) {
      print('   - $key: $value');
    });

    // ✅ INICIAR TIMER PARA RECHAZO AUTOMÁTICO EN 20 SEGUNDOS
    _startAutoRejectTimer();

    // ✅ CERRAR CUALQUIER SNACKBAR QUE PUEDA HABER QUEDADO ABIERTO
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationHandler._closeCurrentSnackBar();
    });
  }

  @override
  void dispose() {
    _autoRejectTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ✅ TIMER PARA RECHAZO AUTOMÁTICO
  void _startAutoRejectTimer() {
    print('⏰ Iniciando timer de rechazo automático (20 segundos)');
    _autoRejectTimer = Timer(const Duration(seconds: 20), () {
      print('⏰ Tiempo agotado - Rechazo automático de compra');
      if (!_showResultAnimation && !_isLoading) {
        _rejectCompra(descripcion: 'Compra cancelada por tiempo de espera agotado');
      }
    });
  }

  // ✅ FORMATO DE MONEDA CHILENA
  String _formatCurrency(String amount) {
    try {
      // Remover cualquier caracter no numérico
      String cleanAmount = amount.replaceAll(RegExp(r'[^\d]'), '');
      int value = int.tryParse(cleanAmount) ?? 0;

      // Formatear con separadores de miles
      String formatted = value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]}.',
      );

      return '\$$formatted';
    } catch (e) {
      return '\$$amount';
    }
  }

  Future<void> _abrirPoliticaCobranza() async {
    final Uri url = Uri.parse('https://apiorsanpay.orsanevaluaciones.cl/');

    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('No se pudo abrir la URL: $url');
    }
  }

  // ✅ MÉTODO PARA RECHAZAR COMPRA (MANUAL Y AUTOMÁTICO)
  Future<void> _rejectCompra({required String descripcion}) async {
    // Cancelar timer si está activo
    if (_autoRejectTimer.isActive) {
      _autoRejectTimer.cancel();
      print('⏰ Timer de rechazo automático cancelado');
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 ========== INICIANDO LLAMADA A API RECHAZAR COMPRA ==========');

      // ✅ PREPARAR DATOS PARA LA API DE RECHAZO
      final Map<String, dynamic> requestBody = {
        "token_venta": widget.notificationData['token_venta'] ?? '',
        "descripcion": descripcion,
      };

      print('📤 REQUEST BODY RECHAZAR COMPRA:');
      print('   🔹 token_venta: ${requestBody["token_venta"]}');
      print('   🔹 descripcion: $descripcion');

      final String requestBodyJson = json.encode(requestBody);
      print('📦 JSON ENVIADO: $requestBodyJson');

      final String apiUrl = '${GlobalVariables.baseUrl}/RechazarCompra/api/v1/';
      print('🌐 URL COMPLETA: $apiUrl');
      print('🔑 API KEY: ${GlobalVariables.apiKey}');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: requestBodyJson,
      ).timeout(const Duration(seconds: 30));

      print('📥 ========== RESPONSE RECIBIDO RECHAZAR COMPRA ==========');
      print('   🔹 Status Code: ${response.statusCode}');
      print('   🔹 Headers: ${response.headers}');
      print('   🔹 Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ COMPRA RECHAZADA EXITOSAMENTE');
        print('📋 RESPONSE DATA:');
        responseData.forEach((key, value) {
          print('   🔸 $key: $value');
        });

        _apiResponseData = responseData;
        _apiResponseMessage = responseData['mensaje'] ?? descripcion;

      } else {
        print('❌ ERROR HTTP EN RECHAZAR COMPRA: ${response.statusCode}');
        print('❌ BODY DEL ERROR: ${response.body}');
        _apiResponseMessage = 'Error al rechazar compra: ${response.statusCode}';
      }

    } catch (e) {
      print('❌ ========== ERROR EN _rejectCompra ==========');
      print('❌ Exception: $e');
      print('❌ StackTrace: ${e.toString()}');
      _apiResponseMessage = 'Error de conexión: $e';
    } finally {
      setState(() {
        _isLoading = false;
        _isApproved = false;
        _showResultAnimation = true;
      });
      _controller.forward();
      print('🎬 Mostrando animación de rechazo');
    }
  }

  // ✅ MÉTODO ACTUALIZADO: LLAMADA REAL A LA API PARA CONFIRMAR
  Future<void> _confirmAction(BuildContext context) async {
    if (!_aceptoPoliticas) {
      _mostrarErrorPoliticas();
      return;
    }

    // Cancelar timer de rechazo automático
    if (_autoRejectTimer.isActive) {
      _autoRejectTimer.cancel();
      print('⏰ Timer de rechazo automático cancelado por confirmación');
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 ========== INICIANDO LLAMADA A API GUARDAR COMPRA ==========');
      print('notificationData: ${widget.notificationData}');
      // ✅ PREPARAR DATOS PARA LA API
      final Map<String, dynamic> requestBody = {
        "token_comprador": widget.notificationData['token_comprador'] ?? '',
        "token_vendedor": widget.notificationData['token_vendedor'] ?? '',
        "token_empresa": widget.notificationData['token_empresa'] ?? '',
        "monto_venta": widget.notificationData['monto'] ?? '0',
        "run_comprador": widget.notificationData['run_comprador'] ?? '',
        "dv_comprador": widget.notificationData['dv_comprador'] ?? '',
        "rut_empresa": widget.notificationData['rut_empresa'] ?? '',
        "dv_empresa": widget.notificationData['dv_empresa'] ?? '',
        "fecha_expiracion": widget.notificationData['fecha_expiracion'] ?? '',
        "telefono_comprador": widget.notificationData['telefono_comprador'] ?? '',
        "nombre_comercio": widget.notificationData['comercio'] ?? '',
        "numero_comercio": widget.notificationData['numero_comercio'] ?? '',
        "nombre_vendedor": widget.notificationData['nombre_vendedor'] ?? '',
        "numero_contrato": widget.notificationData['numero_contrato'] ?? '',
        "token_venta": widget.notificationData['token_venta'] ?? '',
      };

      print('📤 REQUEST BODY GUARDAR COMPRA:');
      requestBody.forEach((key, value) {
        print('   🔹 $key: $value');
      });

      final String requestBodyJson = json.encode(requestBody);
      print('📦 JSON ENVIADO: $requestBodyJson');

      final String apiUrl = '${GlobalVariables.baseUrl}/GuardarCompra/api/v1/';
      print('🌐 URL COMPLETA: $apiUrl');
      print('🔑 API KEY: ${GlobalVariables.apiKey}');

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: requestBodyJson,
      ).timeout(const Duration(seconds: 30));

      print('📥 ========== RESPONSE RECIBIDO GUARDAR COMPRA ==========');
      print('   🔹 Status Code: ${response.statusCode}');
      print('   🔹 Headers: ${response.headers}');
      print('   🔹 Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _apiResponseData = responseData;

        print('✅ API RESPONSE DATA GUARDAR COMPRA:');
        responseData.forEach((key, value) {
          print('   🔸 $key: $value');
        });

        // ✅ DETERMINAR SI FUE APROBADA O RECHAZADA SEGÚN LA RESPUESTA REAL
        final bool success = responseData['success'] == true;
        final int estadoVenta = responseData['estado_venta'] ?? 0;
        final String mensaje = responseData['mensaje'] ?? 'Sin mensaje';

        _isApproved = success && estadoVenta == 1;
        _apiResponseMessage = mensaje;

        print('🎯 RESULTADO DE LA COMPRA:');
        print('   🔸 Success: $success');
        print('   🔸 Estado Venta: $estadoVenta');
        print('   🔸 Aprobada: $_isApproved');
        print('   🔸 Mensaje: $_apiResponseMessage');

      } else {
        print('❌ ERROR HTTP GUARDAR COMPRA: ${response.statusCode}');
        print('❌ BODY DEL ERROR: ${response.body}');
        _isApproved = false;
        _apiResponseMessage = 'Error de conexión: ${response.statusCode}';
      }

    } catch (e) {
      print('❌ ========== ERROR EN _confirmAction ==========');
      print('❌ Exception: $e');
      print('❌ StackTrace: ${e.toString()}');
      _isApproved = false;
      _apiResponseMessage = 'Error de conexión: $e';
    } finally {
      setState(() {
        _isLoading = false;
        _showResultAnimation = true;
      });
      _controller.forward();
      print('🎬 Mostrando animación de resultado - Aprobada: $_isApproved');
    }
  }

  // ✅ MODIFICADO: RECHAZAR MANUALMENTE
  void _rejectAction(BuildContext context) {
    print('❌ COMPRA RECHAZADA MANUALMENTE POR EL USUARIO');
    _rejectCompra(descripcion: 'Compra rechazada manualmente por el usuario');
  }

  void _mostrarErrorPoliticas() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debe aceptar la política de gestión de cobranza para continuar'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // ✅ MÉTODO PARA NAVEGAR AL DASHBOARD
  void _navigateToDashboard() {
    print('🏠 Navegando al Dashboard...');

    // ✅ NAVEGAR AL DASHBOARD Y LIMPIAR TODAS LAS RUTAS ANTERIORES
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (context) => DashboardScreen(userData: {}) // ✅ DASHBOARD CON DATOS VACÍOS (SE ACTUALIZARÁN AUTOMÁTICAMENTE)
      ),
          (route) => false, // Elimina todas las rutas anteriores
    );
  }

  // ✅ MODIFICADO: FINALIZAR AHORA LLEVA AL DASHBOARD
  void _onFinalizar() {
    _navigateToDashboard();
  }

  // ✅ ANIMACIÓN PARA COMPRA APROBADA
  Widget _buildApprovedAnimation() {
    return Scaffold(
      backgroundColor: const Color(0xFFE3FAEF),
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: const Icon(
                      Icons.check,
                      size: 50,
                      color: Color(0xFF0A915C),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _apiResponseMessage.isNotEmpty
                        ? _apiResponseMessage
                        : "Tu compra ha sido confirmada",
                    style: const TextStyle(
                      color: Color(0xFF0A915C),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  // ✅ MOSTRAR DETALLES ADICIONALES SI ESTÁN DISPONIBLES
                  if (_apiResponseData['monto_disponible'] != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Monto disponible: \$${_apiResponseData['monto_disponible']}',
                      style: const TextStyle(
                        color: Color(0xFF0A915C),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: _onFinalizar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A915C),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Finalizar",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ ANIMACIÓN PARA COMPRA RECHAZADA
  Widget _buildRejectedAnimation() {
    return Scaffold(
      backgroundColor: const Color(0xFFFDE8E8),
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: const Icon(
                      Icons.close,
                      size: 50,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _apiResponseMessage.isNotEmpty
                        ? _apiResponseMessage
                        : "Tu compra no ha sido aceptada",
                    style: const TextStyle(
                      color: Color(0xFFD32F2F),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Por favor, verifica tu información o intenta con otro método de pago",
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // ✅ MOSTRAR RAZÓN DEL RECHAZO SI ESTÁ DISPONIBLE
                  if (_apiResponseData['razon_rechazo'] != null) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Razón: ${_apiResponseData['razon_rechazo']}',
                        style: const TextStyle(
                          color: Color(0xFFD32F2F),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: _onFinalizar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        "Entendido",
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ SI SE MUESTRA LA ANIMACIÓN DE RESULTADO
    if (_showResultAnimation) {
      return _isApproved ? _buildApprovedAnimation() : _buildRejectedAnimation();
    }

    // ✅ VISTA NORMAL DE NOTIFICACIÓN
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _navigateToDashboard,
        ),
        title: const Text(
          'Detalle de Compra',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header con icono
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.shade50,
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.shopping_cart,
                          size: 40,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.notificationTitle,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1976D2),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tienes 20 segundos para responder',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Detalles de la compra
                const Text(
                  'Detalles de la compra',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),

                _buildDetailCard(
                  icon: Icons.store,
                  label: 'Comercio',
                  value: widget.notificationData['comercio'] ?? 'No especificado',
                ),
                const SizedBox(height: 12),
                _buildDetailCard(
                  icon: Icons.attach_money,
                  label: 'Monto',
                  value: _formatCurrency(widget.notificationData['monto'] ?? '0'),
                ),

                const SizedBox(height: 24),

                // ✅ CHECKBOX DE POLÍTICAS
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _aceptoPoliticas,
                        onChanged: (bool? value) {
                          setState(() {
                            _aceptoPoliticas = value ?? false;
                          });
                        },
                        activeColor: Color(0xFF1976D2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: _abrirPoliticaCobranza,
                          child: RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                                height: 1.4,
                              ),
                              children: [
                                TextSpan(text: 'Estoy de acuerdo con la '),
                                TextSpan(
                                  text: 'política de gestión de cobranza',
                                  style: TextStyle(
                                    color: Color(0xFF1976D2),
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Botones de acción
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () => _rejectAction(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.red.shade400, width: 2),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          'Rechazar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _aceptoPoliticas && !_isLoading
                            ? () => _confirmAction(context)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _aceptoPoliticas && !_isLoading
                              ? Colors.green
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                            : const Text(
                          'Confirmar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ✅ OVERLAY DE CARGA
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1976D2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Color(0xFF1976D2),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
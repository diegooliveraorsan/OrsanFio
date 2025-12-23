import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

import 'dashboard_screen.dart';
import 'variables_globales.dart';

class NotificationHandler {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  // ✅ SEPARAR CONTROLADORES PARA SNACKBAR Y MATERIALBANNER
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _currentSnackBar;
  static ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>? _currentMaterialBanner;
  static OverlayEntry? _notificationOverlay;
  static RemoteMessage? _currentMessage; // ✅ GUARDAR EL MENSAJE ACTUAL

  // ✅ TIMER INDEPENDIENTE PARA CADA NOTIFICACIÓN
  static Timer? _currentNotificationTimer;

  // ✅ COLOR AZUL OSCURO (IGUAL QUE EN PROFILE SCREEN)
  static const Color _blueDarkColor = Color(0xFF0055B8);

  // ✅ COLOR DE FONDO DE TARJETAS APROBADAS (IGUAL QUE EN PROFILE SCREEN)
  static const Color _approvedCardBackground = Color(0xFFE8F0FE);

  // ✅ INICIALIZAR CON EL navigatorKey DEL MAIN
  static void initializeNotifications() {
    print('🔔 Inicializando notificaciones...');

    // Configurar notificaciones en primer plano
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📱 Notificación en primer plano recibida!');
      print('📋 Título: ${message.notification?.title}');
      print('📋 Cuerpo: ${message.notification?.body}');
      print('📋 Datos: ${message.data}');

      // ✅ GUARDAR EL MENSAJE ACTUAL
      _currentMessage = message;

      // ✅ MOSTRAR NOTIFICACIÓN EN PARTE SUPERIOR
      _showForegroundNotification(message);
    });

    // Configurar cuando se abre la notificación (app en segundo plano/cerrada)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🚀 Notificación abierta desde segundo plano/cerrada');
      print('📋 Título: ${message.notification?.title}');
      print('📋 Cuerpo: ${message.notification?.body}');
      print('📋 Datos: ${message.data}');

      // ✅ GUARDAR EL MENSAJE ACTUAL
      _currentMessage = message;

      // ✅ CERRAR NOTIFICACIONES SI ESTÁN ABIERTAS
      _closeCurrentNotifications();
      _navigateToNotificationDetail(message);
    });

    // Manejar notificación cuando la app está totalmente cerrada
    _handleTerminatedNotification();

    // Solicitar permisos
    _requestPermissions();
  }

  // ✅ MÉTODO PARA CERRAR TODAS LAS NOTIFICACIONES ACTUALES
  static void _closeCurrentNotifications() {
    // ✅ CANCELAR TIMER ACTUAL
    if (_currentNotificationTimer != null && _currentNotificationTimer!.isActive) {
      _currentNotificationTimer!.cancel();
      _currentNotificationTimer = null;
      print('✅ Timer de notificación cancelado');
    }

    if (_currentMaterialBanner != null) {
      try {
        _currentMaterialBanner!.close();
        _currentMaterialBanner = null;
        print('✅ MaterialBanner cerrado manualmente');
      } catch (e) {
        print('❌ Error cerrando MaterialBanner: $e');
      }
    }

    if (_currentSnackBar != null) {
      try {
        _currentSnackBar!.close();
        _currentSnackBar = null;
        print('✅ SnackBar cerrado manualmente');
      } catch (e) {
        print('❌ Error cerrando SnackBar: $e');
      }
    }

    if (_notificationOverlay != null) {
      try {
        _notificationOverlay!.remove();
        _notificationOverlay = null;
        print('✅ Overlay cerrado manualmente');
      } catch (e) {
        print('❌ Error cerrando Overlay: $e');
      }
    }

    _currentMessage = null; // ✅ LIMPIAR EL MENSAJE ACTUAL
  }

  // ✅ MÉTODO PARA RECHAZAR COMPRA AL CERRAR LA NOTIFICACIÓN
  static Future<void> _rejectCurrentCompra() async {
    if (_currentMessage == null) {
      print('❌ No hay mensaje actual para rechazar');
      return;
    }

    final tokenVenta = _currentMessage!.data['token_venta'];
    if (tokenVenta == null) {
      print('❌ No hay token_venta en el mensaje actual');
      return;
    }

    print('❌ RECHAZANDO COMPRA AL CERRAR NOTIFICACIÓN');
    print('📋 Token venta: $tokenVenta');

    try {
      final Map<String, dynamic> requestBody = {
        "token_venta": tokenVenta,
        "descripcion": "Compra cancelada al cerrar la notificación",
      };

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/RechazarCompra/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));

      print('📥 Response rechazo por cerrar notificación - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Compra rechazada exitosamente al cerrar notificación');
      } else {
        print('❌ Error al rechazar compra: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ Error en _rejectCurrentCompra: $e');
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

  // ✅ MÉTODO PRINCIPAL: MOSTRAR NOTIFICACIÓN EN PARTE SUPERIOR
  static void _showForegroundNotification(RemoteMessage message) {
    print('🎬 Mostrando notificación en primer plano...');

    if (navigatorKey.currentContext != null) {
      print('✅ Contexto disponible para notificación');

      // ✅ CERRAR NOTIFICACIONES ANTERIORES (INCLUYENDO TIMERS)
      _closeCurrentNotifications();

      // ✅ GUARDAR EL MENSAJE ACTUAL
      _currentMessage = message;

      // ✅ USAR OVERLAY PERSONALIZADO (RECOMENDADO)
      _showCustomTopNotification(message);

    } else {
      print('❌ No hay contexto disponible para notificación');
      // Si no hay contexto, navegar directamente
      _navigateToNotificationDetail(message);
    }
  }

  // ✅ MÉTODO CON OVERLAY PERSONALIZADO EN PARTE SUPERIOR
  static void _showCustomTopNotification(RemoteMessage message) {
    print('🎬 Mostrando notificación personalizada en parte superior...');

    if (navigatorKey.currentContext != null) {
      try {
        final overlay = Overlay.of(navigatorKey.currentContext!);

        // Crear el overlay entry
        _notificationOverlay = OverlayEntry(
          builder: (context) => _NotificationOverlayContent(
            message: message,
            onTap: () {
              print('👆 Notificación personalizada presionada');
              _closeCurrentNotifications(); // ✅ CANCELAR TIMER DE NOTIFICACIÓN
              _navigateToNotificationDetail(message);
            },
            onClose: () {
              print('❌ Botón X presionado - Rechazando compra');
              _rejectCurrentCompra();
              _closeCurrentNotifications();
            },
          ),
        );

        // Insertar el overlay
        overlay.insert(_notificationOverlay!);
        print('✅ Notificación overlay mostrada exitosamente en parte superior');

        // ✅ INICIAR TIMER PARA ESTA NOTIFICACIÓN (10 SEGUNDOS)
        _startNotificationTimer();

      } catch (e) {
        print('❌ Error mostrando overlay: $e');
        // Si falla el overlay, intentar con MaterialBanner
        _showMaterialBannerNotification(message);
      }
    }
  }

  // ✅ MÉTODO PARA INICIAR EL TIMER (10 SEGUNDOS)
  static void _startNotificationTimer() {
    const totalSeconds = 10; // ✅ CAMBIADO A 10 SEGUNDOS
    int elapsedSeconds = 0;

    // ✅ CANCELAR TIMER ANTERIOR SI EXISTE
    if (_currentNotificationTimer != null && _currentNotificationTimer!.isActive) {
      _currentNotificationTimer!.cancel();
    }

    _currentNotificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsedSeconds++;

      if (elapsedSeconds >= totalSeconds) {
        print('⏰ Tiempo agotado (10s) - Rechazando compra automáticamente');
        _rejectCurrentCompra();
        _closeCurrentNotifications();
        timer.cancel();
      }
    });
  }

  // ✅ MÉTODO ALTERNATIVO: MATERIAL BANNER
  static void _showMaterialBannerNotification(RemoteMessage message) {
    print('🎬 Intentando con MaterialBanner...');

    try {
      _currentMaterialBanner = ScaffoldMessenger.of(navigatorKey.currentContext!).showMaterialBanner(
        MaterialBanner(
          content: GestureDetector(
            onTap: () {
              print('👆 MaterialBanner presionado');
              _closeCurrentNotifications(); // ✅ CANCELAR TIMER DE NOTIFICACIÓN
              _navigateToNotificationDetail(message);
            },
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _blueDarkColor.withOpacity(0.1), // ✅ AZUL OSCURO CON OPACIDAD
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_cart,
                    color: _blueDarkColor, // ✅ CAMBIADO A AZUL OSCURO
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.notification?.title ?? 'Nueva compra',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _blueDarkColor, // ✅ TÍTULO EN AZUL OSCURO
                        ),
                      ),
                      Text(
                        message.notification?.body ?? 'Toca para ver detalles',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ✅ INDICADOR DE TIEMPO RESTANTE SIMPLE (SIN ValueNotifier)
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 6,
          padding: const EdgeInsets.all(16),
          leadingPadding: EdgeInsets.zero,
          actions: [
            // ✅ BOTÓN X QUE RECHAZA LA COMPRA
            IconButton(
              icon: Icon(
                Icons.close,
                size: 20,
                color: Colors.red.shade700,
              ),
              onPressed: () {
                print('❌ Botón X presionado - Rechazando compra');
                _rejectCurrentCompra();
                _closeCurrentNotifications();
              },
            ),
          ],
        ),
      );

      print('✅ MaterialBanner mostrado exitosamente');

      // ✅ INICIAR TIMER PARA ESTA NOTIFICACIÓN (10 SEGUNDOS)
      _startNotificationTimer();

    } catch (e) {
      print('❌ Error mostrando MaterialBanner: $e');
      // Si todo falla, navegar directamente
      _navigateToNotificationDetail(message);
    }
  }

  static void _navigateToNotificationDetail(RemoteMessage message) {
    print('🧭 Navegando a detalle de notificación...');
    print('🔍 NavigatorKey estado: ${navigatorKey.currentState}');

    if (navigatorKey.currentState != null) {
      try {
        navigatorKey.currentState!.pushReplacement(
          MaterialPageRoute(
            builder: (context) => NotificationDetailScreen(
              notificationData: message.data,
              notificationTitle: message.notification?.title ?? 'Notificación',
              notificationBody: message.notification?.body ?? '',
            ),
          ),
        );
        print('✅ Navegación exitosa a NotificationDetailScreen');
      } catch (e) {
        print('❌ Error en navegación: $e');
      }
    } else {
      print('❌ No se puede navegar: navigatorKey.currentState es null');
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
      await Future.delayed(const Duration(milliseconds: 2000));
      _navigateToNotificationDetail(initialMessage);
    } else {
      print('📭 No hay notificaciones de app terminada');
    }
  }
}

// ✅ WIDGET SEPARADO PARA EL OVERLAY DE NOTIFICACIÓN (EVITA PROBLEMAS DE ValueNotifier)
class _NotificationOverlayContent extends StatefulWidget {
  final RemoteMessage message;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _NotificationOverlayContent({
    required this.message,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_NotificationOverlayContent> createState() => _NotificationOverlayContentState();
}

class _NotificationOverlayContentState extends State<_NotificationOverlayContent> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _progressAnimation;
  Timer? _timer;
  int _elapsedSeconds = 0;
  final int _totalSeconds = 10;

  // ✅ COLOR AZUL OSCURO (IGUAL QUE EN PROFILE SCREEN)
  final Color _blueDarkColor = const Color(0xFF0055B8);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );

    _progressAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);

    // Iniciar animación y timer
    _controller.forward();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });

      if (_elapsedSeconds >= _totalSeconds) {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 10,
      right: 10,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: _blueDarkColor, // ✅ CAMBIADO A AZUL OSCURO
                width: 2.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _blueDarkColor.withOpacity(0.1), // ✅ AZUL OSCURO CON OPACIDAD
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shopping_cart,
                    color: _blueDarkColor, // ✅ CAMBIADO A AZUL OSCURO
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message.notification?.title ?? 'Nueva compra',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _blueDarkColor, // ✅ TÍTULO EN AZUL OSCURO
                        ),
                      ),
                      Text(
                        widget.message.notification?.body ?? 'Toca para ver detalles',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // ✅ INDICADOR DE TIEMPO RESTANTE CON ANIMACIÓN
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            final progress = _progressAnimation.value;
                            return FractionallySizedBox(
                              widthFactor: progress,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: progress > 0.5
                                      ? Colors.green.shade600
                                      : progress > 0.2
                                      ? Colors.orange.shade600
                                      : Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // ✅ BOTÓN X QUE RECHAZA LA COMPRA
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 20,
                    color: Colors.red.shade700,
                  ),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
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

// ✅ PANTALLA DE DETALLE DE NOTIFICACIÓN
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
  late Timer _autoRejectTimer;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // ✅ COLOR AZUL OSCURO (IGUAL QUE EN PROFILE SCREEN)
  final Color _blueDarkColor = const Color(0xFF0055B8);

  // ✅ COLOR DE FONDO DE TARJETAS APROBADAS (IGUAL QUE EN PROFILE SCREEN)
  final Color _approvedCardBackground = const Color(0xFFE8F0FE);

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

    // ✅ INICIAR TIMER PARA RECHAZO AUTOMÁTICO EN 15 SEGUNDOS
    _startAutoRejectTimer();

    // ✅ CERRAR CUALQUIER NOTIFICACIÓN QUE PUEDA HABER QUEDADO ABIERTA
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationHandler._closeCurrentNotifications();
    });
  }

  @override
  void dispose() {
    _autoRejectTimer.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ✅ TIMER PARA RECHAZO AUTOMÁTICO (15 SEGUNDOS)
  void _startAutoRejectTimer() {
    print('⏰ Iniciando timer de rechazo automático (15 segundos)');
    _autoRejectTimer = Timer(const Duration(seconds: 15), () {
      print('⏰ Tiempo agotado - Rechazo automático de compra');
      if (!_showResultAnimation && !_isLoading) {
        _rejectCompra(descripcion: 'Compra cancelada por tiempo de espera agotado');
      }
    });
  }

  // ✅ MÉTODO PARA RECHAZAR COMPRA AL PRESIONAR BACK BUTTON
  Future<void> _rejectOnBackButton() async {
    print('⬅️ Back button presionado - Rechazando compra');

    if (_autoRejectTimer.isActive) {
      _autoRejectTimer.cancel();
      print('⏰ Timer de rechazo automático cancelado por back button');
    }

    try {
      final Map<String, dynamic> requestBody = {
        "token_venta": widget.notificationData['token_venta'] ?? '',
        "descripcion": "Compra cancelada al retroceder de la pantalla",
      };

      print('📤 Rechazando compra por back button...');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/RechazarCompra/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));

      print('📥 Response rechazo por back button - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ Compra rechazada exitosamente por back button');
      } else {
        print('❌ Error al rechazar compra por back button: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ Error en _rejectOnBackButton: $e');
    }
  }

  // ✅ FORMATO DE MONEDA CHILENA CORREGIDO
  String _formatCurrency(String amount) {
    try {
      String cleanAmount = amount.replaceAll(RegExp(r'[^\d]'), '');
      int value = int.tryParse(cleanAmount) ?? 0;

      String amountStr = value.toString();
      String formatted = '';
      int count = 0;

      for (int i = amountStr.length - 1; i >= 0; i--) {
        if (count > 0 && count % 3 == 0) {
          formatted = '.$formatted';
        }
        formatted = amountStr[i] + formatted;
        count++;
      }

      return '\$$formatted';
    } catch (e) {
      return '\$$amount';
    }
  }

  Future<void> _abrirPoliticaCobranza() async {
    final Uri url = Uri.parse('http://orsanevaluaciones.cl/wp-content/uploads/2025/11/Consentimiento-Legal-y-Autorizacion-de-Contacto.pdf');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir la URL: $url');
    }
  }

  // ✅ MÉTODO PARA RECHAZAR COMPRA
  Future<void> _rejectCompra({required String descripcion}) async {
    if (_autoRejectTimer.isActive) {
      _autoRejectTimer.cancel();
      print('⏰ Timer de rechazo automático cancelado');
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 ========== RECHAZANDO COMPRA ==========');

      final Map<String, dynamic> requestBody = {
        "token_venta": widget.notificationData['token_venta'] ?? '',
        "descripcion": descripcion,
      };

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/RechazarCompra/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _apiResponseData = responseData;
        _apiResponseMessage = responseData['mensaje'] ?? descripcion;
        print('✅ Compra rechazada exitosamente');
      } else {
        _apiResponseMessage = 'Error al rechazar compra: ${response.statusCode}';
      }

    } catch (e) {
      print('❌ Error en _rejectCompra: $e');
      _apiResponseMessage = 'Error de conexión: $e';
    } finally {
      setState(() {
        _isLoading = false;
        _isApproved = false;
        _showResultAnimation = true;
      });
      _controller.forward();
    }
  }

  // ✅ MÉTODO PARA CONFIRMAR COMPRA
  Future<void> _confirmAction(BuildContext context) async {
    if (!_aceptoPoliticas) {
      _mostrarErrorPoliticas();
      return;
    }

    if (_autoRejectTimer.isActive) {
      _autoRejectTimer.cancel();
      print('⏰ Timer de rechazo automático cancelado por confirmación');
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 ========== CONFIRMANDO COMPRA ==========');

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

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/GuardarCompra/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _apiResponseData = responseData;

        final bool success = responseData['success'] == true;
        final int estadoVenta = responseData['estado_venta'] ?? 0;
        final String mensaje = responseData['mensaje'] ?? 'Sin mensaje';

        _isApproved = success && estadoVenta == 1;
        _apiResponseMessage = mensaje;

      } else {
        _isApproved = false;
        _apiResponseMessage = 'Error de conexión: ${response.statusCode}';
      }

    } catch (e) {
      print('❌ Error en _confirmAction: $e');
      _isApproved = false;
      _apiResponseMessage = 'Error de conexión: $e';
    } finally {
      setState(() {
        _isLoading = false;
        _showResultAnimation = true;
      });
      _controller.forward();
    }
  }

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

  // ✅ MÉTODO MODIFICADO: NAVEGAR AL DASHBOARD SOLO RECHAZANDO SI NO SE CONFIRMÓ
  void _navigateToDashboard() {
    print('⬅️ Navegando al Dashboard...');

    // ✅ SOLO RECHAZAR LA COMPRA SI NO SE HA CONFIRMADO
    if (!_showResultAnimation || !_isApproved) {
      print('🔄 Rechazando compra antes de navegar (no confirmada)');
      _rejectOnBackButton();
    } else {
      print('✅ Compra confirmada, navegando sin rechazar');
    }

    // ✅ NAVEGAR AL DASHBOARD Y LIMPIAR TODAS LAS RUTAS ANTERIORES
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => DashboardScreen(userData: {})),
          (route) => false,
    );
  }

  // ✅ MÉTODO PARA MANEJAR EL BACK BUTTON DEL DISPOSITIVO (ANDROID/IOS)
  Future<bool> _onWillPop() async {
    print('⬅️ Back button del dispositivo presionado - Rechazando compra');
    await _rejectOnBackButton();
    return true; // Permitir la navegación hacia atrás
  }

  void _onFinalizar() {
    // ✅ SOLO NAVEGAR, NO RECHAZAR SI YA SE CONFIRMÓ
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => DashboardScreen(userData: {})),
          (route) => false,
    );
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
                    _apiResponseMessage.isNotEmpty ? _apiResponseMessage : "Tu compra ha sido confirmada",
                    style: const TextStyle(
                      color: Color(0xFF0A915C),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_apiResponseData['monto_disponible'] != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Monto disponible: ${_formatCurrency(_apiResponseData['monto_disponible'].toString())}',
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
                    _apiResponseMessage.isNotEmpty ? _apiResponseMessage : "Tu compra no ha sido aceptada",
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
    // ✅ USAR WillPopScope PARA MANEJAR EL BACK BUTTON DEL DISPOSITIVO
    return WillPopScope(
      onWillPop: _onWillPop,
      child: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    if (_showResultAnimation) {
      return _isApproved ? _buildApprovedAnimation() : _buildRejectedAnimation();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _blueDarkColor),
          onPressed: _navigateToDashboard,
        ),
        title: Text(
          'Detalle de Compra',
          style: TextStyle(
            color: _blueDarkColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true, // ✅ TÍTULO CENTRADO
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _blueDarkColor.withOpacity(0.1), // ✅ FONDO AZUL CLARO CON OPACIDAD
                      border: Border.all(
                        color: _blueDarkColor, // ✅ BORDE AZUL OSCURO
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.shopping_cart,
                      size: 40,
                      color: _blueDarkColor, // ✅ CAMBIADO A AZUL OSCURO
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.notificationTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _blueDarkColor, // ✅ TÍTULO EN AZUL OSCURO
                    ),
                    textAlign: TextAlign.center, // ✅ TÍTULO CENTRADO
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tienes 15 segundos para responder',
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

            // ✅ UNA SOLA TARJETA QUE CONTIENE TODO
            _buildInfoCard(
              children: [
                // ✅ COMERCIO
                _buildInfoItemConIcono(
                  icon: Icons.store,
                  label: 'Comercio',
                  value: widget.notificationData['comercio'] ?? 'No especificado',
                  color: _blueDarkColor,
                ),
                const SizedBox(height: 16),

                // ✅ MONTO
                _buildInfoItemConIcono(
                  icon: Icons.attach_money,
                  label: 'Monto',
                  value: _formatCurrency(widget.notificationData['monto'] ?? '0'),
                  color: _blueDarkColor,
                ),
                const SizedBox(height: 16),

                // ✅ LÍNEA DIVISORIA
                const Divider(
                  color: Colors.grey,
                  thickness: 1,
                  height: 20,
                ),
                const SizedBox(height: 16),

                // ✅ ACEPTACIÓN DE POLÍTICAS
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _aceptoPoliticas,
                      onChanged: (bool? value) {
                        setState(() {
                          _aceptoPoliticas = value ?? false;
                        });
                      },
                      activeColor: _blueDarkColor,
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
              ],
            ),

            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50, // ✅ MISMA ALTURA PARA AMBOS BOTONES
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _rejectAction(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.red.shade400, width: 2),
                        ),
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
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 50, // ✅ MISMA ALTURA PARA AMBOS BOTONES
                    child: ElevatedButton(
                      onPressed: _aceptoPoliticas && !_isLoading
                          ? () => _confirmAction(context)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _aceptoPoliticas && !_isLoading
                            ? _blueDarkColor // ✅ AZUL OSCURO CUANDO ESTÁ HABILITADO
                            : Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
                          color: Colors.white, // ✅ TEXTO EN BLANCO
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO MÉTODO PARA CONSTRUIR TARJETA CON DISEÑO UNIFORME (COMO EN PROFILE SCREEN)
  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 3,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _approvedCardBackground, // ← FONDO AZUL CLARO (#E8F0FE)
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  // ✅ MÉTODO PARA CONSTRUIR ÍTEMS CON ICONO (COMO EN PROFILE SCREEN)
  Widget _buildInfoItemConIcono({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color, // ← ÍCONO EN AZUL OSCURO
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
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey, // ← SUBTÍTULO EN GRIS
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black, // ← TÍTULO EN NEGRO
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
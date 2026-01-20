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

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _currentSnackBar;
  static ScaffoldFeatureController<MaterialBanner, MaterialBannerClosedReason>? _currentMaterialBanner;
  static OverlayEntry? _notificationOverlay;
  static RemoteMessage? _currentMessage;

  static Timer? _currentNotificationTimer;
  static const Color _blueDarkColor = Color(0xFF0055B8);
  static const Color _approvedCardBackground = Color(0xFFE8F0FE);
  static OverlayEntry? _globalNotificationOverlay;

  // Variable para almacenar token de dispositivo
  static String? _deviceToken;

  static void initializeNotifications() {
    print('🔔 [NotificationHandler] Inicializando notificaciones...');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('\n📱 [NotificationHandler] Notificación recibida en primer plano');
      _logNotificationData(message);
      _currentMessage = message;

      // Llamar a la API AbrirNotificacion y verificar si se debe abrir
      final bool shouldOpen = await _callAbrirNotificacionAPI(message);

      if (shouldOpen) {
        _showForegroundNotification(message);
      } else {
        print('❌ [NotificationHandler] Notificación no debe abrirse (success: false o sesion_iniciada: false)');
        _closeCurrentNotifications();
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      print('\n🚀 [NotificationHandler] Notificación abierta desde segundo plano');
      _logNotificationData(message);
      _currentMessage = message;

      // Llamar a la API AbrirNotificacion y verificar si se debe abrir
      final bool shouldOpen = await _callAbrirNotificacionAPI(message);

      if (shouldOpen) {
        _closeCurrentNotifications();
        _navigateToNotificationDetail(message);
      } else {
        print('❌ [NotificationHandler] Notificación no debe abrirse desde segundo plano (success: false o sesion_iniciada: false)');
        _closeCurrentNotifications();
      }
    });

    _handleTerminatedNotification();
    _requestPermissions();
  }

  // MÉTODO MODIFICADO: Ahora incluye token_comprador y token_dispositivo
  static Future<bool> _callAbrirNotificacionAPI(RemoteMessage message) async {
    print('\n📡 [NotificationHandler] ========== LLAMANDO API ABRIR NOTIFICACIÓN ==========');

    try {
      // Obtener token del dispositivo FCM si no está almacenado
      if (_deviceToken == null) {
        _deviceToken = await _firebaseMessaging.getToken();
        print('📱 [NotificationHandler] Token FCM obtenido: $_deviceToken');
      }

      // Extraer fecha del payload y formatear correctamente
      final fechaRaw = message.data['fecha'] ?? '';
      String fechaFormateada = '';

      if (fechaRaw.isNotEmpty) {
        try {
          // Intentar parsear la fecha ISO (2026-01-09T05:10:29.706477)
          final fechaIso = DateTime.tryParse(fechaRaw);
          if (fechaIso != null) {
            fechaFormateada = '${fechaIso.day.toString().padLeft(2, '0')}-'
                '${fechaIso.month.toString().padLeft(2, '0')}-'
                '${fechaIso.year} '
                '${fechaIso.hour.toString().padLeft(2, '0')}:'
                '${fechaIso.minute.toString().padLeft(2, '0')}:'
                '${fechaIso.second.toString().padLeft(2, '0')}';
            print('✅ [NotificationHandler] Fecha parseada y formateada correctamente');
            print('   • Original: $fechaRaw');
            print('   • Formateada: $fechaFormateada');
          } else {
            print('⚠️ [NotificationHandler] No se pudo parsear la fecha: $fechaRaw');
          }
        } catch (e) {
          print('⚠️ [NotificationHandler] Error parseando fecha: $e');
        }
      } else {
        print('⚠️ [NotificationHandler] No hay fecha en el payload, usando hora actual');
        final now = DateTime.now();
        fechaFormateada = '${now.day.toString().padLeft(2, '0')}-'
            '${now.month.toString().padLeft(2, '0')}-'
            '${now.year} '
            '${now.hour.toString().padLeft(2, '0')}:'
            '${now.minute.toString().padLeft(2, '0')}:'
            '${now.second.toString().padLeft(2, '0')}';
      }

      // Obtener token_comprador del payload
      final tokenComprador = message.data['token_comprador'] ?? '';
      final maximoTiempo = '15';

      print('📊 [NotificationHandler] Datos para API AbrirNotificacion:');
      print('   • fecha_envio_notificacion: $fechaFormateada');
      print('   • maximo_tiempo: $maximoTiempo');
      print('   • token_comprador: $tokenComprador');
      print('   • token_dispositivo: $_deviceToken');

      // Validar que tenemos los datos necesarios
      if (tokenComprador.isEmpty) {
        print('❌ [NotificationHandler] token_comprador está vacío en el payload');
        print('📡 [NotificationHandler] ========== FIN LLAMADA API ==========\n');
        return false;
      }

      if (_deviceToken == null || _deviceToken!.isEmpty) {
        print('❌ [NotificationHandler] No se pudo obtener token_dispositivo');
        print('📡 [NotificationHandler] ========== FIN LLAMADA API ==========\n');
        return false;
      }

      // Preparar el body de la petición con los nuevos parámetros
      final Map<String, dynamic> requestBody = {
        "fecha_envio_notificacion": fechaFormateada,
        "maximo_tiempo": maximoTiempo,
        "token_comprador": tokenComprador,
        "token_dispositivo": _deviceToken!,
      };

      print('📤 [NotificationHandler] Enviando petición a API:');
      print('   • URL: ${GlobalVariables.baseUrl}/AbrirNotificacion/api/v1/');
      print('   • Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/AbrirNotificacion/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));

      print('📥 [NotificationHandler] RESPUESTA API ABRIR NOTIFICACIÓN:');
      print('   • Status Code: ${response.statusCode}');
      print('   • Body: ${response.body}');

      if (response.statusCode == 200) {
        print('✅ [NotificationHandler] API AbrirNotificacion llamada exitosamente');

        try {
          final responseData = json.decode(response.body);
          print('📊 [NotificationHandler] Respuesta JSON parseada:');
          responseData.forEach((key, value) {
            print('   • $key: $value (tipo: ${value.runtimeType})');
          });

          // VERIFICAR SI SE DEBE ABRIR LA NOTIFICACIÓN - NUEVA LÓGICA
          final bool success = responseData['success'] == true;
          final bool sesionIniciada = responseData['sesion_iniciada'] == true;
          final bool abrirNotificacion = responseData['abrir_notificacion'] == true;

          print('🔍 [NotificationHandler] Validaciones:');
          print('json: $responseData');
          print('   • success: $success');
          print('   • sesion_iniciada: $sesionIniciada');
          print('   • abrir_notificacion: $abrirNotificacion');

          // NUEVA VALIDACIÓN: No abrir si success es false O sesion_iniciada es false
          if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
            print('❌ [NotificationHandler] No se debe abrir notificación porque:');
            if (!success) print('   • success es false');
            if (!sesionIniciada) print('   • sesion_iniciada es false');
            print('📡 [NotificationHandler] ========== FIN LLAMADA API ==========\n');
            return false;
          }

          // Si pasa las validaciones anteriores, usar abrir_notificacion
          print('🔍 [NotificationHandler] ¿Debe abrirse la notificación? $abrirNotificacion');

          if (responseData.containsKey('diferencia_segundos')) {
            final diferenciaSegundos = responseData['diferencia_segundos'];
            final maximoSegundos = responseData['maximo_segundos'] ?? 15.0;
            print('⏰ [NotificationHandler] Tiempo transcurrido: $diferenciaSegundos segundos');
            print('⏰ [NotificationHandler] Máximo permitido: $maximoSegundos segundos');

            if (diferenciaSegundos is num && maximoSegundos is num) {
              final tiempoRestante = maximoSegundos - diferenciaSegundos;
              if (tiempoRestante > 0) {
                print('⏰ [NotificationHandler] Tiempo restante: $tiempoRestante segundos');
              } else {
                print('⏰ [NotificationHandler] Tiempo agotado');
              }
            }
          }

          // Verificar auditoria
          if (responseData.containsKey('auditoria')) {
            final auditoria = responseData['auditoria'];
            final codigoError = auditoria['codigo_error']?.toString() ?? '';
            final glosaError = auditoria['glosa_error']?.toString() ?? '';
            print('📋 [NotificationHandler] Auditoria:');
            print('   • Código error: $codigoError');
            print('   • Glosa error: $glosaError');
          }

          // RETORNAR SI SE DEBE ABRIR O NO
          print('📡 [NotificationHandler] ========== FIN LLAMADA API ==========\n');
          return abrirNotificacion;

        } catch (e) {
          print('⚠️ [NotificationHandler] Error parseando respuesta JSON: $e');
          print('   • Body crudo: ${response.body}');
          // Por defecto, si hay error en el parseo, no abrimos
          print('📡 [NotificationHandler] ========== FIN LLAMADA API ==========\n');
          return false;
        }
      } else {
        print('❌ [NotificationHandler] Error en API AbrirNotificacion: ${response.statusCode}');
        print('   • Error body: ${response.body}');
        // Por defecto, si hay error HTTP, no abrimos
        print('📡 [NotificationHandler] ========== FIN LLAMADA API ==========\n');
        return false;
      }

    } catch (e) {
      print('❌ [NotificationHandler] Error llamando API AbrirNotificacion: $e');
      print('   • Error type: ${e.runtimeType}');
      // Por defecto, si hay excepción, no abrimos
      print('📡 [NotificationHandler] ========== FIN LLAMADA API ==========\n');
      return false;
    }
  }

  static void _logNotificationData(RemoteMessage message) {
    print('📋 Datos completos de la notificación:');
    print('   • Título: ${message.notification?.title}');
    print('   • Cuerpo: ${message.notification?.body}');
    print('   • Datos (payload):');
    message.data.forEach((key, value) {
      print('     - $key: $value (tipo: ${value.runtimeType})');
    });
    print('   • Estructura JSON: ${json.encode(message.data)}');
  }

  static void _closeCurrentNotifications() {
    if (_currentNotificationTimer != null && _currentNotificationTimer!.isActive) {
      _currentNotificationTimer!.cancel();
      _currentNotificationTimer = null;
      print('⏰ [NotificationHandler] Timer cancelado');
    }

    if (_currentMaterialBanner != null) {
      try {
        _currentMaterialBanner!.close();
        _currentMaterialBanner = null;
      } catch (e) {}
    }

    if (_currentSnackBar != null) {
      try {
        _currentSnackBar!.close();
        _currentSnackBar = null;
      } catch (e) {}
    }

    if (_notificationOverlay != null) {
      try {
        _notificationOverlay!.remove();
        _notificationOverlay = null;
      } catch (e) {}
    }

    if (_globalNotificationOverlay != null) {
      try {
        _globalNotificationOverlay!.remove();
        _globalNotificationOverlay = null;
      } catch (e) {}
    }

    _currentMessage = null;
  }

  static Future<void> _rejectCurrentCompra() async {
    if (_currentMessage == null) {
      print('❌ [NotificationHandler] No hay mensaje actual para rechazar');
      return;
    }

    final tokenVenta = _currentMessage!.data['token_venta'];
    if (tokenVenta == null) {
      print('❌ [NotificationHandler] No hay token_venta en el mensaje');
      return;
    }

    print('🔄 [NotificationHandler] Rechazando compra al cerrar notificación');
    print('   • Token venta: $tokenVenta');

    try {
      final Map<String, dynamic> requestBody = {
        "token_venta": tokenVenta,
        "descripcion": "Compra cancelada al cerrar la notificación",
      };

      print('📤 [NotificationHandler] Enviando rechazo: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/RechazarCompra/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));

      print('📥 [NotificationHandler] Respuesta rechazo - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ [NotificationHandler] Compra rechazada exitosamente');
      } else {
        print('❌ [NotificationHandler] Error al rechazar: ${response.statusCode}');
        print('   • Body: ${response.body}');
      }

    } catch (e) {
      print('❌ [NotificationHandler] Error en _rejectCurrentCompra: $e');
    }
  }

  static Future<void> _requestPermissions() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      print('📋 [NotificationHandler] Permisos: ${settings.authorizationStatus}');

      // Obtener y almacenar token FCM al solicitar permisos
      _deviceToken = await _firebaseMessaging.getToken();
      print('🔑 [NotificationHandler] Token FCM almacenado: $_deviceToken');

    } catch (e) {
      print('❌ [NotificationHandler] Error solicitando permisos: $e');
    }
  }

  static void _showForegroundNotification(RemoteMessage message) {
    print('\n🎬 [NotificationHandler] Mostrando notificación en primer plano...');

    if (navigatorKey.currentContext != null) {
      print('✅ [NotificationHandler] Contexto disponible');

      _closeCurrentNotifications();
      _currentMessage = message;
      _forceCloseModals();
      _showDirectOverlayNotification(message);

    } else {
      print('❌ [NotificationHandler] No hay contexto disponible, navegando directamente');
      _navigateToNotificationDetail(message);
    }
  }

  static void _forceCloseModals() {
    if (navigatorKey.currentContext != null) {
      try {
        Navigator.of(navigatorKey.currentContext!, rootNavigator: true).popUntil((route) => route.isFirst);
        print('✅ [NotificationHandler] Modales cerrados');
      } catch (e) {
        print('⚠️ [NotificationHandler] Error cerrando modales: $e');
      }
    }
  }

  static void _showDirectOverlayNotification(RemoteMessage message) {
    print('🎬 [NotificationHandler] Mostrando overlay directo...');

    // Intentar con un delay para asegurar que el contexto esté listo
    Future.delayed(const Duration(milliseconds: 100), () {
      if (navigatorKey.currentContext != null) {
        try {
          // Obtener el overlay state del contexto de navegación
          final overlayState = Navigator.of(navigatorKey.currentContext!).overlay;

          if (overlayState == null) {
            print('❌ [NotificationHandler] No se pudo obtener overlayState');
            _showSimpleNotification(message);
            return;
          }

          _globalNotificationOverlay = OverlayEntry(
            builder: (context) => Positioned(
              top: MediaQuery.of(context).viewPadding.top + 10,
              left: 10,
              right: 10,
              child: Material(
                color: Colors.transparent,
                elevation: 1000,
                child: _DirectNotificationWidget(
                  message: message,
                  onTap: () {
                    print('👆 [NotificationHandler] Notificación presionada');
                    _closeCurrentNotifications();
                    _navigateToNotificationDetail(message);
                  },
                  onClose: () {
                    print('❌ [NotificationHandler] Botón X presionado');
                    _rejectCurrentCompra();
                    _closeCurrentNotifications();
                  },
                ),
              ),
            ),
          );

          overlayState.insert(_globalNotificationOverlay!);
          print('✅ [NotificationHandler] Overlay mostrado exitosamente');
          _startNotificationTimer();

        } catch (e) {
          print('❌ [NotificationHandler] Error mostrando overlay: $e');
          _showSimpleNotification(message);
        }
      } else {
        print('❌ [NotificationHandler] No hay contexto para mostrar overlay');
        _showSimpleNotification(message);
      }
    });
  }

  static void _showSimpleNotification(RemoteMessage message) {
    print('🎬 [NotificationHandler] Mostrando notificación simple...');

    // Crear un modal simple que se parezca a la notificación
    if (navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.3),
        builder: (context) {
          return _NotificationDialog(
            message: message,
            onTap: () {
              Navigator.of(context).pop();
              _closeCurrentNotifications();
              _navigateToNotificationDetail(message);
            },
            onClose: () {
              Navigator.of(context).pop();
              _rejectCurrentCompra();
              _closeCurrentNotifications();
            },
          );
        },
      );

      _startNotificationTimer();
    } else {
      _navigateToNotificationDetail(message);
    }
  }

  static Widget _DirectNotificationWidget({
    required RemoteMessage message,
    required VoidCallback onTap,
    required VoidCallback onClose,
  }) {
    final comercio = message.data['comercio'] ?? 'Comercio';
    final monto = message.data['monto'] ?? '0';
    final empresa = message.data['nombre_empresa'] ?? 'Empresa';

    final montoFormateado = _formatCurrency(monto);
    final titulo = message.notification?.title ?? 'NUEVA COMPRA';
    final cuerpo = 'Compra de $empresa en $comercio por $montoFormateado';

    print('📝 [DirectNotificationWidget] Construyendo widget:');
    print('   • Empresa: $empresa');
    print('   • Comercio: $comercio');
    print('   • Monto original: $monto');
    print('   • Monto formateado: $montoFormateado');
    print('   • Texto final: $cuerpo');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 25,
              spreadRadius: 3,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: _blueDarkColor.withOpacity(0.15),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _blueDarkColor.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _blueDarkColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.shopping_cart_checkout,
                color: _blueDarkColor,
                size: 22,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _blueDarkColor,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  Text(
                    cuerpo,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade800,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.red.shade300,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.15),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: Colors.red.shade700,
                ),
                onPressed: onClose,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCurrency(String amount) {
    try {
      String cleanAmount = amount.replaceAll(RegExp(r'[^\d]'), '');
      int value = int.tryParse(cleanAmount) ?? 0;

      if (value == 0) return '\$0';

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
      print('⚠️ [NotificationHandler] Error formateando moneda "$amount": $e');
      return '\$$amount';
    }
  }

  static void _startNotificationTimer() {
    const totalSeconds = 10;
    int elapsedSeconds = 0;

    if (_currentNotificationTimer != null && _currentNotificationTimer!.isActive) {
      _currentNotificationTimer!.cancel();
    }

    print('⏰ [NotificationHandler] Iniciando timer de 10 segundos');

    _currentNotificationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsedSeconds++;

      if (elapsedSeconds >= totalSeconds) {
        print('⏰ [NotificationHandler] Tiempo agotado - Rechazo automático');
        _rejectCurrentCompra();
        _closeCurrentNotifications();
        timer.cancel();
      }
    });
  }

  static void _navigateToNotificationDetail(RemoteMessage message) {
    print('🧭 [NotificationHandler] Navegando a detalle...');

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
        print('✅ [NotificationHandler] Navegación exitosa');
      } catch (e) {
        print('❌ [NotificationHandler] Error en navegación: $e');
      }
    } else {
      print('❌ [NotificationHandler] navigatorKey.currentState es null');
    }
  }

  static Future<void> _handleTerminatedNotification() async {
    print('🔍 [NotificationHandler] Verificando notificaciones de app terminada...');

    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('🔓 [NotificationHandler] App abierta desde notificación (estado terminado)');
      _logNotificationData(initialMessage);

      // Verificar si se debe abrir la notificación
      final bool shouldOpen = await _callAbrirNotificacionAPI(initialMessage);

      if (shouldOpen) {
        await Future.delayed(const Duration(milliseconds: 2000));
        _navigateToNotificationDetail(initialMessage);
      } else {
        print('❌ [NotificationHandler] Notificación de app terminada no debe abrirse (success: false o sesion_iniciada: false)');
      }
    } else {
      print('📭 [NotificationHandler] No hay notificaciones de app terminada');
    }
  }
}

class _NotificationDialog extends StatefulWidget {
  final RemoteMessage message;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _NotificationDialog({
    required this.message,
    required this.onTap,
    required this.onClose,
  });

  @override
  State<_NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<_NotificationDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;
  int _elapsedSeconds = 0;
  final int _totalSeconds = 10;
  final Color _blueDarkColor = const Color(0xFF0055B8);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );
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
        widget.onClose();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _formatCurrency(String amount) {
    try {
      String cleanAmount = amount.replaceAll(RegExp(r'[^\d]'), '');
      int value = int.tryParse(cleanAmount) ?? 0;
      if (value == 0) return '\$0';
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

  @override
  Widget build(BuildContext context) {
    final comercio = widget.message.data['comercio'] ?? 'Comercio';
    final monto = widget.message.data['monto'] ?? '0';
    final empresa = widget.message.data['nombre_empresa'] ?? 'Empresa';
    final montoFormateado = _formatCurrency(monto);
    final cuerpo = 'Compra de $empresa en $comercio por $montoFormateado';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 25,
                spreadRadius: 3,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: _blueDarkColor.withOpacity(0.15),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _blueDarkColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _blueDarkColor.withOpacity(0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.shopping_cart_checkout,
                  color: _blueDarkColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message.notification?.title ?? 'NUEVA COMPRA',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _blueDarkColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                    Text(
                      cuerpo,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.red.shade300,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.15),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.red.shade700,
                  ),
                  onPressed: widget.onClose,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
  Timer? _timer;
  int _elapsedSeconds = 0;
  final int _totalSeconds = 10;
  final Color _blueDarkColor = const Color(0xFF0055B8);

  @override
  void initState() {
    super.initState();
    print('🔄 [_NotificationOverlayContent] initState');

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );

    _controller.forward();
    _startTimer();
  }

  void _startTimer() {
    print('⏰ [_NotificationOverlayContent] Iniciando timer');
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });

      if (_elapsedSeconds >= _totalSeconds) {
        print('⏰ [_NotificationOverlayContent] Timer completado');
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    print('🗑️ [_NotificationOverlayContent] dispose');
    super.dispose();
  }

  String _formatCurrency(String amount) {
    try {
      String cleanAmount = amount.replaceAll(RegExp(r'[^\d]'), '');
      int value = int.tryParse(cleanAmount) ?? 0;

      if (value == 0) return '\$0';

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

  @override
  Widget build(BuildContext context) {
    final comercio = widget.message.data['comercio'] ?? 'Comercio';
    final monto = widget.message.data['monto'] ?? '0';
    final empresa = widget.message.data['nombre_empresa'] ?? 'Empresa';
    final montoFormateado = _formatCurrency(monto);
    final cuerpo = 'Compra de $empresa en $comercio por $montoFormateado';

    print('🎨 [_NotificationOverlayContent] Construyendo widget con:');
    print('   • Empresa: $empresa');
    print('   • Comercio: $comercio');
    print('   • Monto: $montoFormateado');

    return Positioned(
      top: MediaQuery.of(context).viewPadding.top + 10,
      left: 10,
      right: 10,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 25,
                  spreadRadius: 3,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: _blueDarkColor.withOpacity(0.15),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _blueDarkColor.withOpacity(0.08),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _blueDarkColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.shopping_cart_checkout,
                    color: _blueDarkColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message.notification?.title ?? 'NUEVA COMPRA',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: _blueDarkColor,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        cuerpo,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade800,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.red.shade300,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.15),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.red.shade700,
                    ),
                    onPressed: widget.onClose,
                    padding: EdgeInsets.zero,
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

  final Color _blueDarkColor = const Color(0xFF0055B8);
  final Color _approvedCardBackground = const Color(0xFFE8F0FE);

  @override
  void initState() {
    super.initState();
    print('\n📱 [NotificationDetailScreen] initState');
    print('📋 Datos recibidos en pantalla:');
    widget.notificationData.forEach((key, value) {
      print('   • $key: $value (tipo: ${value.runtimeType})');
    });

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

    _startAutoRejectTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationHandler._closeCurrentNotifications();
    });
  }

  @override
  void dispose() {
    _autoRejectTimer.cancel();
    _controller.dispose();
    print('🗑️ [NotificationDetailScreen] dispose');
    super.dispose();
  }

  void _startAutoRejectTimer() {
    print('⏰ [NotificationDetailScreen] Timer de 15 segundos iniciado');
    _autoRejectTimer = Timer(const Duration(seconds: 15), () {
      print('⏰ [NotificationDetailScreen] Tiempo agotado - Rechazo automático');
      if (!_showResultAnimation && !_isLoading) {
        _rejectCompra(descripcion: 'Compra cancelada por tiempo de espera agotado');
      }
    });
  }

  Future<void> _rejectOnBackButton() async {
    print('⬅️ [NotificationDetailScreen] Back button presionado');

    if (_autoRejectTimer.isActive) {
      _autoRejectTimer.cancel();
      print('⏰ [NotificationDetailScreen] Timer cancelado por back button');
    }

    try {
      final tokenVenta = widget.notificationData['token_venta'] ?? '';
      final Map<String, dynamic> requestBody = {
        "token_venta": tokenVenta,
        "descripcion": "Compra cancelada al retroceder de la pantalla",
      };

      print('📤 [NotificationDetailScreen] Enviando rechazo por back button:');
      print('   • Token venta: $tokenVenta');
      print('   • Request: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/RechazarCompra/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 10));

      print('📥 [NotificationDetailScreen] Respuesta rechazo - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ [NotificationDetailScreen] Compra rechazada por back button');
      } else {
        print('❌ [NotificationDetailScreen] Error en rechazo: ${response.statusCode}');
        print('   • Body: ${response.body}');
      }

    } catch (e) {
      print('❌ [NotificationDetailScreen] Error en _rejectOnBackButton: $e');
    }
  }

  String _formatCurrency(String amount) {
    try {
      String cleanAmount = amount.replaceAll(RegExp(r'[^\d]'), '');
      int value = int.tryParse(cleanAmount) ?? 0;

      if (value == 0) return '\$0';

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
      print('⚠️ [NotificationDetailScreen] Error formateando "$amount": $e');
      return '\$$amount';
    }
  }

  Future<void> _abrirPoliticaCobranza() async {
    print('🌐 [NotificationDetailScreen] Abriendo política de cobranza');
    final Uri url = Uri.parse('http://orsanevaluaciones.cl/wp-content/uploads/2025/11/Consentimiento-Legal-y-Autorizacion-de-Contacto.pdf');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir la URL: $url');
    }
  }

  Future<void> _rejectCompra({required String descripcion}) async {
    print('\n🔄 [NotificationDetailScreen] ========== RECHAZANDO COMPRA ==========');

    if (_autoRejectTimer.isActive) {
      _autoRejectTimer.cancel();
      print('⏰ [NotificationDetailScreen] Timer cancelado');
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final tokenVenta = widget.notificationData['token_venta'] ?? '';
      final Map<String, dynamic> requestBody = {
        "token_venta": tokenVenta,
        "descripcion": descripcion,
      };

      print('📤 [NotificationDetailScreen] Enviando rechazo:');
      print('   • Token venta: $tokenVenta');
      print('   • Descripción: $descripcion');
      print('   • URL: ${GlobalVariables.baseUrl}/RechazarCompra/api/v1/');
      print('   • Request: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/RechazarCompra/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📥 [NotificationDetailScreen] Respuesta recibida:');
      print('   • Status: ${response.statusCode}');
      print('   • Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _apiResponseData = responseData;
        _apiResponseMessage = responseData['mensaje'] ?? descripcion;
        print('✅ [NotificationDetailScreen] Compra rechazada exitosamente');
      } else {
        _apiResponseMessage = 'Error al rechazar compra: ${response.statusCode}';
        print('❌ [NotificationDetailScreen] Error en respuesta: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ [NotificationDetailScreen] Error en _rejectCompra: $e');
      _apiResponseMessage = 'Error de conexión: $e';
    } finally {
      setState(() {
        _isLoading = false;
        _isApproved = false;
        _showResultAnimation = true;
      });
      _controller.forward();
      print('🎬 [NotificationDetailScreen] Mostrando animación de rechazo');
    }
  }

  Future<void> _confirmAction(BuildContext context) async {
    print('\n🔄 [NotificationDetailScreen] ========== CONFIRMANDO COMPRA ==========');

    if (!_aceptoPoliticas) {
      print('❌ [NotificationDetailScreen] Políticas no aceptadas');
      _mostrarErrorPoliticas();
      return;
    }

    if (_autoRejectTimer.isActive) {
      _autoRejectTimer.cancel();
      print('⏰ [NotificationDetailScreen] Timer cancelado por confirmación');
    }

    setState(() {
      _isLoading = true;
    });

    try {
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

      print('📤 [NotificationDetailScreen] Enviando confirmación:');
      print('   • URL: ${GlobalVariables.baseUrl}/GuardarCompra/api/v1/');
      print('   • Request body:');
      requestBody.forEach((key, value) {
        print('     - $key: $value');
      });

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/GuardarCompra/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('📥 [NotificationDetailScreen] Respuesta recibida:');
      print('   • Status: ${response.statusCode}');
      print('   • Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _apiResponseData = responseData;

        print('📊 [NotificationDetailScreen] Datos de respuesta:');
        responseData.forEach((key, value) {
          print('   • $key: $value');
        });

        final bool success = responseData['success'] == true;
        final int estadoVenta = responseData['estado_venta'] ?? 0;
        final String mensaje = responseData['mensaje'] ?? 'Sin mensaje';

        _isApproved = success && estadoVenta == 1;
        _apiResponseMessage = mensaje;

        print('✅ [NotificationDetailScreen] Confirmación procesada:');
        print('   • Success: $success');
        print('   • Estado venta: $estadoVenta');
        print('   • Aprobado: $_isApproved');
        print('   • Mensaje: $_apiResponseMessage');

      } else {
        _isApproved = false;
        _apiResponseMessage = 'Error de conexión: ${response.statusCode}';
        print('❌ [NotificationDetailScreen] Error en respuesta: ${response.statusCode}');
      }

    } catch (e) {
      print('❌ [NotificationHandler] Error en _confirmAction: $e');
      _isApproved = false;
      _apiResponseMessage = 'Error de conexión: $e';
    } finally {
      setState(() {
        _isLoading = false;
        _showResultAnimation = true;
      });
      _controller.forward();
      print('🎬 [NotificationDetailScreen] Mostrando animación de resultado');
    }
  }

  void _rejectAction(BuildContext context) {
    print('❌ [NotificationDetailScreen] COMPRA RECHAZADA MANUALMENTE');
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

  void _navigateToDashboard() {
    print('🧭 [NotificationDetailScreen] Navegando al Dashboard...');

    if (!_showResultAnimation || !_isApproved) {
      print('🔄 [NotificationDetailScreen] Rechazando compra antes de navegar');
      _rejectOnBackButton();
    } else {
      print('✅ [NotificationDetailScreen] Compra confirmada, navegando sin rechazar');
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => DashboardScreen(userData: {})),
          (route) => false,
    );
  }

  Future<bool> _onWillPop() async {
    print('⬅️ [NotificationDetailScreen] Back button del dispositivo');
    await _rejectOnBackButton();
    return true;
  }

  void _onFinalizar() {
    print('🏁 [NotificationDetailScreen] Finalizando proceso');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => DashboardScreen(userData: {})),
          (route) => false,
    );
  }

  Widget _buildApprovedAnimation() {
    print('✅ [NotificationDetailScreen] Construyendo animación de aprobación');

    final montoCompraStr = widget.notificationData['monto'] ?? '0';
    final montoCompra = int.tryParse(montoCompraStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

    final montoDisponibleActualStr = _apiResponseData['monto_disponible']?.toString() ?? '0';
    final montoDisponibleActual = int.tryParse(montoDisponibleActualStr.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;

    final montoDisponibleFinal = (montoDisponibleActual - montoCompra).clamp(0, double.infinity);

    final montoDisponibleFormateado = _formatCurrency(montoDisponibleFinal.toString());

    print('💰 [NotificationDetailScreen] Cálculos de montos:');
    print('   • Monto compra: $montoCompra');
    print('   • Monto disponible actual: $montoDisponibleActual');
    print('   • Monto disponible final: $montoDisponibleFinal');
    print('   • Monto a mostrar: $montoDisponibleFormateado');

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
                        : "¡Compra confirmada exitosamente!",
                    style: const TextStyle(
                      color: Color(0xFF0A915C),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Monto disponible: $montoDisponibleFormateado',
                    style: const TextStyle(
                      color: Color(0xFF0A915C),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),

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

  Widget _buildRejectedAnimation() {
    print('❌ [NotificationDetailScreen] Construyendo animación de rechazo');
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
    print('🏗️ [NotificationDetailScreen] build()');
    return WillPopScope(
      onWillPop: _onWillPop,
      child: _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    if (_showResultAnimation) {
      return _isApproved ? _buildApprovedAnimation() : _buildRejectedAnimation();
    }

    final empresa = widget.notificationData['nombre_empresa'] ?? 'No especificada';

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
        centerTitle: true,
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
                      color: _blueDarkColor.withOpacity(0.1),
                      border: Border.all(
                        color: _blueDarkColor,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.shopping_cart,
                      size: 40,
                      color: _blueDarkColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.notificationTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _blueDarkColor,
                    ),
                    textAlign: TextAlign.center,
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

            _buildInfoCard(
              children: [
                _buildInfoItemConIcono(
                  icon: Icons.business,
                  label: 'Empresa',
                  value: empresa,
                  color: _blueDarkColor,
                ),
                const SizedBox(height: 16),

                _buildInfoItemConIcono(
                  icon: Icons.store,
                  label: 'Comercio',
                  value: widget.notificationData['comercio'] ?? 'No especificado',
                  color: _blueDarkColor,
                ),
                const SizedBox(height: 16),

                _buildInfoItemConIcono(
                  icon: Icons.attach_money,
                  label: 'Monto',
                  value: _formatCurrency(widget.notificationData['monto'] ?? '0'),
                  color: _blueDarkColor,
                ),
                const SizedBox(height: 16),

                const Divider(
                  color: Colors.grey,
                  thickness: 1,
                  height: 20,
                ),
                const SizedBox(height: 16),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _aceptoPoliticas,
                      onChanged: (bool? value) {
                        print('✓ [NotificationDetailScreen] Checkbox cambiado: $value');
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
                    height: 50,
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
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _aceptoPoliticas && !_isLoading
                          ? () => _confirmAction(context)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _aceptoPoliticas && !_isLoading
                            ? _blueDarkColor
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
                          color: Colors.white,
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
            color: _approvedCardBackground,
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
            color: color,
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
                  color: Colors.grey,
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
    );
  }
}
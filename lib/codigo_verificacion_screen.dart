import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'variables_globales.dart';

// ✅ COLOR AZUL OSCURO DEFINIDO GLOBALMENTE
final Color _blueDarkColor = const Color(0xFF0055B8);

class CodigoVerificacionScreen extends StatefulWidget {
  final String tokenComprador;
  final String email;
  final bool esReenvio;

  const CodigoVerificacionScreen({
    super.key,
    required this.tokenComprador,
    required this.email,
    this.esReenvio = false,
  });

  @override
  State<CodigoVerificacionScreen> createState() => _CodigoVerificacionScreenState();
}

class _CodigoVerificacionScreenState extends State<CodigoVerificacionScreen> {
  final TextEditingController _codigoController = TextEditingController();
  final TextEditingController _nuevaPasswordController = TextEditingController();
  final TextEditingController _confirmarPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _codigoEnviado = false;
  bool _mostrarContrasena = false;
  bool _mostrarConfirmarContrasena = false;
  DateTime? _horaEnvioCodigo;
  int _intentosFallidos = 0;
  int _intentosRestantes = 3;
  String? _deviceToken;

  // ✅ TIMER PARA ACTUALIZAR EL CONTADOR
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // ✅ OBTENER TOKEN DEL DISPOSITIVO (FCM)
    _initializeDeviceToken();

    // ✅ Si es reenvío desde perfil, marcar como código ya enviado
    if (widget.esReenvio) {
      _codigoEnviado = true;
      _horaEnvioCodigo = DateTime.now();
      _iniciarTimer();
    }

    // ✅ Escuchar cambios en los campos de texto
    _codigoController.addListener(_actualizarEstadoBoton);
    _nuevaPasswordController.addListener(() {
      _actualizarEstadoBoton();
      setState(() {}); // Para actualizar el indicador en tiempo real
    });
    _confirmarPasswordController.addListener(_actualizarEstadoBoton);
  }

  // ✅ OBTENER TOKEN DEL DISPOSITIVO (FCM)
  Future<void> _initializeDeviceToken() async {
    try {
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        print('✅ Token FCM obtenido para recuperación de contraseña: $fcmToken');
        setState(() {
          _deviceToken = fcmToken;
        });
      } else {
        print('⚠️ No se pudo obtener token FCM, usando fallback');
        final String fallbackToken = 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
        setState(() {
          _deviceToken = fallbackToken;
        });
      }
    } catch (e) {
      print('❌ Error obteniendo token FCM: $e');
      final String errorToken = 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _deviceToken = errorToken;
      });
    }
  }

  // ✅ VALIDACIÓN DE CONTRASEÑA SEGURA
  bool _esContrasenaSegura(String contrasena) {
    if (contrasena.length < 8) return false;

    // Al menos una mayúscula
    if (!RegExp(r'[A-Z]').hasMatch(contrasena)) return false;

    // Al menos un número
    if (!RegExp(r'[0-9]').hasMatch(contrasena)) return false;

    // Al menos un símbolo especial
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(contrasena)) return false;

    return true;
  }

  // ✅ OBTENER MENSAJES DE ERROR DE VALIDACIÓN
  String? _validarContrasena(String contrasena) {
    if (contrasena.isEmpty) return 'La contraseña es obligatoria';
    if (contrasena.length < 8) return 'Mínimo 8 caracteres';
    if (!RegExp(r'[A-Z]').hasMatch(contrasena)) return 'Al menos una mayúscula';
    if (!RegExp(r'[0-9]').hasMatch(contrasena)) return 'Al menos un número';
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(contrasena)) {
      return 'Al menos un símbolo (!@#\$%^&*)';
    }
    return null;
  }

  @override
  void dispose() {
    // ✅ CANCELAR TIMER AL SALIR
    _timer?.cancel();
    // ✅ Limpiar listeners
    _codigoController.removeListener(_actualizarEstadoBoton);
    _nuevaPasswordController.removeListener(() {
      _actualizarEstadoBoton();
      setState(() {});
    });
    _confirmarPasswordController.removeListener(_actualizarEstadoBoton);
    super.dispose();
  }

  // ✅ VERIFICAR SI LA SESIÓN HA EXPIRADO Y REINICIAR APP
  void _verificarSesionExpirada(Map<String, dynamic> responseData) {
    if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
      print('⚠️ Sesión expirada detectada en CodigoVerificacionScreen');

      // Mostrar mensaje de sesión cerrada
      _mostrarError('Sesión cerrada. Por favor, inicia sesión nuevamente.');

      // ✅ REINICIAR LA APLICACIÓN INSTANTÁNEAMENTE
      _reiniciarAplicacion();
    }
  }

  // ✅ REINICIAR LA APLICACIÓN NAVEGANDO AL MAIN
  void _reiniciarAplicacion() {
    print('🔄 Reiniciando aplicación desde CodigoVerificacionScreen...');

    // Navegar a la pantalla de splash/main reiniciando toda la pila
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/', // Usar la ruta raíz
          (route) => false, // Eliminar todas las rutas anteriores
    );

    // Si usas MaterialApp con home: UpdateCheckScreen(), esto navegará al inicio
    // También puedes forzar un hot reload del widget raíz
    if (Navigator.canPop(context)) {
      Navigator.popUntil(context, (route) => route.isFirst);
    }
  }

  // ✅ Función para actualizar el estado del botón basado en los campos
  void _actualizarEstadoBoton() {
    setState(() {});
  }

  // ✅ Verificar si el botón debe estar habilitado
  bool get _botonHabilitado {
    final codigo = _codigoController.text.trim();
    final nuevaPassword = _nuevaPasswordController.text.trim();
    final confirmarPassword = _confirmarPasswordController.text.trim();

    // ✅ Condiciones para habilitar el botón:
    // 1. Código tiene 8 caracteres
    // 2. Ambos campos de contraseña están llenos
    // 3. Las contraseñas son iguales
    // 4. La contraseña cumple con los requisitos de seguridad
    return codigo.length == 8 &&
        nuevaPassword.isNotEmpty &&
        confirmarPassword.isNotEmpty &&
        nuevaPassword == confirmarPassword &&
        _esContrasenaSegura(nuevaPassword) &&
        !_isLoading; // También verificar que no esté cargando
  }

  // ✅ INICIAR TIMER PARA ACTUALIZAR CONTADOR CADA SEGUNDO
  void _iniciarTimer() {
    _timer?.cancel(); // Cancelar timer anterior si existe

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _horaEnvioCodigo != null) {
        final segundosRestantes = _getSegundosRestantes();

        if (segundosRestantes <= 0) {
          // Código expirado, detener timer y volver al estado inicial
          timer.cancel();
          if (mounted) {
            setState(() {
              _codigoEnviado = false;
              _horaEnvioCodigo = null;
              _codigoController.clear();
              _nuevaPasswordController.clear();
              _confirmarPasswordController.clear();
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

  // ✅ ENVIAR CÓDIGO (API v2 CON TOKEN DE DISPOSITIVO)
  Future<void> _enviarCodigo() async {
    print('🔄 Enviando código...');

    // Verificar que tenemos token del dispositivo
    if (_deviceToken == null) {
      _mostrarError('No se pudo obtener el token del dispositivo. Intenta nuevamente.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final requestBody = {
        "token_comprador": widget.tokenComprador,
        "mail": widget.email,
        "token_dispositivo": _deviceToken!, // ✅ NUEVO CAMPO REQUERIDO EN v2
      };

      print('📤 Request CorreoCodigoCambioPassword (v1):');
      print('🌐 URL: ${GlobalVariables.baseUrl}/CorreoCodigoCambioPassword/api/v1/'); // ✅ CAMBIADO A v2
      print('📋 Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CorreoCodigoCambioPassword/api/v1/'), // ✅ CAMBIADO A v2
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response CorreoCodigoCambioPassword (v1):');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // ✅ VERIFICAR SI LA SESIÓN HA EXPIRADO - SOLO 1 SNACKBAR
        if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
          _mostrarError('Sesión cerrada. Por favor, inicia sesión nuevamente.');

          // ✅ REINICIAR LA APLICACIÓN INSTANTÁNEAMENTE
          _reiniciarAplicacion();

          return; // ⬅️ IMPORTANTE: Salir del método para no mostrar otro SnackBar
        }

        if (responseData['success'] == true) {
          setState(() {
            _codigoEnviado = true;
            _horaEnvioCodigo = DateTime.now();
            _intentosFallidos = 0;
            _intentosRestantes = 3;
          });

          _mostrarExito('Código enviado exitosamente');

          // ✅ INICIAR TIMER DESPUÉS DE ENVIAR CÓDIGO
          _iniciarTimer();
        } else {
          final mensajeError = responseData['message'] ?? 'Error desconocido';

          // Manejo de errores específicos según la API
          if (responseData['codigo_error'] == 'TOKEN_DISPOSITIVO_INVALIDO') {
            _mostrarError('Error de dispositivo. Por favor, reinicia la aplicación.');
          } else {
            _mostrarError('Error: $mensajeError');
          }
        }
      } else if (response.statusCode == 401) {
        // ✅ SESIÓN EXPIRADA POR STATUS 401 - SOLO 1 SNACKBAR
        print('🔐 Sesión expirada (401 Unauthorized)');
        _mostrarError('Sesión cerrada. Por favor, inicia sesión nuevamente.');

        // ✅ REINICIAR LA APLICACIÓN INSTANTÁNEAMENTE
        _reiniciarAplicacion();

        return; // ⬅️ IMPORTANTE: Salir del método
      } else {
        print('❌ Error en API CorreoCodigoCambioPassword - Status: ${response.statusCode}');
        _mostrarError('Error al enviar código: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error enviando código: $e');
      _mostrarError('Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ✅ CONFIRMAR CAMBIO DE CONTRASEÑA CON CÓDIGO (API v2 - CUERPO ACTUALIZADO)
  Future<void> _confirmarCambioPassword() async {
    print('🔄 Confirmando cambio de contraseña...');

    // Verificar que tenemos token del dispositivo
    if (_deviceToken == null) {
      _mostrarError('No se pudo obtener el token del dispositivo. Intenta nuevamente.');
      return;
    }

    // Validaciones
    final codigo = _codigoController.text.trim();
    final nuevaPassword = _nuevaPasswordController.text.trim();
    final confirmarPassword = _confirmarPasswordController.text.trim();

    // ✅ Estas validaciones ya están cubiertas por _botonHabilitado, pero las mantenemos por seguridad
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

    // ✅ VALIDACIÓN DE CONTRASEÑA SEGURA
    final errorValidacion = _validarContrasena(nuevaPassword);
    if (errorValidacion != null) {
      _mostrarError('Contraseña insegura: $errorValidacion');
      return;
    }

    // Verificar si el código ha expirado (10 minutos) - SOLO si se ha enviado un código
    if (_horaEnvioCodigo != null) {
      final ahora = DateTime.now();
      final diferencia = ahora.difference(_horaEnvioCodigo!).inMinutes;

      if (diferencia > 10) {
        _mostrarError('El código ha expirado. Debes solicitar uno nuevo.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ✅ CUERPO ACTUALIZADO SEGÚN TU ESPECIFICACIÓN
      final requestBody = {
        "mail": widget.email,
        "codigo_verificador": codigo,
        "nuevo_pass": nuevaPassword,
        "token_dispositivo": _deviceToken!,
      };

      print('📤 Request ConfirmarCambioPassword (v2):');
      print('🌐 URL: ${GlobalVariables.baseUrl}/ConfirmarCambioPassword/api/v2/'); // ✅ ACTUALIZADO A v2
      print('📋 Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/ConfirmarCambioPassword/api/v2/'), // ✅ ACTUALIZADO A v2
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response ConfirmarCambioPassword (v2):');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // ✅ VERIFICAR SI LA SESIÓN HA EXPIRADO - SOLO 1 SNACKBAR
        if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
          _mostrarError('Sesión cerrada. Por favor, inicia sesión nuevamente.');

          // ✅ REINICIAR LA APLICACIÓN INSTANTÁNEAMENTE
          _reiniciarAplicacion();

          return; // ⬅️ IMPORTANTE: Salir del método para no mostrar otro SnackBar
        }

        if (responseData['success'] == true) {
          _mostrarExito('Contraseña cambiada exitosamente');

          // Regresar al perfil después de 2 segundos
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            // ✅ CANCELAR TIMER ANTES DE SALIR
            _timer?.cancel();
            Navigator.pop(context);
          }
        } else {
          final mensajeError = responseData['message'] ?? 'Error desconocido';
          final codigoError = responseData['codigo_error'];

          // ✅ MANEJO DE ERRORES ESPECÍFICOS SEGÚN LA API
          if (codigoError == 'DEMASIADOS_INTENTOS') {
            final intentos = responseData['intentos'] ?? 3;
            _mostrarError('Demasiados intentos fallidos ($intentos). Debe solicitar un nuevo código.');

            // Limpiar formulario y forzar reenvío
            setState(() {
              _codigoController.clear();
              _intentosFallidos = intentos;
              _intentosRestantes = 0;
            });

          } else if (codigoError == 'CODIGO_EXPIRADO') {
            _mostrarError('El código ha expirado. Solicita uno nuevo.');

            setState(() {
              _codigoController.clear();
              _codigoEnviado = false;
              _horaEnvioCodigo = null;
            });

          } else if (codigoError == 'CODIGO_INCORRECTO') {
            final intentos = responseData['intentos'] ?? 0;
            final intentosRestantes = responseData['intentos_restantes'] ?? 3;

            setState(() {
              _intentosFallidos = intentos;
              _intentosRestantes = intentosRestantes;
            });

            _mostrarError('Código incorrecto. Intentos: $_intentosFallidos/3');

          } else if (codigoError == 'CONTRASENA_IGUAL') {
            _mostrarError('La nueva contraseña no puede ser igual a la actual');

          } else if (codigoError == 'SOLICITUD_NO_ENCONTRADA') {
            _mostrarError('No se encontró solicitud de cambio. Solicita un nuevo código.');

            setState(() {
              _codigoController.clear();
              _codigoEnviado = false;
              _horaEnvioCodigo = null;
            });

          } else if (codigoError == 'TOKEN_DISPOSITIVO_INVALIDO') {
            _mostrarError('Error de dispositivo. Por favor, reinicia la aplicación.');

          } else {
            _mostrarError(mensajeError);
          }
        }
      } else if (response.statusCode == 401) {
        // ✅ SESIÓN EXPIRADA POR STATUS 401 - SOLO 1 SNACKBAR
        print('🔐 Sesión expirada (401 Unauthorized)');
        _mostrarError('Sesión cerrada. Por favor, inicia sesión nuevamente.');

        // ✅ REINICIAR LA APLICACIÓN INSTANTÁNEAMENTE
        _reiniciarAplicacion();

        return; // ⬅️ IMPORTANTE: Salir del método
      } else {
        print('❌ Error en API ConfirmarCambioPassword - Status: ${response.statusCode}');
        _mostrarError('Error al cambiar contraseña: ${response.statusCode}');
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

  // ✅ MÉTODOS AUXILIARES PARA MOSTRAR MENSAJES (MISMO ESTILO GRIS)
  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[800], // Color gris oscuro
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[800], // Color gris oscuro
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
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

  // ✅ Verificar si el código ha expirado
  bool _codigoExpirado() {
    return _getSegundosRestantes() <= 0;
  }

  // ✅ Widget para mostrar indicadores de fortaleza de contraseña
  Widget _buildPasswordStrengthIndicator(String password) {
    if (password.isEmpty) return const SizedBox.shrink();

    final tieneLongitud = password.length >= 8;
    final tieneMayuscula = RegExp(r'[A-Z]').hasMatch(password);
    final tieneNumero = RegExp(r'[0-9]').hasMatch(password);
    final tieneSimbolo = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Fortaleza de contraseña:',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildRequirementIndicator('8+ chars', tieneLongitud),
            const SizedBox(width: 8),
            _buildRequirementIndicator('MAYÚS', tieneMayuscula),
            const SizedBox(width: 8),
            _buildRequirementIndicator('NÚM', tieneNumero),
            const SizedBox(width: 8),
            _buildRequirementIndicator('SÍM', tieneSimbolo),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirementIndicator(String label, bool cumple) {
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
    final codigoExpirado = _codigoExpirado();

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
      body: _isLoading && !_codigoEnviado
          ? Center(
        child: CircularProgressIndicator(
          color: _blueDarkColor,
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ BOTÓN PARA ENVIAR CÓDIGO (solo si no hay código enviado)
            if (!_codigoEnviado) ...[
              // ✅ MOSTRAR ESTADO DEL TOKEN DISPOSITIVO (solo para debug)
              if (_deviceToken != null && _deviceToken!.contains('fcm_'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Dispositivo: ${_deviceToken!.substring(0, 20)}...',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_deviceToken != null && !_isLoading) ? _enviarCodigo : null,
                  icon: const Icon(Icons.send, size: 20, color: Colors.white),
                  label: const Text(
                    'Enviar código de verificación',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_deviceToken != null && !_isLoading) ? _blueDarkColor : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ] else ...[
              // ✅ INFORMACIÓN DEL CÓDIGO ENVIADO (reemplaza al botón)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: _blueDarkColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _blueDarkColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ "CÓDIGO ENVIADO A:"
                    Text(
                      'Código enviado a:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _blueDarkColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ✅ EMAIL
                    Text(
                      widget.email,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // ✅ TIMER Y BOTÓN REENVIAR EN LA MISMA LÍNEA
                    Row(
                      children: [
                        // ✅ TIMER CON ICONO
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 18,
                              color: segundosRestantes < 60 ? Colors.red.shade700 : _blueDarkColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getTiempoRestante(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: segundosRestantes < 60 ? Colors.red.shade700 : _blueDarkColor,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // ✅ BOTÓN REENVIAR (EN LA MISMA ALTURA)
                        TextButton.icon(
                          onPressed: (_deviceToken != null && !_isLoading) ? _enviarCodigo : null,
                          icon: Icon(Icons.refresh, size: 16, color: _blueDarkColor),
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

            // ✅ FORMULARIO COMPLETO (SIEMPRE VISIBLE Y HABILITADO)
            // ✅ CAMPO PARA CÓDIGO DE VERIFICACIÓN
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
                hintText: 'Ingresar el código enviado',
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
                prefixIcon: Icon(Icons.code, size: 20, color: Colors.grey.shade600),
              ),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),

            // ✅ CAMPO PARA NUEVA CONTRASEÑA
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
              onChanged: (value) {
                setState(() {}); // Para actualizar el indicador en tiempo real
              },
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
                prefixIcon: Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade600),
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarContrasena ? Icons.visibility_off : Icons.visibility,
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

            // ✅ INDICADOR DE FORTALEZA DE CONTRASEÑA EN TIEMPO REAL
            _buildPasswordStrengthIndicator(_nuevaPasswordController.text),

            const SizedBox(height: 16),

            // ✅ CAMPO PARA CONFIRMAR CONTRASEÑA
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
                prefixIcon: Icon(Icons.lock_outline, size: 20, color: Colors.grey.shade600),
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarConfirmarContrasena ? Icons.visibility_off : Icons.visibility,
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

            const SizedBox(height: 24),

            // ✅ INFORMACIÓN ADICIONAL MEJORADA
            Container(
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
                      Icon(Icons.security, size: 16, color: _blueDarkColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Requisitos de seguridad',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
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
            ),

            const SizedBox(height: 24),

            // ✅ BOTÓN PARA CONFIRMAR CAMBIO DE CONTRASEÑA
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_deviceToken != null && _botonHabilitado) ? _confirmarCambioPassword : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_deviceToken != null && _botonHabilitado)
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
          ],
        ),
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
}
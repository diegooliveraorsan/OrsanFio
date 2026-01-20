import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'variables_globales.dart';

// ✅ COLOR AZUL OSCURO DEFINIDO GLOBALMENTE
final Color _blueDarkColor = const Color(0xFF0055B8);

class CambiarContrasenaScreen extends StatefulWidget {
  final String tokenComprador;
  final String email;

  const CambiarContrasenaScreen({
    super.key,
    required this.tokenComprador,
    required this.email,
  });

  @override
  State<CambiarContrasenaScreen> createState() => _CambiarContrasenaScreenState();
}

class _CambiarContrasenaScreenState extends State<CambiarContrasenaScreen> {
  final TextEditingController _antiguaController = TextEditingController();
  final TextEditingController _nuevaController = TextEditingController();
  final TextEditingController _confirmarController = TextEditingController();

  bool _isLoading = false;
  bool _mostrarAntigua = false;
  bool _mostrarNueva = false;
  bool _mostrarConfirmar = false;
  String? _deviceToken;

  @override
  void initState() {
    super.initState();
    _initializeDeviceToken();
  }

  // ✅ OBTENER TOKEN DEL DISPOSITIVO (FCM)
  Future<void> _initializeDeviceToken() async {
    try {
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        print('✅ Token FCM obtenido para cambio de contraseña: $fcmToken');
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

  // ✅ VERIFICAR SI LA SESIÓN HA EXPIRADO Y REINICIAR APP
  void _verificarSesionExpirada(Map<String, dynamic> responseData) {
    if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
      print('⚠️ Sesión expirada detectada en CambiarContrasenaScreen');

      // Mostrar mensaje de sesión cerrada
      _mostrarError('Sesión cerrada. Por favor, inicia sesión nuevamente.');

      // ✅ REINICIAR LA APLICACIÓN INSTANTÁNEAMENTE
      _reiniciarAplicacion();
    }
  }

  // ✅ REINICIAR LA APLICACIÓN NAVEGANDO AL MAIN
  void _reiniciarAplicacion() {
    print('🔄 Reiniciando aplicación desde CambiarContrasenaScreen...');

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

  // ✅ API PARA CAMBIAR CONTRASEÑA CON CONTRASEÑA ANTIGUA Y TOKEN DISPOSITIVO (v2)
  Future<void> _cambiarContrasena() async {
    print('🔄 Cambiando contraseña...');

    // Verificar que tenemos token del dispositivo
    if (_deviceToken == null) {
      _mostrarError('No se pudo obtener el token del dispositivo. Intenta nuevamente.');
      return;
    }

    final antigua = _antiguaController.text.trim();
    final nueva = _nuevaController.text.trim();
    final confirmar = _confirmarController.text.trim();

    // Validaciones básicas
    if (antigua.isEmpty || nueva.isEmpty || confirmar.isEmpty) {
      _mostrarError('Todos los campos son obligatorios');
      return;
    }

    if (nueva != confirmar) {
      _mostrarError('Las nuevas contraseñas no coinciden');
      return;
    }

    // ✅ VALIDACIÓN DE CONTRASEÑA SEGURA
    final errorValidacion = _validarContrasena(nueva);
    if (errorValidacion != null) {
      _mostrarError('Contraseña insegura: $errorValidacion');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final requestBody = {
        "token_comprador": widget.tokenComprador,
        "mail": widget.email,
        "antigua_password": antigua,
        "nueva_password": nueva,
        "token_dispositivo": _deviceToken!, // ✅ NUEVO CAMPO REQUERIDO
      };

      print('📤 Request CambiarPassword (v2):');
      print('🌐 URL: ${GlobalVariables.baseUrl}/CambiarPassword/api/v2/'); // ✅ CAMBIADO A v2
      print('📋 Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CambiarPassword/api/v2/'), // ✅ CAMBIADO A v2
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response CambiarPassword (v2):');
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
            Navigator.pop(context);
          }
        } else {
          final mensajeError = responseData['message'] ?? 'Error desconocido';
          final codigoError = responseData['codigo_error'];

          String mensajeUsuario = mensajeError;

          // Manejo de errores específicos según la API
          if (codigoError == 'CONTRASENA_IGUAL') {
            mensajeUsuario = 'La nueva contraseña debe ser diferente a la actual';
          } else if (codigoError == 'TOKEN_DISPOSITIVO_INVALIDO') {
            mensajeUsuario = 'Error de dispositivo. Por favor, reinicia la aplicación.';
          } else if (codigoError == 'CONTRASENA_ANTIGUA_INCORRECTA') {
            mensajeUsuario = 'La contraseña actual es incorrecta';
          }

          _mostrarError(mensajeUsuario);
        }
      } else if (response.statusCode == 401) {
        // ✅ SESIÓN EXPIRADA POR STATUS 401 - SOLO 1 SNACKBAR
        print('🔐 Sesión expirada (401 Unauthorized)');
        _mostrarError('Sesión cerrada. Por favor, inicia sesión nuevamente.');

        // ✅ REINICIAR LA APLICACIÓN INSTANTÁNEAMENTE
        _reiniciarAplicacion();

        return; // ⬅️ IMPORTANTE: Salir del método
      } else {
        print('❌ Error en API CambiarPassword - Status: ${response.statusCode}');
        _mostrarError('Error al cambiar contraseña: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error cambiando contraseña: $e');
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _blueDarkColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Cambiar Contraseña',
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
            // ✅ CAMPO PARA CONTRASEÑA ANTIGUA
            const Text(
              'Contraseña actual',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _antiguaController,
              obscureText: !_mostrarAntigua,
              decoration: InputDecoration(
                hintText: 'Ingresa tu contraseña actual',
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
                    _mostrarAntigua ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _mostrarAntigua = !_mostrarAntigua;
                    });
                  },
                ),
              ),
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 20),

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
              controller: _nuevaController,
              obscureText: !_mostrarNueva,
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
                    _mostrarNueva ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _mostrarNueva = !_mostrarNueva;
                    });
                  },
                ),
              ),
              textInputAction: TextInputAction.next,
            ),

            // ✅ INDICADOR DE FORTALEZA DE CONTRASEÑA EN TIEMPO REAL
            _buildPasswordStrengthIndicator(_nuevaController.text),

            const SizedBox(height: 20),

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
              controller: _confirmarController,
              obscureText: !_mostrarConfirmar,
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
                    _mostrarConfirmar ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _mostrarConfirmar = !_mostrarConfirmar;
                    });
                  },
                ),
              ),
              textInputAction: TextInputAction.done,
            ),

            // ✅ MOSTRAR ESTADO DEL TOKEN DISPOSITIVO (solo para debug en desarrollo)
            if (_deviceToken != null && _deviceToken!.contains('fcm_'))
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Dispositivo: ${_deviceToken!.substring(0, 20)}...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // ✅ BOTÓN PARA CAMBIAR CONTRASEÑA
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_deviceToken != null && !_isLoading) ? _cambiarContrasena : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_deviceToken != null && !_isLoading) ? _blueDarkColor : Colors.grey.shade400,
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
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'variables_globales.dart'; // ✅ Estilos y colores globales

// ✅ Color de fondo específico para esta tarjeta (se mantiene local)
final Color _approvedCardBackground = const Color(0xFFE8F0FE);

class EliminarCuentaScreen extends StatefulWidget {
  final String tokenComprador;
  final String email;
  final String userRun;
  final String userName;

  const EliminarCuentaScreen({
    super.key,
    required this.tokenComprador,
    required this.email,
    required this.userRun,
    required this.userName,
  });

  @override
  State<EliminarCuentaScreen> createState() => _EliminarCuentaScreenState();
}

class _EliminarCuentaScreenState extends State<EliminarCuentaScreen> {
  final TextEditingController _contrasenaController = TextEditingController();

  bool _isLoading = false;
  bool _mostrarContrasena = false;
  bool _contrasenaValida = false;
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
        print('✅ Token FCM obtenido para eliminación de cuenta: $fcmToken');
        setState(() {
          _deviceToken = fcmToken;
        });
      } else {
        print('⚠️ No se pudo obtener token FCM, usando fallback');
        final String fallbackToken =
            'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
        setState(() {
          _deviceToken = fallbackToken;
        });
      }
    } catch (e) {
      print('❌ Error obteniendo token FCM: $e');
      final String errorToken =
          'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _deviceToken = errorToken;
      });
    }
  }

  // ✅ EXTRAER RUN Y DV DEL FORMATO COMPLETO
  Map<String, String> _extraerRunYDv() {
    String runCompleto = widget.userRun;

    // Remover puntos y espacios
    runCompleto = runCompleto.replaceAll('.', '').replaceAll(' ', '');

    // Separar RUN y DV
    final partes = runCompleto.split('-');

    if (partes.length == 2) {
      return {
        'run': partes[0],
        'dv': partes[1],
      };
    } else {
      return {
        'run': '',
        'dv': '',
      };
    }
  }

  // ✅ VALIDAR CONTRASEÑA
  void _validarContrasena(String contrasena) {
    final bool esValida = contrasena.isNotEmpty;
    setState(() {
      _contrasenaValida = esValida;
    });
  }

  // ✅ VERIFICAR SI EL BOTÓN DEBE ESTAR HABILITADO
  bool get _botonHabilitado =>
      _deviceToken != null && _contrasenaValida && !_isLoading;

  // ✅ ELIMINAR CUENTA
  Future<void> _eliminarCuenta() async {
    if (!_botonHabilitado) return;

    // Extraer RUN y DV
    final runDv = _extraerRunYDv();
    final motivo = "1";
    setState(() {
      _isLoading = true;
    });

    try {
      final requestBody = {
        "token_comprador": widget.tokenComprador,
        "run_comprador": runDv['run'],
        "dv_comprador": runDv['dv'],
        "token_dispositivo": _deviceToken!,
        "correo_comprador": widget.email,
        "password_comprador": _contrasenaController.text.trim(),
        "motivo_eliminacion": motivo
      };

      print('📤 Request EliminarUsuario (v1):');
      print('🌐 URL: ${GlobalVariables.baseUrl}/EliminarUsuario/api/v1/');
      print('📋 Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/EliminarUsuario/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response EliminarUsuario (v1):');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == false &&
            responseData['sesion_iniciada'] == false) {
          GlobalSnackBars.mostrarError(
              context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          _reiniciarAplicacion();
          return;
        }

        if (responseData['success'] == true) {
          GlobalSnackBars.mostrarExito(context, 'Cuenta eliminada exitosamente');

          await Future.delayed(const Duration(seconds: 1));
          _reiniciarAplicacion();
        } else {
          final mensajeError = responseData['message'] ?? 'Error desconocido';
          final codigoError = responseData['codigo_error'];

          String mensajeUsuario = mensajeError;

          if (codigoError == 'CONTRASENA_INCORRECTA') {
            mensajeUsuario = 'Contraseña incorrecta';
          } else if (codigoError == 'CUENTA_CON_DEUDAS') {
            mensajeUsuario =
            'No puedes eliminar la cuenta con deudas pendientes';
          } else if (codigoError == 'CUENTA_CON_ACTIVIDAD_RECIENTE') {
            mensajeUsuario =
            'Hay actividad reciente en la cuenta. Intenta más tarde.';
          }

          GlobalSnackBars.mostrarError(context, mensajeUsuario);
        }
      } else if (response.statusCode == 401) {
        GlobalSnackBars.mostrarError(
            context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
        _reiniciarAplicacion();
      } else {
        GlobalSnackBars.mostrarError(
            context, 'Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error eliminando cuenta: $e');
      GlobalSnackBars.mostrarError(context, 'Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _reiniciarAplicacion() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
          (route) => false,
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
          icon: Icon(Icons.arrow_back, color: GlobalVariables.blueDarkColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Eliminar Cuenta',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: GlobalVariables.blueDarkColor,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ TARJETA DE CONFIRMACIÓN
                Container(
                  decoration: BoxDecoration(
                    color: _approvedCardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 3,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ADVERTENCIA
                        Row(
                          children: [
                            Icon(Icons.warning_amber_outlined,
                                color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'Advertencia',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Esta acción eliminará tu cuenta y todos tus datos permanentemente. No se puede deshacer.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // CAMPO DE CONTRASEÑA CON ESTILO GLOBAL
                        Text(
                          'Para confirmar, ingresa tu contraseña:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _contrasenaController,
                          obscureText: !_mostrarContrasena,
                          decoration: GlobalInputStyles.inputDecoration(
                            labelText: 'Contraseña',
                            hintText: 'Ingresa tu contraseña',
                            prefixIcon: Icons.lock_outline,
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
                          onChanged: _validarContrasena,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ✅ BOTÓN DE ELIMINAR CUENTA
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _botonHabilitado ? _eliminarCuenta : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      _botonHabilitado ? Colors.red : Colors.grey.shade400,
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
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_forever,
                            size: 20, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Eliminar Cuenta',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
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
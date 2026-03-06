import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'variables_globales.dart';

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

  Future<void> _initializeDeviceToken() async {
    try {
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        print('✅ Token FCM obtenido para cambio de contraseña: $fcmToken');
        setState(() => _deviceToken = fcmToken);
      } else {
        print('⚠️ No se pudo obtener token FCM, usando fallback');
        setState(() => _deviceToken = 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}');
      }
    } catch (e) {
      print('❌ Error obteniendo token FCM: $e');
      setState(() => _deviceToken = 'fcm_error_${DateTime.now().millisecondsSinceEpoch}');
    }
  }

  bool _esContrasenaSegura(String contrasena) {
    return contrasena.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(contrasena) &&
        RegExp(r'[0-9]').hasMatch(contrasena) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(contrasena);
  }

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

  void _reiniciarAplicacion() {
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Future<void> _cambiarContrasena() async {
    if (_deviceToken == null) {
      GlobalSnackBars.mostrarError(context, 'No se pudo obtener el token del dispositivo. Intenta nuevamente.');
      return;
    }

    final antigua = _antiguaController.text.trim();
    final nueva = _nuevaController.text.trim();
    final confirmar = _confirmarController.text.trim();

    if (antigua.isEmpty || nueva.isEmpty || confirmar.isEmpty) {
      GlobalSnackBars.mostrarError(context, 'Todos los campos son obligatorios');
      return;
    }

    if (nueva != confirmar) {
      GlobalSnackBars.mostrarError(context, 'Las nuevas contraseñas no coinciden');
      return;
    }

    final errorValidacion = _validarContrasena(nueva);
    if (errorValidacion != null) {
      GlobalSnackBars.mostrarError(context, 'Contraseña insegura: $errorValidacion');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CambiarPassword/api/v2/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "token_comprador": widget.tokenComprador,
          "mail": widget.email,
          "antigua_password": antigua,
          "nueva_password": nueva,
          "token_dispositivo": _deviceToken!,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
          GlobalSnackBars.mostrarError(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          _reiniciarAplicacion();
          return;
        }

        if (responseData['success'] == true) {
          GlobalSnackBars.mostrarExito(context, 'Contraseña cambiada exitosamente');
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pop(context);
        } else {
          final mensajeError = responseData['message'] ?? 'Error desconocido';
          final codigoError = responseData['codigo_error'];
          String mensajeUsuario = mensajeError;
          if (codigoError == 'CONTRASENA_IGUAL') {
            mensajeUsuario = 'La nueva contraseña debe ser diferente a la actual';
          } else if (codigoError == 'TOKEN_DISPOSITIVO_INVALIDO') {
            mensajeUsuario = 'Error de dispositivo. Por favor, reinicia la aplicación.';
          } else if (codigoError == 'CONTRASENA_ANTIGUA_INCORRECTA') {
            mensajeUsuario = 'La contraseña actual es incorrecta';
          }
          GlobalSnackBars.mostrarError(context, mensajeUsuario);
        }
      } else if (response.statusCode == 401) {
        GlobalSnackBars.mostrarError(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
        _reiniciarAplicacion();
      } else {
        GlobalSnackBars.mostrarError(context, 'Error al cambiar contraseña: ${response.statusCode}');
      }
    } catch (e) {
      GlobalSnackBars.mostrarError(context, 'Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
        Text('Fortaleza de contraseña:', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Row(children: [
          _buildRequirementIndicator('8+ chars', tieneLongitud),
          const SizedBox(width: 8),
          _buildRequirementIndicator('MAYÚS', tieneMayuscula),
          const SizedBox(width: 8),
          _buildRequirementIndicator('NÚM', tieneNumero),
          const SizedBox(width: 8),
          _buildRequirementIndicator('SÍM', tieneSimbolo),
        ]),
      ],
    );
  }

  Widget _buildRequirementIndicator(String label, bool cumple) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cumple ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: cumple ? Colors.green.shade300 : Colors.grey.shade300, width: 1),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cumple ? Colors.green.shade800 : Colors.grey.shade600)),
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
          'Cambiar Contraseña',
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
            // Contraseña actual
            TextFormField(
              controller: _antiguaController,
              obscureText: !_mostrarAntigua,
              decoration: GlobalInputStyles.inputDecoration(
                labelText: 'Contraseña actual',
                hintText: 'Ingresa tu contraseña actual',
                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarAntigua ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () => setState(() => _mostrarAntigua = !_mostrarAntigua),
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),

            // Nueva contraseña
            TextFormField(
              controller: _nuevaController,
              obscureText: !_mostrarNueva,
              onChanged: (_) => setState(() {}),
              decoration: GlobalInputStyles.inputDecoration(
                labelText: 'Nueva contraseña',
                hintText: 'Ingresa nueva contraseña',
                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarNueva ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () => setState(() => _mostrarNueva = !_mostrarNueva),
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            _buildPasswordStrengthIndicator(_nuevaController.text),
            const SizedBox(height: 20),

            // Confirmar contraseña
            TextFormField(
              controller: _confirmarController,
              obscureText: !_mostrarConfirmar,
              decoration: GlobalInputStyles.inputDecoration(
                labelText: 'Confirmar contraseña',
                hintText: 'Confirma la nueva contraseña',
                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(
                    _mostrarConfirmar ? Icons.visibility_off : Icons.visibility,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () => setState(() => _mostrarConfirmar = !_mostrarConfirmar),
                ),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 32),

            // Botón
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_deviceToken != null && !_isLoading) ? _cambiarContrasena : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_deviceToken != null && !_isLoading)
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
            const SizedBox(height: 20),

            // Requisitos de seguridad
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
                      Icon(Icons.security, size: 16, color: GlobalVariables.blueDarkColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Requisitos de seguridad',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black),
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
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey.shade700),
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
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
        ],
      ),
    );
  }
}
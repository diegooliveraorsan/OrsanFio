import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'variables_globales.dart';

// ✅ COLOR AZUL OSCURO DEFINIDO GLOBALMENTE
final Color _blueDarkColor = const Color(0xFF0055B8);

class CambiarPinSeguridadScreen extends StatefulWidget {
  final String tokenComprador;
  final String email;
  final String userRun;

  const CambiarPinSeguridadScreen({
    super.key,
    required this.tokenComprador,
    required this.email,
    required this.userRun,
  });

  @override
  State<CambiarPinSeguridadScreen> createState() => _CambiarPinSeguridadScreenState();
}

class _CambiarPinSeguridadScreenState extends State<CambiarPinSeguridadScreen> {
  final TextEditingController _nuevoPinController = TextEditingController();
  final TextEditingController _codigoVerificacionController = TextEditingController();
  final TextEditingController _contrasenaController = TextEditingController();

  bool _isLoading = false;
  bool _mostrarContrasena = false;
  bool _enviandoCodigo = false;
  bool _codigoEnviado = false;
  String? _errorPin;
  String? _errorCodigo;
  String? _errorContrasena;

  // ✅ VALIDAR FORMATO DEL PIN (4 dígitos numéricos)
  bool _validarPin(String pin) {
    if (pin.isEmpty) return false;
    if (pin.length != 4) return false;
    final regex = RegExp(r'^[0-9]{4}$');
    return regex.hasMatch(pin);
  }

  // ✅ ENVIAR CÓDIGO DE VERIFICACIÓN AL CORREO
  Future<void> _enviarCodigoVerificacion() async {
    if (widget.email.isEmpty) {
      _mostrarError('No se puede enviar código: Email no disponible');
      return;
    }

    setState(() {
      _enviandoCodigo = true;
    });

    try {
      final requestBody = {
        "token_comprador": widget.tokenComprador,
        "mail": widget.email,
        "tipo_operacion": "cambiar_pin",
      };

      print('📤 Enviando código de verificación...');
      print('🌐 URL: ${GlobalVariables.baseUrl}/SolicitarCodigoVerificacion/api/');
      print('📋 Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/SolicitarCodigoVerificacion/api/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response código verificación:');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          setState(() {
            _codigoEnviado = true;
          });
          _mostrarExito('Código enviado a tu correo electrónico');
        } else {
          final mensaje = responseData['message'] ?? 'Error al enviar código';
          _mostrarError(mensaje);
        }
      } else {
        _mostrarError('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error enviando código: $e');
      _mostrarError('Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() {
          _enviandoCodigo = false;
        });
      }
    }
  }

  // ✅ CAMBIAR PIN DE SEGURIDAD
  Future<void> _cambiarPinSeguridad() async {
    // Validaciones
    final nuevoPin = _nuevoPinController.text.trim();
    final codigo = _codigoVerificacionController.text.trim();
    final contrasena = _contrasenaController.text.trim();

    setState(() {
      _errorPin = null;
      _errorCodigo = null;
      _errorContrasena = null;
    });

    bool hayErrores = false;

    if (!_validarPin(nuevoPin)) {
      setState(() {
        _errorPin = 'El PIN debe tener exactamente 4 dígitos numéricos';
      });
      hayErrores = true;
    }

    if (codigo.isEmpty) {
      setState(() {
        _errorCodigo = 'El código de verificación es obligatorio';
      });
      hayErrores = true;
    }

    if (contrasena.isEmpty) {
      setState(() {
        _errorContrasena = 'La contraseña es obligatoria';
      });
      hayErrores = true;
    }

    if (hayErrores) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final requestBody = {
        "token_comprador": widget.tokenComprador,
        "mail": widget.email,
        "nuevo_pin": nuevoPin,
        "codigo_verificacion": codigo,
        "password": contrasena,
      };

      print('📤 Request CambiarPinSeguridad:');
      print('🌐 URL: ${GlobalVariables.baseUrl}/CambiarPinSeguridad/api/');
      print('📋 Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CambiarPinSeguridad/api/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response CambiarPinSeguridad:');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['success'] == false && responseData['sesion_iniciada'] == false) {
          _mostrarError('Sesión cerrada. Por favor, inicia sesión nuevamente.');
          _reiniciarAplicacion();
          return;
        }

        if (responseData['success'] == true) {
          _mostrarExito('PIN de seguridad actualizado exitosamente');

          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pop(context);
          }
        } else {
          final mensajeError = responseData['message'] ?? 'Error desconocido';
          final codigoError = responseData['codigo_error'];

          String mensajeUsuario = mensajeError;

          if (codigoError == 'CODIGO_INVALIDO') {
            mensajeUsuario = 'Código de verificación incorrecto o expirado';
          } else if (codigoError == 'CONTRASENA_INCORRECTA') {
            mensajeUsuario = 'Contraseña incorrecta';
          } else if (codigoError == 'PIN_FORMATO_INVALIDO') {
            mensajeUsuario = 'Formato de PIN inválido';
          } else if (codigoError == 'PIN_IGUAL_ANTERIOR') {
            mensajeUsuario = 'El nuevo PIN no puede ser igual al anterior';
          }

          _mostrarError(mensajeUsuario);
        }
      } else if (response.statusCode == 401) {
        _mostrarError('Sesión cerrada. Por favor, inicia sesión nuevamente.');
        _reiniciarAplicacion();
      } else {
        _mostrarError('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error cambiando PIN: $e');
      _mostrarError('Error de conexión: $e');
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

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[800],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey[800],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          'Cambiar PIN de Seguridad',
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
            // ✅ INFORMACIÓN EXPLICATIVA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: _blueDarkColor),
                      const SizedBox(width: 8),
                      Text(
                        'Importante',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _blueDarkColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Para cambiar tu PIN de seguridad necesitas:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildRequirementItem('1. Elegir un nuevo PIN de 4 dígitos'),
                  _buildRequirementItem('2. Recibir un código de verificación en tu correo'),
                  _buildRequirementItem('3. Confirmar con tu contraseña actual'),
                ],
              ),
            ),

            // ✅ CAMPO PARA NUEVO PIN
            const Text(
              'Nuevo PIN de seguridad',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nuevoPinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                hintText: 'Ingresa 4 dígitos numéricos',
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
                prefixIcon: Icon(Icons.pin_outlined, size: 20, color: Colors.grey.shade600),
                counterText: '',
                errorText: _errorPin,
              ),
              onChanged: (value) {
                setState(() {
                  if (_validarPin(value)) {
                    _errorPin = null;
                  }
                });
              },
            ),
            const SizedBox(height: 4),
            Text(
              'Ejemplo: 1234, 7890, 5555',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            // ✅ SECCIÓN DE CÓDIGO DE VERIFICACIÓN
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Código de verificación',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enviado a: ${widget.email}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _codigoEnviado || _enviandoCodigo ? null : _enviarCodigoVerificacion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blueDarkColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: _enviandoCodigo
                      ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Text(
                    _codigoEnviado ? 'Reenviar' : 'Enviar código',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _codigoVerificacionController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'Ingresa el código de 6 dígitos',
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
                prefixIcon: Icon(Icons.verified_user_outlined, size: 20, color: Colors.grey.shade600),
                counterText: '',
                errorText: _errorCodigo,
              ),
            ),

            const SizedBox(height: 20),

            // ✅ CAMPO PARA CONTRASEÑA
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
              controller: _contrasenaController,
              obscureText: !_mostrarContrasena,
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
                errorText: _errorContrasena,
              ),
            ),

            const SizedBox(height: 32),

            // ✅ BOTÓN PARA CAMBIAR PIN
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _cambiarPinSeguridad,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLoading ? Colors.grey.shade400 : _blueDarkColor,
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
                  'Cambiar PIN de Seguridad',
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
          Icon(Icons.circle, size: 8, color: _blueDarkColor),
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
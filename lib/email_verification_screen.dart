import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dashboard_screen.dart';
import 'variables_globales.dart';

// ✅ COLOR AZUL OSCURO DEFINIDO GLOBALMENTE (IGUAL QUE EN EL DASHBOARD)
final Color _blueDarkColor = const Color(0xFF0055B8);

class EmailVerificationScreen extends StatefulWidget {
  final String userEmail;
  final String tokenComprador;
  final VoidCallback onBack;
  final Map<String, dynamic> userData;

  const EmailVerificationScreen({
    super.key,
    required this.userEmail,
    required this.tokenComprador,
    required this.onBack,
    required this.userData,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  bool _isSendingEmail = false;
  bool _emailSent = false;
  bool _isResending = false;

  // ✅ MÉTODO PARA ENVIAR CORREO DE VERIFICACIÓN
  Future<void> _sendVerificationEmail() async {
    setState(() {
      if (_emailSent) {
        _isResending = true;
      } else {
        _isSendingEmail = true;
      }
    });

    try {
      print('📧 Enviando correo de verificación...');
      print('🔑 Token comprador: ${widget.tokenComprador}');
      print('📧 Email: ${widget.userEmail}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/EnviarCorreo/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': '${GlobalVariables.apiKey}',
        },
        body: json.encode({
          "token_comprador": widget.tokenComprador,
          "mail": widget.userEmail,
        }),
      );

      print('📥 Response EnviarCorreo - Status: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('✅ Correo enviado exitosamente: $responseData');

        setState(() {
          _emailSent = true;
        });

        if (_isResending) {
          _showSnackBar('Código reenviado a ${widget.userEmail}');
        } else {
          _showSnackBar('Código de verificación enviado a ${widget.userEmail}');
        }
      } else {
        print('❌ Error al enviar correo: ${response.statusCode}');
        _showSnackBar('Error al enviar el código de verificación');
      }
    } catch (e) {
      print('❌ Error de conexión: $e');
      _showSnackBar('Error de conexión al enviar el código');
    } finally {
      setState(() {
        _isSendingEmail = false;
        _isResending = false;
      });
    }
  }

  void _setupPasteListener() {
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus) {
          _handlePaste();
        }
      });
    }
  }

  void _handlePaste() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final pastedText = clipboardData?.text ?? '';

      if (pastedText.length == 6 && RegExp(r'^\d+$').hasMatch(pastedText)) {
        for (int i = 0; i < 6; i++) {
          _controllers[i].text = pastedText[i];
          if (i == 5) {
            _focusNodes[i].requestFocus();
          }
        }
      }
    } catch (e) {
      print('Error al pegar: $e');
    }
  }

  void _onFieldChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _onFieldSubmitted(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (index == 5 && value.isNotEmpty) {
      _verifyCode();
    }
  }

  void _verifyCode() {
    final code = _controllers.map((controller) => controller.text).join();

    if (code.length != 6) {
      _showSnackBar('Por favor ingresa el código completo de 6 dígitos');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    _confirmarCorreoAPI(code);
  }

  // ✅ MÉTODO PARA LLAMAR A LA API ConfirmarCorreo
  Future<void> _confirmarCorreoAPI(String codigo) async {
    try {
      print('🔐 Verificando código...');
      print('🔑 Token comprador: ${widget.tokenComprador}');
      print('🔢 Código: $codigo');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/ConfirmarCorreo/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': '${GlobalVariables.apiKey}',
        },
        body: json.encode({
          "token_comprador": widget.tokenComprador,
          "numero_confirmacion": codigo,
        }),
      );

      print('📥 Response ConfirmarCorreo - Status: ${response.statusCode}');
      print('📥 Body completo: ${response.body}');

      if (response.body.isNotEmpty) {
        try {
          final responseData = json.decode(response.body);
          print('🎯 Estructura de la respuesta:');
          print('   - Tipo: ${responseData.runtimeType}');
          print('   - Keys: ${responseData.keys}');
          print('   - Valores: $responseData');

          // ✅ VERIFICAR SI success ES true
          final bool success = responseData['success'] == true;
          print('✅ Success: $success');

          if (success) {
            _showSnackBar('✅ Correo verificado exitosamente');
            // ✅ VOLVER AL HOME Y ACTUALIZAR SESIÓN
            _returnToHomeAndRefresh();
          } else {
            print('❌ Código incorrecto');
            _showSnackBar('❌ Código incorrecto, por favor intenta nuevamente');
          }
        } catch (e) {
          print('❌ Error parseando JSON: $e');
          _showSnackBar('❌ Error al verificar el código');
        }
      } else {
        print('❌ Respuesta vacía');
        _showSnackBar('❌ Error al verificar el código');
      }

    } catch (e) {
      print('❌ Error de conexión en verificación: $e');
      _showSnackBar('❌ Error de conexión al verificar el código');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ✅ MÉTODO MEJORADO PARA VOLVER AL HOME Y REFRESCAR SESIÓN
  void _returnToHomeAndRefresh() {
    print('🏠 Volviendo al Home y refrescando sesión...');

    // ✅ USAR pushReplacement PARA VOLVER AL DASHBOARD ACTUALIZADO
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(
          userData: widget.userData, // ✅ PASAR LOS DATOS ACTUALES
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _clearAllFields() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  // ✅ MÉTODO PARA REENVIAR CÓDIGO
  void _resendCode() {
    _sendVerificationEmail();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
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
          onPressed: widget.onBack,
        ),
        title: Text(
          'Verificar Correo',
          style: TextStyle(
            fontSize: 18,
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
 //           Text(
   //           'Verificación de correo electrónico',
     //         style: TextStyle(
       //         fontSize: 24,
         //       fontWeight: FontWeight.bold,
           //     color: _blueDarkColor, // ✅ CAMBIADO: Ahora usa el azul oscuro
             // ),
            //),
            //const SizedBox(height: 16),

            Text(
              'Hemos enviado un código de verificación a:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),

            // Email del usuario
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _blueDarkColor.withOpacity(0.1), // ✅ CAMBIADO: Fondo azul claro
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _blueDarkColor.withOpacity(0.3)), // ✅ CAMBIADO: Borde azul
              ),
              child: Column(
                children: [
                  Text(
                    widget.userEmail,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _blueDarkColor, // ✅ CAMBIADO: Ahora usa el azul oscuro
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_isSendingEmail) ...[
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Enviando código...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ] else if (_emailSent) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: _blueDarkColor, size: 16), // ✅ CAMBIADO: Azul oscuro
                        const SizedBox(width: 4),
                        Text(
                          'Código enviado',
                          style: TextStyle(
                            fontSize: 12,
                            color: _blueDarkColor, // ✅ CAMBIADO: Azul oscuro
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Por favor ingresa el código que recibiste:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 32),

            // Campos para el código de 6 dígitos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                return SizedBox(
                  width: 50,
                  height: 60,
                  child: TextField(
                    controller: _controllers[index],
                    focusNode: _focusNodes[index],
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: _blueDarkColor, width: 2), // ✅ CAMBIADO: Azul oscuro
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    onChanged: (value) => _onFieldChanged(index, value),
                    onSubmitted: (value) => _onFieldSubmitted(index, value),
                  ),
                );
              }),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _handlePaste,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blueDarkColor, // ✅ CAMBIADO: Azul oscuro
                  side: BorderSide(color: _blueDarkColor), // ✅ CAMBIADO: Azul oscuro
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Pegar Código',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _clearAllFields,
                child: Text(
                  'Limpiar campos',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Botón de verificación
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blueDarkColor, // ✅ CAMBIADO: Azul oscuro
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
                  'Verificar Código',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Reenviar código
            Center(
              child: TextButton(
                onPressed: (_isSendingEmail || _isResending) ? null : _resendCode,
                child: _isResending
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Reenviando código...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                )
                    : Text(
                  '¿No recibiste el código? Reenviar',
                  style: TextStyle(
                    fontSize: 14,
                    color: _blueDarkColor, // ✅ CAMBIADO: Azul oscuro
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
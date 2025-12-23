import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  // ✅ API PARA CAMBIAR CONTRASEÑA CON CONTRASEÑA ANTIGUA
  Future<void> _cambiarContrasena() async {
    print('🔄 Cambiando contraseña...');

    final antigua = _antiguaController.text.trim();
    final nueva = _nuevaController.text.trim();
    final confirmar = _confirmarController.text.trim();

    // Validaciones
    if (antigua.isEmpty || nueva.isEmpty || confirmar.isEmpty) {
      _mostrarError('Todos los campos son obligatorios');
      return;
    }

    if (nueva != confirmar) {
      _mostrarError('Las nuevas contraseñas no coinciden');
      return;
    }

    if (nueva.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres');
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
      };

      print('📤 Request CambiarPassword:');
      print('🌐 URL: ${GlobalVariables.baseUrl}/CambiarPassword/api/v1/');
      print('📋 Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CambiarPassword/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response CambiarPassword:');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

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
          }

          _mostrarError(mensajeUsuario);
        }
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
            color: _blueDarkColor, // ✅ CAMBIADO: Azul oscuro
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
                  borderSide: BorderSide(color: Colors.grey.shade400), // ✅ CONTORNO GRIS
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400), // ✅ CONTORNO GRIS
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _blueDarkColor, width: 2), // ✅ CONTORNO AZUL OSCURO AL FOCUS
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
              decoration: InputDecoration(
                hintText: 'Ingresa nueva contraseña',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400), // ✅ CONTORNO GRIS
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400), // ✅ CONTORNO GRIS
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _blueDarkColor, width: 2), // ✅ CONTORNO AZUL OSCURO AL FOCUS
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
                  borderSide: BorderSide(color: Colors.grey.shade400), // ✅ CONTORNO GRIS
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade400), // ✅ CONTORNO GRIS
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _blueDarkColor, width: 2), // ✅ CONTORNO AZUL OSCURO AL FOCUS
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

            const SizedBox(height: 32),

            // ✅ BOTÓN PARA CAMBIAR CONTRASEÑA
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _cambiarContrasena,
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

            // ✅ INFORMACIÓN ADICIONAL
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      const Text(
                        'Recomendaciones de seguridad',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Usa una contraseña diferente a la que usas en otros sitios\n• Combina letras, números y símbolos\n• No uses información personal fácil de adivinar\n• Cambia tu contraseña regularmente',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.5,
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
}
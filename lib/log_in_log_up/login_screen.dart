import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import '../variables_globales.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _deviceToken = 'generando...';

  // Función para detectar la plataforma real
  String _getPlatform() {
    if (Platform.isAndroid) {
      return "android";
    } else if (Platform.isIOS) {
      return "ios";
    } else if (Platform.isWindows) {
      return "windows";
    } else if (Platform.isMacOS) {
      return "macos";
    } else if (Platform.isLinux) {
      return "linux";
    } else {
      return "unknown";
    }
  }

  // OBTENER TOKEN FCM REAL
  Future<String> _getFCMToken() async {
    try {
      // ✅ INICIALIZAR FIREBASE PRIMERO
      await Firebase.initializeApp();

      // Obtener el token FCM real de Firebase
      String? fcmToken = await FirebaseMessaging.instance.getToken();

      if (fcmToken != null) {
        print('✅ Token FCM obtenido: $fcmToken');
        return fcmToken;
      } else {
        print('⚠️ No se pudo obtener token FCM, usando fallback');
        return 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      print('❌ Error obteniendo token FCM: $e');
      return 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeFCMToken();
  }

  // Inicializar el token FCM
  Future<void> _initializeFCMToken() async {
    try {
      final String fcmToken = await _getFCMToken();
      setState(() {
        _deviceToken = fcmToken;
      });
      print('🎯 Token FCM listo: $fcmToken');
    } catch (e) {
      final String fallbackToken = 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _deviceToken = fallbackToken;
      });
      print('⚠️ Usando token fallback: $fallbackToken');
    }
  }

  // Función para iniciar sesión
  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Por favor ingresa email y contraseña');
      return;
    }

    // Validar formato de email
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(_emailController.text)) {
      _showSnackBar('Por favor ingresa un email válido');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String platform = _getPlatform();

      print('🔍 REQUEST COMPLETO:');
      print('URL: https://apiorsanpay.orsanevaluaciones.cl/IniciarSesion/api/v1/');
      print('Body: ${json.encode({
        "mail": _emailController.text,
        "password": _passwordController.text,
        "token_dispositivo": _deviceToken,
        "tipo_dispositivo": platform,
      })}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/IniciarSesion/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': '${GlobalVariables.apiKey}',
        },
        body: json.encode({
          "mail": _emailController.text,
          "password": _passwordController.text,
          "token_dispositivo": _deviceToken,
          "tipo_dispositivo": platform,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      print('📥 RESPONSE:');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _showSnackBar('Login exitoso');
        _showApiResponse(responseData);
      } else {
        print('❌ ERROR DETALLADO:');
        print('Status: ${response.statusCode}');
        print('Body: ${response.body}');

        if (response.body.isNotEmpty) {
          try {
            final errorData = json.decode(response.body);
            _showSnackBar('Error: ${errorData['error'] ?? errorData['message'] ?? 'Error del servidor'}');
          } catch (e) {
            _showSnackBar('Error ${response.statusCode}: ${response.body}');
          }
        } else {
          _showSnackBar('Error ${response.statusCode}: Servidor no respondió');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('❌ ERROR DE CONEXIÓN: $e');
      _showSnackBar('Error de conexión: $e');
    }
  }

  // ✅ MÉTODO PARA MOSTRAR RESPUESTA DE LA API
  void _showApiResponse(Map<String, dynamic> responseData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Login Exitoso'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Respuesta de la API:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Mostrar datos del comprador
              if (responseData['comprador'] != null) ...[
                _buildResponseItem('👤 Nombre', responseData['comprador']['nombre_comprador']),
                _buildResponseItem('📧 Email', responseData['comprador']['correo_comprador']),
                _buildResponseItem('🆔 Token', responseData['comprador']['token_comprador']),
                _buildResponseItem('🏢 RUN', responseData['comprador']['run_comprador']),
                const SizedBox(height: 10),
              ],

              // Mostrar auditoría
              if (responseData['auditoria'] != null) ...[
                _buildResponseItem('✅ Código', responseData['auditoria']['codigo_error']),
                _buildResponseItem('📝 Mensaje', responseData['auditoria']['glosa_error']),
                const SizedBox(height: 10),
              ],

              // Mostrar información del dispositivo enviado
              _buildResponseItem('📱 Dispositivo', _deviceToken),
              _buildResponseItem('⚙️ Plataforma', _getPlatform()),
              _buildResponseItem('🔐 Tipo', 'Token FCM de Firebase'),

              // Botón para ver respuesta completa
              ExpansionTile(
                title: const Text('Ver respuesta completa JSON'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(responseData),
                      style: const TextStyle(fontFamily: 'Monospace', fontSize: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para mostrar items de respuesta
  Widget _buildResponseItem(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? 'N/A',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Iniciar Sesión'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),

              const Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ingresa tus credenciales',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 60),

              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 20),

              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
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
                    'Iniciar Sesión',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Información del dispositivo
              Card(
                color: Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📱 Token FCM del dispositivo:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Plataforma: ${_getPlatform()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        'Token FCM: $_deviceToken',
                        style: const TextStyle(fontSize: 12, fontFamily: 'Monospace', fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Tipo: Token FCM de Firebase',
                        style: TextStyle(fontSize: 12, color: Colors.green[700]),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Volver al Inicio',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'variables_globales.dart';

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

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeDeviceToken();

    if (widget.esReenvio) {
      _codigoEnviado = true;
      _horaEnvioCodigo = DateTime.now();
      _iniciarTimer();
    }

    _codigoController.addListener(_actualizarEstadoBoton);
    _nuevaPasswordController.addListener(() {
      _actualizarEstadoBoton();
      setState(() {});
    });
    _confirmarPasswordController.addListener(_actualizarEstadoBoton);
  }

  Future<void> _initializeDeviceToken() async {
    try {
      await Firebase.initializeApp();
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      setState(() {
        _deviceToken = fcmToken ?? 'fcm_fallback_${DateTime.now().millisecondsSinceEpoch}';
      });
    } catch (e) {
      setState(() {
        _deviceToken = 'fcm_error_${DateTime.now().millisecondsSinceEpoch}';
      });
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

  @override
  void dispose() {
    _timer?.cancel();
    _codigoController.removeListener(_actualizarEstadoBoton);
    _nuevaPasswordController.removeListener(() {
      _actualizarEstadoBoton();
      setState(() {});
    });
    _confirmarPasswordController.removeListener(_actualizarEstadoBoton);
    super.dispose();
  }

  void _reiniciarAplicacion() {
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  void _actualizarEstadoBoton() => setState(() {});

  bool get _botonHabilitado {
    final codigo = _codigoController.text.trim();
    final nueva = _nuevaPasswordController.text.trim();
    final confirmar = _confirmarPasswordController.text.trim();
    return codigo.length == 8 &&
        nueva.isNotEmpty &&
        confirmar.isNotEmpty &&
        nueva == confirmar &&
        _esContrasenaSegura(nueva) &&
        !_isLoading;
  }

  void _iniciarTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _horaEnvioCodigo != null) {
        if (_getSegundosRestantes() <= 0) {
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
          setState(() {});
        }
      }
    });
  }

  Future<void> _enviarCodigo() async {
    if (_deviceToken == null) {
      GlobalSnackBars.mostrarError(context, 'No se pudo obtener el token del dispositivo. Intenta nuevamente.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CorreoCodigoCambioPassword/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "token_comprador": widget.tokenComprador,
          "mail": widget.email,
          "token_dispositivo": _deviceToken,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == false && data['sesion_iniciada'] == false) {
          GlobalSnackBars.mostrarError(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          _reiniciarAplicacion();
          return;
        }
        if (data['success'] == true) {
          setState(() {
            _codigoEnviado = true;
            _horaEnvioCodigo = DateTime.now();
            _intentosFallidos = 0;
            _intentosRestantes = 3;
          });
          GlobalSnackBars.mostrarExito(context, 'Código enviado exitosamente');
          _iniciarTimer();
        } else {
          GlobalSnackBars.mostrarError(context, data['message'] ?? 'Error desconocido');
        }
      } else if (response.statusCode == 401) {
        GlobalSnackBars.mostrarError(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
        _reiniciarAplicacion();
      } else {
        GlobalSnackBars.mostrarError(context, 'Error al enviar código: ${response.statusCode}');
      }
    } catch (e) {
      GlobalSnackBars.mostrarError(context, 'Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmarCambioPassword() async {
    if (_deviceToken == null) {
      GlobalSnackBars.mostrarError(context, 'No se pudo obtener el token del dispositivo.');
      return;
    }

    final codigo = _codigoController.text.trim();
    final nueva = _nuevaPasswordController.text.trim();
    final confirmar = _confirmarPasswordController.text.trim();

    if (codigo.length != 8) {
      GlobalSnackBars.mostrarError(context, 'El código debe tener 8 caracteres');
      return;
    }
    if (nueva.isEmpty || confirmar.isEmpty) {
      GlobalSnackBars.mostrarError(context, 'Ingresa y confirma la nueva contraseña');
      return;
    }
    if (nueva != confirmar) {
      GlobalSnackBars.mostrarError(context, 'Las contraseñas no coinciden');
      return;
    }
    final error = _validarContrasena(nueva);
    if (error != null) {
      GlobalSnackBars.mostrarError(context, 'Contraseña insegura: $error');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/ConfirmarCambioPassword/api/v2/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({
          "mail": widget.email,
          "codigo_verificador": codigo,
          "nuevo_pass": nueva,
          "token_dispositivo": _deviceToken,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == false && data['sesion_iniciada'] == false) {
          GlobalSnackBars.mostrarError(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          _reiniciarAplicacion();
          return;
        }
        if (data['success'] == true) {
          GlobalSnackBars.mostrarExito(context, 'Contraseña cambiada exitosamente');
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            _timer?.cancel();
            Navigator.pop(context);
          }
        } else {
          final msg = data['message'] ?? 'Error desconocido';
          final codigoError = data['codigo_error'];
          if (codigoError == 'CODIGO_INCORRECTO') {
            setState(() => _intentosFallidos = data['intentos'] ?? 0);
            GlobalSnackBars.mostrarError(context, 'Código incorrecto. Intentos: $_intentosFallidos/3');
          } else if (codigoError == 'CODIGO_EXPIRADO') {
            setState(() {
              _codigoEnviado = false;
              _horaEnvioCodigo = null;
            });
            GlobalSnackBars.mostrarError(context, 'El código ha expirado. Solicita uno nuevo.');
          } else {
            GlobalSnackBars.mostrarError(context, msg);
          }
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

  int _getSegundosRestantes() {
    if (_horaEnvioCodigo == null) return 0;
    final transcurrido = DateTime.now().difference(_horaEnvioCodigo!).inSeconds;
    return (600 - transcurrido).clamp(0, 600);
  }

  String _getTiempoRestante() {
    final seg = _getSegundosRestantes();
    return '${(seg ~/ 60).toString().padLeft(2, '0')}:${(seg % 60).toString().padLeft(2, '0')}';
  }

  Widget _buildPasswordStrengthIndicator(String password) {
    if (password.isEmpty) return const SizedBox.shrink();
    final l = password.length >= 8;
    final may = RegExp(r'[A-Z]').hasMatch(password);
    final num = RegExp(r'[0-9]').hasMatch(password);
    final sim = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Fortaleza:', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        const SizedBox(height: 4),
        Row(children: [
          _buildReq('8+', l), const SizedBox(width: 8),
          _buildReq('MAY', may), const SizedBox(width: 8),
          _buildReq('NUM', num), const SizedBox(width: 8),
          _buildReq('SIM', sim),
        ]),
      ],
    );
  }

  Widget _buildReq(String label, bool ok) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ok ? Colors.green.shade300 : Colors.grey.shade300),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: ok ? Colors.green.shade800 : Colors.grey.shade600)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final segRest = _getSegundosRestantes();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: GlobalVariables.blueDarkColor),
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Recuperar Contraseña',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: GlobalVariables.blueDarkColor),
        ),
        centerTitle: true,
      ),
      body: _isLoading && !_codigoEnviado
          ? Center(child: CircularProgressIndicator(color: GlobalVariables.blueDarkColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_codigoEnviado) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_deviceToken != null && !_isLoading) ? _enviarCodigo : null,
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: const Text('Enviar código de verificación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_deviceToken != null && !_isLoading) ? GlobalVariables.blueDarkColor : Colors.grey.shade400,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: GlobalVariables.blueDarkColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: GlobalVariables.blueDarkColor.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Código enviado a:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: GlobalVariables.blueDarkColor)),
                    const SizedBox(height: 4),
                    Text(widget.email, style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.timer_outlined, size: 18, color: segRest < 60 ? Colors.red.shade700 : GlobalVariables.blueDarkColor),
                            const SizedBox(width: 6),
                            Text(
                              _getTiempoRestante(),
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: segRest < 60 ? Colors.red.shade700 : GlobalVariables.blueDarkColor),
                            ),
                          ],
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: (_deviceToken != null && !_isLoading) ? _enviarCodigo : null,
                          icon: Icon(Icons.refresh, color: GlobalVariables.blueDarkColor),
                          label: Text('Reenviar código', style: TextStyle(color: GlobalVariables.blueDarkColor)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            if (_intentosFallidos > 0 && _codigoEnviado)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Intentos fallidos: $_intentosFallidos/3', style: TextStyle(fontSize: 14, color: Colors.red.shade700, fontWeight: FontWeight.w500))),
                  ],
                ),
              ),

            // Código de verificación
            TextFormField(
              controller: _codigoController,
              maxLength: 8,
              decoration: GlobalInputStyles.inputDecoration(
                labelText: 'Código de verificación',
                hintText: 'Ingresa el código enviado',
                prefixIcon: Icons.code,
              ).copyWith(counterText: ''),
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 24),

            // Nueva contraseña
            TextFormField(
              controller: _nuevaPasswordController,
              obscureText: !_mostrarContrasena,
              onChanged: (_) => setState(() {}),
              decoration: GlobalInputStyles.inputDecoration(
                labelText: 'Nueva contraseña',
                hintText: 'Ingresa nueva contraseña',
                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(_mostrarContrasena ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
                  onPressed: () => setState(() => _mostrarContrasena = !_mostrarContrasena),
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            _buildPasswordStrengthIndicator(_nuevaPasswordController.text),
            const SizedBox(height: 16),

            // Confirmar contraseña
            TextFormField(
              controller: _confirmarPasswordController,
              obscureText: !_mostrarConfirmarContrasena,
              decoration: GlobalInputStyles.inputDecoration(
                labelText: 'Confirmar contraseña',
                hintText: 'Confirma la nueva contraseña',
                prefixIcon: Icons.lock_outline,
                suffixIcon: IconButton(
                  icon: Icon(_mostrarConfirmarContrasena ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
                  onPressed: () => setState(() => _mostrarConfirmarContrasena = !_mostrarConfirmarContrasena),
                ),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),

            // Botón Cambiar Contraseña
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (_deviceToken != null && _botonHabilitado) ? _confirmarCambioPassword : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_deviceToken != null && _botonHabilitado) ? GlobalVariables.blueDarkColor : Colors.grey.shade400,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Cambiar Contraseña', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),

            // Requisitos de seguridad
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.security, size: 16, color: GlobalVariables.blueDarkColor),
                      const SizedBox(width: 8),
                      const Text('Requisitos de seguridad', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildRequirementItem('Mínimo 8 caracteres'),
                  _buildRequirementItem('Al menos una letra mayúscula'),
                  _buildRequirementItem('Al menos un número (0-9)'),
                  _buildRequirementItem('Al menos un símbolo (! @ # \$ % ^ & *)'),
                  const SizedBox(height: 8),
                  Text('Ejemplo seguro: "Passw0rd\$2026"', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey.shade700)),
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
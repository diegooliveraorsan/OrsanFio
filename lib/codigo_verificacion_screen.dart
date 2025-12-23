import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
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

  // ✅ TIMER PARA ACTUALIZAR EL CONTADOR
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // ✅ Si es reenvío desde perfil, marcar como código ya enviado
    if (widget.esReenvio) {
      _codigoEnviado = true;
      _horaEnvioCodigo = DateTime.now();
      _iniciarTimer();
    }

    // ✅ Escuchar cambios en los campos de texto
    _codigoController.addListener(_actualizarEstadoBoton);
    _nuevaPasswordController.addListener(_actualizarEstadoBoton);
    _confirmarPasswordController.addListener(_actualizarEstadoBoton);
  }

  @override
  void dispose() {
    // ✅ CANCELAR TIMER AL SALIR
    _timer?.cancel();
    // ✅ Limpiar listeners
    _codigoController.removeListener(_actualizarEstadoBoton);
    _nuevaPasswordController.removeListener(_actualizarEstadoBoton);
    _confirmarPasswordController.removeListener(_actualizarEstadoBoton);
    super.dispose();
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
    return codigo.length == 8 &&
        nuevaPassword.isNotEmpty &&
        confirmarPassword.isNotEmpty &&
        nuevaPassword == confirmarPassword &&
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

  // ✅ ENVIAR CÓDIGO
  Future<void> _enviarCodigo() async {
    print('🔄 Enviando código...');

    setState(() {
      _isLoading = true;
    });

    try {
      final requestBody = {
        "token_comprador": widget.tokenComprador,
        "mail": widget.email,
      };

      print('📤 Request CorreoCodigoCambioPassword:');
      print('🌐 URL: ${GlobalVariables.baseUrl}/CorreoCodigoCambioPassword/api/v1/');
      print('📋 Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/CorreoCodigoCambioPassword/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response CorreoCodigoCambioPassword:');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

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
          _mostrarError('Error: $mensajeError');
        }
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

  // ✅ CONFIRMAR CAMBIO DE CONTRASEÑA CON CÓDIGO
  Future<void> _confirmarCambioPassword() async {
    print('🔄 Confirmando cambio de contraseña...');

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

    // ✅ COMENTADO: Validación de longitud mínima de contraseña
    /*
    if (nuevaPassword.length < 6) {
      _mostrarError('La contraseña debe tener al menos 6 caracteres');
      return;
    }
    */

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
      final requestBody = {
        "token_comprador": widget.tokenComprador,
        "codigo_verificador": codigo,
        "mail": widget.email,
        "nuevo_pass": nuevaPassword,
      };

      print('📤 Request ConfirmarCambioPassword:');
      print('🌐 URL: ${GlobalVariables.baseUrl}/ConfirmarCambioPassword/api/v1/');
      print('📋 Body: ${json.encode(requestBody)}');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/ConfirmarCambioPassword/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response ConfirmarCambioPassword:');
      print('  - Status: ${response.statusCode}');
      print('  - Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

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

          } else {
            _mostrarError(mensajeError);
          }
        }
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
            color: _blueDarkColor, // ✅ CAMBIADO: Azul oscuro
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading && !_codigoEnviado
          ? Center(
        child: CircularProgressIndicator(
          color: _blueDarkColor, // ✅ CAMBIADO: Azul oscuro
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ BOTÓN PARA ENVIAR CÓDIGO (solo si no hay código enviado)
            if (!_codigoEnviado) ...[
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _enviarCodigo,
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
                    backgroundColor: _blueDarkColor, // ✅ CAMBIADO: Azul oscuro
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
                  color: _blueDarkColor.withOpacity(0.1), // ✅ CAMBIADO: Azul claro
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _blueDarkColor.withOpacity(0.3)), // ✅ CAMBIADO: Borde azul
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
                        color: _blueDarkColor, // ✅ CAMBIADO: Azul oscuro
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
                              color: segundosRestantes < 60 ? Colors.red.shade700 : _blueDarkColor, // ✅ CAMBIADO: Azul oscuro
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getTiempoRestante(),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: segundosRestantes < 60 ? Colors.red.shade700 : _blueDarkColor, // ✅ CAMBIADO: Azul oscuro
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // ✅ BOTÓN REENVIAR (EN LA MISMA ALTURA)
                        TextButton.icon(
                          onPressed: _isLoading ? null : _enviarCodigo,
                          icon: Icon(Icons.refresh, size: 16, color: _blueDarkColor), // ✅ CAMBIADO: Azul oscuro
                          label: Text(
                            'Reenviar código',
                            style: TextStyle(
                              fontSize: 14,
                              color: _blueDarkColor, // ✅ CAMBIADO: Azul oscuro
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

            const SizedBox(height: 32),

            // ✅ BOTÓN PARA CONFIRMAR CAMBIO DE CONTRASEÑA
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _botonHabilitado ? _confirmarCambioPassword : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _botonHabilitado
                      ? _blueDarkColor // ✅ CAMBIADO: Azul oscuro
                      : Colors.grey.shade400, // ✅ MANTENIDO: Gris para deshabilitado
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
}
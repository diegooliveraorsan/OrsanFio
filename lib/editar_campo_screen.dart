import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'variables_globales.dart';

class EditarCampoScreen extends StatefulWidget {
  final String titulo;
  final String label;
  final String valorInicial;
  final TextInputType teclado;
  final String tokenComprador;
  final String tokenDispositivo;
  final String? correoActual;

  const EditarCampoScreen({
    super.key,
    required this.titulo,
    required this.label,
    required this.valorInicial,
    required this.teclado,
    required this.tokenComprador,
    required this.tokenDispositivo,
    this.correoActual,
  });

  @override
  State<EditarCampoScreen> createState() => _EditarCampoScreenState();
}

class _EditarCampoScreenState extends State<EditarCampoScreen> {
  late TextEditingController _controller;
  late TextEditingController _passwordController;
  late TextEditingController _codigoController;
  late String _originalValue;

  final _formKey = GlobalKey<FormState>();
  final Color _blueDarkColor = GlobalVariables.blueDarkColor;
  final Color _approvedCardBackground = const Color(0xFFE8F0FE);

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isEnviandoCodigo = false;
  bool _codigoEnviado = false;

  String get _tipoDato {
    if (widget.teclado == TextInputType.phone) return '1';
    if (widget.teclado == TextInputType.emailAddress) return '2';
    return '3';
  }

  @override
  void initState() {
    super.initState();
    _inicializarControladores();
  }

  void _inicializarControladores() {
    String valor = widget.valorInicial;

    if (widget.teclado == TextInputType.phone) {
      valor = valor.replaceAll(RegExp(r'[^\d]'), '');
      _controller = TextEditingController(text: valor);
      _originalValue = valor;
    } else if (widget.teclado == TextInputType.emailAddress) {
      valor = valor.replaceAll(' ', '');
      _controller = TextEditingController(text: valor);
      _originalValue = valor;
      _passwordController = TextEditingController();
      _codigoController = TextEditingController();
    } else {
      valor = valor.trim();
      _controller = TextEditingController(text: valor);
      _originalValue = valor;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (widget.teclado == TextInputType.emailAddress) {
      _passwordController.dispose();
      _codigoController.dispose();
    }
    super.dispose();
  }

  String? _validarAlias(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El alias no puede estar vacío';
    }
    return null;
  }

  String? _validarTelefono(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresa el teléfono';
    }
    if (value.length < 11) {
      return 'El teléfono debe tener al menos 11 dígitos';
    }
    return null;
  }

  String? _validarEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Ingresa un correo electrónico';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(trimmed)) return 'Ingresa un correo válido';
    return null;
  }

  String? _validarPassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu contraseña actual';
    return null;
  }

  String? _validarCodigo(String? value) {
    if (_codigoEnviado && (value == null || value.isEmpty)) {
      return 'Ingresa el código de verificación';
    }
    return null;
  }

  bool get _isEmailValid {
    if (widget.teclado != TextInputType.emailAddress) return false;
    return _validarEmail(_controller.text) == null;
  }

  Future<void> _enviarCodigoVerificacion() async {
    if (!_isEmailValid) {
      GlobalSnackBars.mostrarError(context, 'Ingresa un correo válido primero');
      return;
    }

    setState(() => _isEnviandoCodigo = true);

    try {
      final url = Uri.parse('${GlobalVariables.baseUrl}/EnviarCodigoVerificacion/api/v1/');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode({"correo": _controller.text.trim()}),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          setState(() => _codigoEnviado = true);
          GlobalSnackBars.mostrarExito(
            context,
            data['message'] ?? 'Código enviado a tu nuevo correo',
          );
        }
      } else {
        throw Exception(data['message'] ?? 'Error al enviar código');
      }
    } catch (e) {
      if (mounted) {
        GlobalSnackBars.mostrarError(context, 'Error: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _isEnviandoCodigo = false);
    }
  }

  Future<void> _guardarEnApi() async {
    setState(() => _isLoading = true);

    try {
      String nuevoDato = widget.teclado == TextInputType.phone
          ? _controller.text
          : _controller.text.trim();

      Map<String, dynamic> body = {
        "token_comprador": widget.tokenComprador,
        "token_dispositivo": widget.tokenDispositivo,
        "tipo_dato": _tipoDato,
        "nuevo_dato": nuevoDato,
        "dato_original": _originalValue,
      };

      if (widget.teclado == TextInputType.emailAddress) {
        if (widget.correoActual == null) {
          throw Exception('El correo actual es requerido para cambiar el email');
        }
        if (!_codigoEnviado) {
          throw Exception('Debes enviar y verificar el código primero');
        }
        body.addAll({
          "correo_comprador": widget.correoActual,
          "contrasenna_comprador": _passwordController.text,
          "codigo_seguridad": _codigoController.text,
        });
      }

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/EditarComprador/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          GlobalSnackBars.mostrarExito(
            context,
            data['message'] ?? 'Dato actualizado correctamente',
          );

          if (widget.teclado == TextInputType.emailAddress) {
            Navigator.pop(context, {
              'email': _controller.text,
              'password': _passwordController.text,
            });
          } else {
            String nuevoValor = widget.teclado == TextInputType.phone
                ? '+${_controller.text}'
                : _controller.text.trim();
            Navigator.pop(context, nuevoValor);
          }
        }
      } else {
        if (data['success'] == false && data['sesion_iniciada'] == false) {
          GlobalSnackBars.mostrarError(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          _reiniciarAplicacion();
          return;
        }
        throw Exception(data['message'] ?? 'Error al actualizar');
      }
    } catch (e) {
      if (mounted) {
        GlobalSnackBars.mostrarError(context, 'Error: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _reiniciarAplicacion() {
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  void _guardar() {
    if (_formKey.currentState!.validate()) {
      _guardarEnApi();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEmail = widget.teclado == TextInputType.emailAddress;

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
          widget.titulo,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _blueDarkColor,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
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
                            // Instrucciones contextuales
                            if (widget.teclado == TextInputType.phone)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Ingresa un número de teléfono válido',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            if (isEmail)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Para cambiar tu correo, ingresa el nuevo, tu contraseña y el código de verificación',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),

                            // Campos según tipo
                            if (widget.teclado == TextInputType.phone) ...[
                              TextFormField(
                                controller: _controller,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: GlobalInputStyles.inputDecoration(
                                  labelText: 'Teléfono',
                                  hintText: '56912345678',
                                  prefixIcon: Icons.phone_outlined,
                                ).copyWith(
                                  prefix: const Text('+ '), // Prefijo visual
                                ),
                                validator: _validarTelefono,
                              ),
                            ] else if (isEmail) ...[
                              // Nuevo correo
                              TextFormField(
                                controller: _controller,
                                keyboardType: TextInputType.emailAddress,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(RegExp(r'\s')),
                                ],
                                decoration: GlobalInputStyles.inputDecoration(
                                  labelText: 'Nuevo correo',
                                  hintText: 'ejemplo@correo.com',
                                  prefixIcon: Icons.email,
                                ),
                                validator: _validarEmail,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 16),
                              // Botón enviar código
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: (_isEnviandoCodigo || !_isEmailValid)
                                      ? null
                                      : _enviarCodigoVerificacion,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _blueDarkColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: _isEnviandoCodigo
                                      ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                      : Text(
                                    _codigoEnviado
                                        ? 'Reenviar código'
                                        : 'Enviar código de verificación',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              if (_codigoEnviado) ...[
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _codigoController,
                                  keyboardType: TextInputType.number,
                                  decoration: GlobalInputStyles.inputDecoration(
                                    labelText: 'Código de verificación',
                                    hintText: 'Ingresa el código recibido',
                                    prefixIcon: Icons.lock_outline,
                                  ),
                                  validator: _validarCodigo,
                                ),
                              ],
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: GlobalInputStyles.inputDecoration(
                                  labelText: 'Contraseña actual',
                                  hintText: 'Ingresa tu contraseña',
                                  prefixIcon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                      color: _blueDarkColor,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: _validarPassword,
                              ),
                            ] else ...[
                              // Alias
                              TextFormField(
                                controller: _controller,
                                keyboardType: TextInputType.text,
                                textCapitalization: TextCapitalization.words,
                                decoration: GlobalInputStyles.inputDecoration(
                                  labelText: 'Alias',
                                  hintText: 'Ingresa el nuevo alias',
                                  prefixIcon: Icons.person,
                                ),
                                validator: _validarAlias,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Botón Guardar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _guardar,
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
                      'Guardar',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
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
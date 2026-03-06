import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'variables_globales.dart'; // Importa estilos globales, color azul y snackbars

class PinCreationScreen extends StatefulWidget {
  final String tokenComprador;
  final String correoComprador;
  final String tokenDispositivo;
  final VoidCallback? onPinCreated;
  final bool crearPin; // true = crear, false = cambiar

  const PinCreationScreen({
    super.key,
    required this.tokenComprador,
    required this.correoComprador,
    required this.tokenDispositivo,
    this.onPinCreated,
    this.crearPin = true,
  });

  @override
  State<PinCreationScreen> createState() => _PinCreationScreenState();
}

class _PinCreationScreenState extends State<PinCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePin(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa un PIN';
    if (value.length != 4) return 'El PIN debe tener 4 dígitos';
    if (!RegExp(r'^\d{4}$').hasMatch(value)) return 'Solo se permiten números';
    return null;
  }

  String? _validateConfirmPin(String? value) {
    if (value == null || value.isEmpty) return 'Confirma tu PIN';
    if (value != _pinController.text) return 'Los PIN no coinciden';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
    return null;
  }

  Future<void> _crearPin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('${GlobalVariables.baseUrl}/CrearPinSeguridad/api/v1/');
      final body = json.encode({
        "token_comprador": widget.tokenComprador,
        "token_dispositivo": widget.tokenDispositivo,
        "correo_comprador": widget.correoComprador,
        "password_comprador": _passwordController.text,
        "pin_seguridad": _pinController.text,
      });

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': GlobalVariables.apiKey,
        },
        body: body,
      ).timeout(const Duration(seconds: 15));

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          GlobalSnackBars.mostrarExito(
            context,
            data['message'] ?? (widget.crearPin ? 'PIN creado exitosamente' : 'PIN actualizado exitosamente'),
          );
          widget.onPinCreated?.call();
          Navigator.pop(context);
        }
      } else {
        if (data['success'] == false && data['sesion_iniciada'] == false) {
          GlobalSnackBars.mostrarError(context, 'Sesión cerrada. Por favor, inicia sesión nuevamente.');
          _reiniciarAplicacion();
          return;
        }
        throw Exception(data['message'] ?? 'Error al procesar el PIN');
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

  @override
  Widget build(BuildContext context) {
    final String titulo = widget.crearPin ? 'Crear PIN de seguridad' : 'Cambiar PIN de seguridad';
    final String subtitulo = widget.crearPin
        ? 'Crea un PIN de 4 dígitos para operaciones sensibles'
        : 'Actualiza tu PIN de 4 dígitos';
    final String botonTexto = widget.crearPin ? 'Crear PIN' : 'Cambiar PIN';

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
          titulo,
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subtítulo
              Text(
                subtitulo,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),

              // Campo PIN
              TextFormField(
                controller: _pinController,
                obscureText: _obscurePin,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: GlobalInputStyles.inputDecoration(
                  labelText: 'PIN de 4 dígitos',
                  hintText: 'Ingresa tu PIN',
                  prefixIcon: Icons.pin,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePin ? Icons.visibility_off : Icons.visibility,
                      color: GlobalVariables.blueDarkColor,
                    ),
                    onPressed: () => setState(() => _obscurePin = !_obscurePin),
                  ),
                ),
                validator: _validatePin,
              ),

              const SizedBox(height: 16),

              // Confirmar PIN
              TextFormField(
                controller: _confirmPinController,
                obscureText: _obscureConfirmPin,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: GlobalInputStyles.inputDecoration(
                  labelText: 'Confirmar PIN',
                  hintText: 'Confirma tu PIN',
                  prefixIcon: Icons.pin,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirmPin ? Icons.visibility_off : Icons.visibility,
                      color: GlobalVariables.blueDarkColor,
                    ),
                    onPressed: () => setState(() => _obscureConfirmPin = !_obscureConfirmPin),
                  ),
                ),
                validator: _validateConfirmPin,
              ),

              const SizedBox(height: 16),

              // Contraseña actual
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: GlobalInputStyles.inputDecoration(
                  labelText: 'Contraseña actual',
                  hintText: 'Ingresa tu contraseña actual',
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: GlobalVariables.blueDarkColor,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: _validatePassword,
              ),

              const SizedBox(height: 32),

              // Botón de acción
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _crearPin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLoading ? Colors.grey.shade400 : GlobalVariables.blueDarkColor,
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
                      : Text(
                    botonTexto,
                    style: const TextStyle(
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
      ),
    );
  }
}
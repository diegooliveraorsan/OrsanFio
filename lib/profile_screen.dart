import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'codigo_verificacion_screen.dart';
import 'cambiar_contrasena_screen.dart';
import 'eliminar_cuenta_screen.dart';
import 'pin_creation_screen.dart';
import 'variables_globales.dart';
import 'editar_campo_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onLogout;
  final String? empresaSeleccionada;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onEditComplete;

  const ProfileScreen({
    super.key,
    required this.userData,
    required this.onLogout,
    this.empresaSeleccionada,
    this.onRefresh,
    this.onEditComplete,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isRefreshing = false;
  bool _empresaExpanded = false;
  bool _personalExpanded = false;
  bool _seguridadExpanded = false;

  final Color _blueDarkColor = GlobalVariables.blueDarkColor;
  final Color _approvedCardBackground = const Color(0xFFE8F0FE);

  Future<void> _onRefresh() async {
    GlobalVariables.debugPrint('🔄 Pull to refresh en ProfileScreen');
    setState(() => _isRefreshing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      GlobalVariables.debugPrint('❌ Error durante refresh: $e');
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Widget _buildRefreshableContent() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFF1976D2),
      backgroundColor: Colors.white,
      displacement: 40,
      edgeOffset: 0,
      child: _buildContent(),
    );
  }

  String _getTokenComprador() {
    try {
      return widget.userData['comprador']?['token_comprador'] ?? '';
    } catch (e) {
      return '';
    }
  }

  String _getUserEmail() {
    try {
      if (widget.userData['comprador'] != null &&
          widget.userData['comprador']['correo_comprador'] != null) {
        return widget.userData['comprador']['correo_comprador'].toString();
      }
    } catch (e) {
      GlobalVariables.debugPrint('Error obteniendo email: $e');
    }
    return '';
  }

  String? _getTokenDispositivo() {
    try {
      if (widget.userData['dispositivo_actual'] != null &&
          widget.userData['dispositivo_actual']['token_dispositivo'] != null) {
        return widget.userData['dispositivo_actual']['token_dispositivo'].toString();
      }
      if (widget.userData['dispositivos'] != null) {
        final dispositivos = widget.userData['dispositivos'] as List;
        if (dispositivos.isNotEmpty) {
          return dispositivos.first['token_dispositivo']?.toString();
        }
      }
    } catch (e) {
      GlobalVariables.debugPrint('Error obteniendo token dispositivo: $e');
    }
    return null;
  }

  // Diálogo para editar alias o teléfono
  Future<void> _mostrarDialogoEditar(String campo, String valorActual) async {
    String titulo = campo == 'alias' ? 'Editar Alias' : 'Editar Teléfono';
    String label = campo == 'alias' ? 'Nuevo alias' : 'Nuevo teléfono';
    TextInputType teclado = campo == 'alias' ? TextInputType.text : TextInputType.phone;
    String tipoDato = campo == 'alias' ? '3' : '1'; // 1: teléfono, 3: alias

    final token = _getTokenComprador();
    if (token.isEmpty) {
      _mostrarError('Error: No se pudo obtener el token de sesión');
      return;
    }

    final tokenDispositivo = _getTokenDispositivo();
    if (tokenDispositivo == null || tokenDispositivo.isEmpty) {
      _mostrarError('Error: No se pudo obtener el token del dispositivo');
      return;
    }

    TextEditingController controller = TextEditingController(text: valorActual);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isLoading = false;

            Future<void> guardar() async {
              if (!formKey.currentState!.validate()) return;

              String nuevoDato;
              if (campo == 'telefono') {
                String digits = controller.text.replaceAll(RegExp(r'[^\d]'), '');
                if (digits.length < 11) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('El teléfono debe tener al menos 11 dígitos'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                nuevoDato = digits;
              } else {
                nuevoDato = controller.text.trim();
              }

              setDialogState(() => isLoading = true);

              try {
                final response = await http.post(
                  Uri.parse('${GlobalVariables.baseUrl}/EditarComprador/api/v1/'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'api-key': GlobalVariables.apiKey,
                  },
                  body: json.encode({
                    "token_comprador": token,
                    "token_dispositivo": tokenDispositivo,
                    "tipo_dato": tipoDato,
                    "nuevo_dato": nuevoDato,
                    "dato_original": valorActual,
                  }),
                ).timeout(const Duration(seconds: 15));

                final data = json.decode(response.body);

                if (response.statusCode == 200 && data['success'] == true) {
                  Navigator.of(context).pop(); // Cerrar diálogo
                  GlobalSnackBars.mostrarExito(
                    context,
                    data['message'] ?? 'Dato actualizado correctamente',
                  );

                  if (widget.onRefresh != null) await widget.onRefresh!();
                  widget.onEditComplete?.call();
                } else {
                  if (data['success'] == false && data['sesion_iniciada'] == false) {
                    GlobalSnackBars.mostrarError(
                      context,
                      'Sesión cerrada. Por favor, inicia sesión nuevamente.',
                    );
                    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                    return;
                  }
                  throw Exception(data['message'] ?? 'Error al actualizar');
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setDialogState(() => isLoading = false);
              }
            }

            return AlertDialog(
              title: Text(
                titulo,
                style: TextStyle(color: _blueDarkColor, fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (campo == 'telefono')
                      TextFormField(
                        controller: controller,
                        keyboardType: teclado,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: GlobalInputStyles.inputDecoration(
                          labelText: label,
                          hintText: '56912345678',
                          prefixIcon: Icons.phone_outlined,
                        ).copyWith(prefix: const Text('+ ')),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Ingresa el teléfono';
                          if (value.length < 11) return 'Mínimo 11 dígitos';
                          return null;
                        },
                      )
                    else
                      TextFormField(
                        controller: controller,
                        keyboardType: teclado,
                        decoration: GlobalInputStyles.inputDecoration(
                          labelText: label,
                          hintText: 'Nuevo alias',
                          prefixIcon: Icons.person,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'El alias no puede estar vacío';
                          }
                          return null;
                        },
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : guardar,
                  style: ElevatedButton.styleFrom(backgroundColor: _blueDarkColor),
                  child: isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _navegarAEditar(String campo, String valorActual) async {
    if (campo == 'alias' || campo == 'telefono') {
      await _mostrarDialogoEditar(campo, valorActual);
      return;
    }

    // Para email, usar pantalla completa
    String titulo;
    String label;
    TextInputType teclado;

    switch (campo) {
      case 'email':
        titulo = 'Editar Correo Electrónico';
        label = 'Nuevo correo';
        teclado = TextInputType.emailAddress;
        break;
      default:
        return;
    }

    final token = _getTokenComprador();
    if (token.isEmpty) {
      _mostrarError('Error: No se pudo obtener el token de sesión');
      return;
    }

    final tokenDispositivo = _getTokenDispositivo();
    if (tokenDispositivo == null || tokenDispositivo.isEmpty) {
      _mostrarError('Error: No se pudo obtener el token del dispositivo');
      return;
    }

    final result = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => EditarCampoScreen(
          titulo: titulo,
          label: label,
          valorInicial: valorActual,
          teclado: teclado,
          tokenComprador: token,
          correoActual: campo == 'email' ? valorActual : null,
          tokenDispositivo: tokenDispositivo,
        ),
      ),
    );

    if (result != null) {
      if (widget.onRefresh != null) await widget.onRefresh!();
      widget.onEditComplete?.call();
    }
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _blueDarkColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: _blueDarkColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final empresaData = _getEmpresaData();
    final bool esRelacionValida = _esRelacionValida();
    final int userStatus = _getUserStatus();
    final bool mostrarInfoVerificada = userStatus >= 3;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isRefreshing)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1976D2),
                  ),
                ),
              ),
            ),

          // Sección Información de empresa (colapsable)
          if (mostrarInfoVerificada && empresaData != null) ...[
            _buildSectionHeader(
              title: 'Información de empresa',
              subtitle: 'Datos de la empresa seleccionada',
              isExpanded: _empresaExpanded,
              onTap: () => setState(() => _empresaExpanded = !_empresaExpanded),
            ),
            if (_empresaExpanded) ...[
              const SizedBox(height: 8),
              _buildInfoCard(
                children: [
                  if (esRelacionValida) ...[
                    _buildInfoItemConIcono(
                      icon: Icons.business,
                      label: 'Empresa',
                      value: _getNombreEmpresa(),
                      color: _blueDarkColor,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildInfoItemConIcono(
                    icon: Icons.numbers,
                    label: 'RUT',
                    value: _getEmpresaRut(),
                    color: _blueDarkColor,
                  ),
                  const SizedBox(height: 16),
                  _buildRelacionItem(esValida: esRelacionValida, color: _blueDarkColor),
                ],
              ),
              const SizedBox(height: 30),
            ] else
              const SizedBox(height: 30),
          ],
          const Divider(color: Colors.grey, thickness: 1),
          const SizedBox(height: 20),
          // Sección Información personal (colapsable)
          _buildSectionHeader(
            title: 'Información personal',
            subtitle: 'Datos de tu cuenta',
            isExpanded: _personalExpanded,
            onTap: () => setState(() => _personalExpanded = !_personalExpanded),
          ),
          if (_personalExpanded) ...[
            const SizedBox(height: 8),
            _buildInfoCard(
              children: [
                _buildInfoItemConIcono(
                  icon: Icons.person_outline,
                  label: 'Alias',
                  value: _getUserName(),
                  color: _blueDarkColor,
                  trailing: IconButton(
                    icon: Icon(Icons.edit, color: _blueDarkColor, size: 20),
                    onPressed: () => _navegarAEditar('alias', _getUserName()),
                  ),
                ),
                if (mostrarInfoVerificada) ...[
                  const SizedBox(height: 16),
                  _buildInfoItemConIcono(
                    icon: Icons.person,
                    label: 'Nombre',
                    value: _getUserFullName(),
                    color: _blueDarkColor,
                  ),
                ],
                if (mostrarInfoVerificada) ...[
                  const SizedBox(height: 16),
                  _buildInfoItemConIcono(
                    icon: Icons.badge,
                    label: 'RUN',
                    value: _getUserRun(),
                    color: _blueDarkColor,
                  ),
                ],
                const SizedBox(height: 16),
                _buildInfoItemConIcono(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: _getUserEmail(),
                  color: _blueDarkColor,
                  // trailing: IconButton(...) // Comentado
                ),
                const SizedBox(height: 16),
                _buildInfoItemConIcono(
                  icon: Icons.phone_outlined,
                  label: 'Teléfono',
                  value: "+" + _getUserPhone(),
                  color: _blueDarkColor,
                  trailing: IconButton(
                    icon: Icon(Icons.edit, color: _blueDarkColor, size: 20),
                    onPressed: () => _navegarAEditar('telefono', _getUserPhone()),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoItemConIcono(
                  icon: Icons.verified_user_outlined,
                  label: 'Estado de cuenta',
                  value: _getAccountStatus(),
                  color: _blueDarkColor,
                ),
              ],
            ),
            const SizedBox(height: 30),
          ] else
            const SizedBox(height: 30),

          const Divider(color: Colors.grey, thickness: 1),
          const SizedBox(height: 20),

          // Sección Seguridad (colapsable)
          _buildSectionHeader(
            title: 'Seguridad',
            subtitle: 'Opciones de seguridad de tu cuenta',
            isExpanded: _seguridadExpanded,
            onTap: () => setState(() => _seguridadExpanded = !_seguridadExpanded),
          ),
          if (_seguridadExpanded) ...[
            const SizedBox(height: 8),
            _buildSecurityCard(
              icon: Icons.lock_outline,
              title: 'Cambiar contraseña',
              subtitle: 'Usando tu contraseña actual',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CambiarContrasenaScreen(
                      tokenComprador: _getTokenComprador(),
                      email: _getUserEmail(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildSecurityCard(
              icon: Icons.email_outlined,
              title: 'Recuperar contraseña',
              subtitle: 'Recibir código al correo electrónico',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CodigoVerificacionScreen(
                      tokenComprador: _getTokenComprador(),
                      email: _getUserEmail(),
                      esReenvio: false,
                    ),
                  ),
                );
              },
            ),
            if (userStatus >= 4)
              _buildSecurityCard(
                icon: Icons.password_outlined,
                title: 'Cambiar pin de seguridad',
                subtitle: 'Actualizar tu PIN de 4 dígitos',
                onTap: () {
                  final tokenComprador = _getTokenComprador();
                  final correoComprador = _getUserEmail();
                  final tokenDispositivo = _getTokenDispositivo();

                  if (tokenComprador.isEmpty || correoComprador.isEmpty || tokenDispositivo == null) {
                    _mostrarError('Error: No se pudo obtener la información necesaria');
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PinCreationScreen(
                        tokenComprador: tokenComprador,
                        correoComprador: correoComprador,
                        tokenDispositivo: tokenDispositivo,
                        onPinCreated: () {
                          if (widget.onRefresh != null) widget.onRefresh!();
                        },
                        crearPin: false,
                      ),
                    ),
                  );
                },
              ),
            _buildSecurityCard(
              icon: Icons.privacy_tip_outlined,
              title: 'Políticas de privacidad',
              subtitle: 'Consulta nuestras políticas de privacidad',
              onTap: _abrirPoliticasPrivacidad,
            ),
            const SizedBox(height: 12),
            _buildSecurityCard(
              icon: Icons.delete_forever_outlined,
              title: 'Eliminar cuenta',
              subtitle: 'Eliminar permanentemente tu cuenta',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EliminarCuentaScreen(
                      tokenComprador: _getTokenComprador(),
                      email: _getUserEmail(),
                      userRun: _getUserRun(),
                      userName: _getUserName(),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),
          ] else
            const SizedBox(height: 30),

          const Divider(color: Colors.grey, thickness: 1),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: widget.onLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blueDarkColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
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
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _approvedCardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ),
    );
  }

  Widget _buildInfoItemConIcono({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _buildRelacionItem({required bool esValida, required Color color}) {
    final String texto = _getRelacion();
    final Color iconColor = esValida ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
    final IconData icon = esValida ? Icons.check_circle : Icons.cancel;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.group, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Relación', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(texto,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
            ],
          ),
        ),
        Icon(icon, color: iconColor, size: 20),
      ],
    );
  }

  Widget _buildSecurityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 3,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _approvedCardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _blueDarkColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _blueDarkColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: _blueDarkColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getUserName() {
    try {
      if (widget.userData['comprador'] != null && widget.userData['comprador']['alias_comprador'] != null) {
        return widget.userData['comprador']['alias_comprador'].toString();
      }
      if (widget.userData['comprador'] != null && widget.userData['comprador']['correo_comprador'] != null) {
        String email = widget.userData['comprador']['correo_comprador'].toString();
        return email.split('@').first;
      }
    } catch (e) {
      GlobalVariables.debugPrint('Error obteniendo nombre: $e');
    }
    return 'Usuario';
  }

  String _getUserFullName() {
    try {
      if (widget.userData['comprador'] != null && widget.userData['comprador']['nombre_comprador'] != null) {
        return widget.userData['comprador']['nombre_comprador'].toString();
      }
    } catch (e) {
      GlobalVariables.debugPrint('Error obteniendo nombre completo: $e');
    }
    return 'No disponible';
  }

  String _getUserRun() {
    try {
      if (widget.userData['comprador'] != null &&
          widget.userData['comprador']['run_comprador'] != null &&
          widget.userData['comprador']['dv_run_comprador'] != null) {
        String run = widget.userData['comprador']['run_comprador'].toString();
        String dv = widget.userData['comprador']['dv_run_comprador'].toString();

        if (run.length >= 7) {
          if (run.length == 7) {
            return '${run.substring(0, 1)}.${run.substring(1, 4)}.${run.substring(4, 7)}-$dv';
          } else if (run.length == 8) {
            return '${run.substring(0, 2)}.${run.substring(2, 5)}.${run.substring(5, 8)}-$dv';
          } else if (run.length == 9) {
            return '${run.substring(0, 3)}.${run.substring(3, 6)}.${run.substring(6, 9)}-$dv';
          }
        }
        return '$run-$dv';
      }
    } catch (e) {
      GlobalVariables.debugPrint('Error obteniendo RUN: $e');
    }
    return 'No disponible';
  }

  String _getUserPhone() {
    try {
      if (widget.userData['comprador'] != null && widget.userData['comprador']['telefono_comprador'] != null) {
        return widget.userData['comprador']['telefono_comprador'].toString();
      }
    } catch (e) {
      GlobalVariables.debugPrint('Error obteniendo teléfono: $e');
    }
    return 'No disponible';
  }

  String _getAccountStatus() {
    try {
      if (widget.userData['comprador'] != null && widget.userData['comprador']['estado_comprador'] != null) {
        int estado = widget.userData['comprador']['estado_comprador'] as int;
        switch (estado) {
          case 1:
            return 'Pendiente verificación email';
          case 2:
            return 'Pendiente verificación cuenta';
          case 3:
            return 'Verificada (PIN pendiente)';
          case 4:
            return 'Verificada';
          default:
            return 'Pendiente';
        }
      }
    } catch (e) {
      GlobalVariables.debugPrint('Error obteniendo estado: $e');
    }
    return 'Pendiente';
  }

  int _getUserStatus() {
    try {
      if (widget.userData['comprador'] != null && widget.userData['comprador']['estado_comprador'] != null) {
        return widget.userData['comprador']['estado_comprador'] as int;
      }
    } catch (e) {
      GlobalVariables.debugPrint('Error obteniendo estado numérico: $e');
    }
    return 1;
  }

  Map<String, dynamic>? _getEmpresaData() {
    if (widget.empresaSeleccionada == null) return null;
    try {
      final empresas = widget.userData['empresas'] ?? [];
      for (final emp in empresas) {
        if (emp['token_empresa'] == widget.empresaSeleccionada) {
          return emp;
        }
      }
      return null;
    } catch (e) {
      GlobalVariables.debugPrint('Error obteniendo datos de empresa: $e');
      return null;
    }
  }

  String _getEmpresaRut() {
    final empresa = _getEmpresaData();
    if (empresa != null) {
      final rut = empresa['rut_empresa']?.toString() ?? '';
      final dv = empresa['dv_rut_empresa']?.toString() ?? '';

      if (rut.length >= 7) {
        if (rut.length == 7) {
          return '${rut.substring(0, 1)}.${rut.substring(1, 4)}.${rut.substring(4, 7)}-$dv';
        } else if (rut.length == 8) {
          return '${rut.substring(0, 2)}.${rut.substring(2, 5)}.${rut.substring(5, 8)}-$dv';
        }
      }
      return '$rut-$dv';
    }
    return 'No disponible';
  }

  bool _esRelacionValida() {
    final empresa = _getEmpresaData();
    if (empresa != null) {
      final validez = empresa['validez_relacion']?.toString() ?? '';
      return validez.toLowerCase() == 'válida';
    }
    return false;
  }

  String _getNombreEmpresa() {
    final empresa = _getEmpresaData();
    if (empresa != null) {
      final nombreEmpresa = empresa['nombre_empresa']?.toString();
      if (nombreEmpresa != null && nombreEmpresa.isNotEmpty) {
        return nombreEmpresa;
      }
      final rut = empresa['rut_empresa']?.toString() ?? '';
      final dv = empresa['dv_rut_empresa']?.toString() ?? '';
      if (rut.isNotEmpty) {
        return 'Empresa $rut-$dv';
      }
    }
    return 'No disponible';
  }

  String _getRelacion() {
    final empresa = _getEmpresaData();
    if (empresa != null) {
      final tipoRelacion = empresa['tipo_relacion']?.toString();
      if (tipoRelacion != null && tipoRelacion.isNotEmpty) {
        return tipoRelacion;
      }
    }
    return 'No disponible';
  }

  Future<void> _abrirPoliticasPrivacidad() async {
    const url = 'https://www.orsanevaluaciones.cl/politica-de-privacidad-aplicacion-fio-2/';
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        _mostrarError('No se puede abrir la página de políticas de privacidad');
      }
    } catch (e) {
      GlobalVariables.debugPrint('❌ Error al abrir políticas de privacidad: $e');
      _mostrarError('Error al abrir la página');
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: null,
      body: _buildRefreshableContent(),
    );
  }
}
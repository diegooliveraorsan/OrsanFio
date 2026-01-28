import 'package:flutter/material.dart';
import 'codigo_verificacion_screen.dart';
import 'cambiar_contrasena_screen.dart';
import 'cambiar_pin_seguridad_screen.dart';
import 'eliminar_cuenta_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onLogout;
  final String? empresaSeleccionada;
  final VoidCallback? onRefresh;

  const ProfileScreen({
    super.key,
    required this.userData,
    required this.onLogout,
    this.empresaSeleccionada,
    this.onRefresh,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isRefreshing = false;

  // ✅ COLOR AZUL OSCURO (MISMO QUE VENTAS APROBADAS) - solo para botones e íconos
  final Color _blueDarkColor = const Color(0xFF0055B8);

  // ✅ COLOR DE FONDO DE TARJETAS APROBADAS (EXTRAÍDO DE SalesHistoryScreen)
  final Color _approvedCardBackground = const Color(0xFFE8F0FE);

  // ✅ Método para pull-to-refresh
  Future<void> _onRefresh() async {
    print('🔄 Pull to refresh en ProfileScreen');

    setState(() {
      _isRefreshing = true;
    });

    try {
      // ✅ SOLO ACTUALIZAR DATOS LOCALES, NO LLAMAR AL REFRESH DEL PADRE
      // Si necesitas datos actualizados del servidor, haz una llamada API directa aquí
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      print('❌ Error durante refresh: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  // ✅ Widget con pull-to-refresh
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

  // ✅ Métodos para obtener token y email
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
      print('Error obteniendo email: $e');
    }
    return '';
  }

  // ✅ Contenido principal del perfil
  Widget _buildContent() {
    final empresaData = _getEmpresaData();
    final bool esRelacionValida = _esRelacionValida();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Indicador de refresh manual
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

          // ✅ SECCIÓN DE EMPRESA CON FONDO DE TARJETAS APROBADAS
          if (showVerifiedInfo && empresaData != null) ...[
            Text(
              'Información de empresa',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _blueDarkColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Datos de la empresa seleccionada',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            // ✅ TARJETA CON FONDO AZUL CLARO (#E8F0FE) como ventas aprobadas
            _buildInfoCard(
              children: [
                // ✅ MOSTRAR NOMBRE SOLO SI LA RELACIÓN ES VÁLIDA
                if (esRelacionValida) ...[
                  _buildInfoItemConIcono(
                    icon: Icons.business,
                    label: 'Empresa',
                    value: _getNombreEmpresa(),
                    color: _blueDarkColor,
                  ),
                  const SizedBox(height: 16),
                ],

                // ✅ SIEMPRE MOSTRAR RUT
                _buildInfoItemConIcono(
                  icon: Icons.numbers,
                  label: 'RUT',
                  value: _getEmpresaRut(),
                  color: _blueDarkColor,
                ),
                const SizedBox(height: 16),

                // ✅ RELACIÓN CON COLOR AZUL Y CHECK/CRUZ A LA DERECHA
                _buildRelacionItem(
                  esValida: esRelacionValida,
                  color: _blueDarkColor,
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],

          // ✅ SECCIÓN DE INFORMACIÓN PERSONAL CON MISMO FONDO
          if (showVerifiedInfo) ...[
            Text(
              'Información personal verificada',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _blueDarkColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Datos validados mediante verificación de identidad',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            // ✅ TARJETA CON MISMO FONDO AZUL CLARO
            _buildInfoCard(
              children: [
                _buildInfoItemConIcono(
                  icon: Icons.person,
                  label: 'Nombre',
                  value: _getUserFullName(),
                  color: _blueDarkColor,
                ),
                const SizedBox(height: 16),
                _buildInfoItemConIcono(
                  icon: Icons.badge,
                  label: 'RUN',
                  value: _getUserRun(),
                  color: _blueDarkColor,
                ),
              ],
            ),
            const SizedBox(height: 30),
          ],

          // ✅ Información Personal - AHORA SOLO UNA TARJETA CON LAS 4 SECCIONES
          Text(
            'Información personal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _blueDarkColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Datos de tu cuenta',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),

          // ✅ UNA SOLA TARJETA CON LAS 4 SECCIONES DENTRO
          _buildInfoCard(
            children: [
              // ✅ ALIAS
              _buildInfoItemConIcono(
                icon: Icons.person_outline,
                label: 'Alias',
                value: _getUserName(),
                color: _blueDarkColor,
              ),
              const SizedBox(height: 16),

              // ✅ EMAIL
              _buildInfoItemConIcono(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _getUserEmail(),
                color: _blueDarkColor,
              ),
              const SizedBox(height: 16),

              // ✅ TELÉFONO
              _buildInfoItemConIcono(
                icon: Icons.phone_outlined,
                label: 'Teléfono',
                value: _getUserPhone(),
                color: _blueDarkColor,
              ),
              const SizedBox(height: 16),

              // ✅ ESTADO DE CUENTA
              _buildInfoItemConIcono(
                icon: Icons.verified_user_outlined,
                label: 'Estado de cuenta',
                value: _getAccountStatus(),
                color: _blueDarkColor,
              ),
            ],
          ),

          const SizedBox(height: 30),
          const Divider(color: Colors.grey, thickness: 1),
          const SizedBox(height: 20),

          // ✅ SEGURIDAD - AHORA CON DISEÑO DE TARJETAS AZULES
          Text(
            'Seguridad',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _blueDarkColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Opciones de seguridad de tu cuenta',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),

          // OPCIÓN 1: Cambiar contraseña con contraseña antigua - AHORA COMO TARJETA
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

          // OPCIÓN 2: Cambiar contraseña con código de verificación - AHORA COMO TARJETA
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

          const SizedBox(height: 12),

          /*
          // ✅ NUEVA TARJETA: CAMBIAR PIN DE SEGURIDAD
          _buildSecurityCard(
            icon: Icons.password_outlined,
            title: 'Cambiar pin de seguridad',
            subtitle: 'Actualizar código de 4 dígitos',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CambiarPinSeguridadScreen(
                    tokenComprador: _getTokenComprador(),
                    email: _getUserEmail(),
                    userRun: _getUserRun(),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),
          */

          _buildSecurityCard(
            icon: Icons.privacy_tip_outlined,
            title: 'Políticas de privacidad',
            subtitle: 'Consulta nuestras políticas de privacidad',
            onTap: () {
              _abrirPoliticasPrivacidad();
            },
          ),

          const SizedBox(height: 12),

          // ✅ NUEVA TARJETA: ELIMINAR CUENTA
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
          const Divider(color: Colors.grey, thickness: 1),
          const SizedBox(height: 20),

          // ✅ BOTÓN DE CERRAR SESIÓN (EN AZUL OSCURO #0055B8)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: widget.onLogout,
              style: ElevatedButton.styleFrom(
                backgroundColor: _blueDarkColor, // ← Mismo azul oscuro
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ✅ MÉTODO PARA CONSTRUIR TARJETA CON DISEÑO UNIFORME (ACTUALIZADO CON SOGMAsa)
  Widget _buildInfoCard({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16), // ✅ ESPACIO ENTRE TARJETAS
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3), // ✅ MISMA SOMBRA QUE SALES HISTORY
            blurRadius: 3,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero, // ✅ SIN MARGEN INTERNO PARA QUE EL SHADOW SEA VISIBLE
        elevation: 0, // ✅ SIN ELEVACIÓN, USAMOS EL SHADOW DEL CONTAINER
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none, // ✅ SIN BORDE ADICIONAL
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _approvedCardBackground, // ← FONDO AZUL CLARO (#E8F0FE)
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ),
    );
  }

  // ✅ MÉTODO PARA CONSTRUIR ÍTEMS CON ICONO (DATOS EN NEGRO)
  Widget _buildInfoItemConIcono({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
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
          child: Icon(
            icon,
            color: color, // ← ÍCONO EN AZUL OSCURO
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey, // ← SUBTÍTULO EN GRIS
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black, // ← TÍTULO EN NEGRO
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ MÉTODO PARA RELACIÓN CON ICONO Y CHECK/CRUZ A LA DERECHA (DATOS EN AZUL)
  Widget _buildRelacionItem({
    required bool esValida,
    required Color color,
  }) {
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
          child: Icon(
            Icons.group, // ← Icono de grupo (relación)
            color: color, // ← ÍCONO EN AZUL OSCURO
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Relación',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                texto,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black, // ← TEXTO EN NEGRO
                ),
              ),
            ],
          ),
        ),
        // ✅ CHECK/CRUZ SOLO AQUÍ (a la derecha)
        Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ],
    );
  }

  // ✅ NUEVO: Widget para opción de seguridad CON DISEÑO DE TARJETA AZUL (ACTUALIZADO CON SOGMAsa)
  Widget _buildSecurityCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), // ✅ ESPACIO ENTRE TARJETAS
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3), // ✅ MISMA SOMBRA QUE SALES HISTORY
            blurRadius: 3,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero, // ✅ SIN MARGEN INTERNO PARA QUE EL SHADOW SEA VISIBLE
        elevation: 0, // ✅ SIN ELEVACIÓN, USAMOS EL SHADOW DEL CONTAINER
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none, // ✅ SIN BORDE ADICIONAL
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _approvedCardBackground, // ← MISMO FONDO AZUL CLARO
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _blueDarkColor.withOpacity(0.1), // ← FONDO AZUL CLARITO
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: _blueDarkColor, // ← ÍCONO EN AZUL OSCURO
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black, // ← TÍTULO EN NEGRO
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey, // ← SUBTÍTULO EN GRIS
                        ),
                      ),
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

  // ✅ GETTERS y métodos existentes
  bool get showVerifiedInfo => _getUserStatus() >= 3;

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
      print('Error obteniendo nombre: $e');
    }
    return 'Usuario';
  }

  String _getUserFullName() {
    try {
      if (widget.userData['comprador'] != null && widget.userData['comprador']['nombre_comprador'] != null) {
        return widget.userData['comprador']['nombre_comprador'].toString();
      }
    } catch (e) {
      print('Error obteniendo nombre completo: $e');
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
      print('Error obteniendo RUN: $e');
    }
    return 'No disponible';
  }

  String _getUserPhone() {
    try {
      if (widget.userData['comprador'] != null && widget.userData['comprador']['telefono_comprador'] != null) {
        return widget.userData['comprador']['telefono_comprador'].toString();
      }
    } catch (e) {
      print('Error obteniendo teléfono: $e');
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
            return 'Verificada';
          default:
            return 'Pendiente';
        }
      }
    } catch (e) {
      print('Error obteniendo estado: $e');
    }
    return 'Pendiente';
  }

  int _getUserStatus() {
    try {
      if (widget.userData['comprador'] != null && widget.userData['comprador']['estado_comprador'] != null) {
        return widget.userData['comprador']['estado_comprador'] as int;
      }
    } catch (e) {
      print('Error obteniendo estado numérico: $e');
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
      print('Error obteniendo datos de empresa: $e');
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
    print(empresa);
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
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } else {
        _mostrarError('No se puede abrir la página de políticas de privacidad');
      }
    } catch (e) {
      print('❌ Error al abrir políticas de privacidad: $e');
      _mostrarError('Error al abrir la página');
    }
  }

// ✅ Método auxiliar para mostrar errores (si no lo tienes ya)
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
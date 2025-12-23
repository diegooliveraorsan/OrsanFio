import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../document_reader/document_reader_service.dart';
import '../face_api/face_api_service.dart';
import '../dashboard_screen.dart';
import '../variables_globales.dart';

// Clase de utilidades para RUT chileno
class RutUtils {
  static String formatRut(String rut) {
    String cleanRut = rut.replaceAll('.', '').replaceAll('-', '');

    if (cleanRut.length < 2) return rut;

    String numero = cleanRut.substring(0, cleanRut.length - 1);
    String dv = cleanRut.substring(cleanRut.length - 1);

    String formatted = '';
    for (int i = numero.length - 1, j = 0; i >= 0; i--, j++) {
      if (j > 0 && j % 3 == 0) {
        formatted = '.$formatted';
      }
      formatted = numero[i] + formatted;
    }

    return '$formatted-$dv'.toUpperCase();
  }

  static bool validateRut(String rut) {
    if (rut.isEmpty) return false;

    try {
      String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').toUpperCase();

      // ✅ VALIDACIÓN: RUT DEBE TENER AL MENOS 8 DÍGITOS (sin contar el DV)
      if (cleanRut.length < 9) return false; // Mínimo 8 dígitos + 1 DV

      String numero = cleanRut.substring(0, cleanRut.length - 1);
      String dv = cleanRut.substring(cleanRut.length - 1);

      // ✅ VALIDACIÓN: EL NÚMERO DEBE TENER AL MENOS 8 DÍGITOS
      if (numero.length < 8) return false;

      if (int.tryParse(numero) == null) return false;

      String expectedDv = _calculateDv(numero);

      return dv == expectedDv;
    } catch (e) {
      return false;
    }
  }

  static String _calculateDv(String numero) {
    int suma = 0;
    int multiplicador = 2;

    for (int i = numero.length - 1; i >= 0; i--) {
      suma += int.parse(numero[i]) * multiplicador;
      multiplicador = multiplicador == 7 ? 2 : multiplicador + 1;
    }

    int resto = suma % 11;
    String dv = (11 - resto).toString();

    if (dv == '11') return '0';
    if (dv == '10') return 'K';
    return dv;
  }

  static Map<String, String> parseRut(String rut) {
    String cleanRut = rut.replaceAll('.', '').replaceAll('-', '').toUpperCase();
    if (cleanRut.length < 2) return {'numero': '', 'dv': ''};

    String numero = cleanRut.substring(0, cleanRut.length - 1);
    String dv = cleanRut.substring(cleanRut.length - 1);

    return {'numero': numero, 'dv': dv};
  }
}

// ✅ COLOR AZUL OSCURO (MISMO QUE EN OTRAS VISTAS)
const Color _blueDarkColor = Color(0xFF0055B8);
const Color _approvedCardBackground = Color(0xFFE8F0FE);

// ✅ PANTALLA DE CONFIRMACIÓN ANTES DEL ESCANEO
class ScanConfirmationScreen extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const ScanConfirmationScreen({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo FIO
              Image.asset(
                'assets/images/logo_fio.png',
                height: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),

              // Icono de cámara
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _blueDarkColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _blueDarkColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 50,
                  color: _blueDarkColor,
                ),
              ),
              const SizedBox(height: 32),

              // Título
              Text(
                'Verificación de Identidad',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _blueDarkColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Descripción
              const Text(
                'A continuación se realizará:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 20),

              // Pasos del proceso
              _buildStep(
                number: 1,
                title: 'Escaneo de Carnet de Identidad',
                description: 'Escanearemos ambas caras de su documento',
              ),
              const SizedBox(height: 16),
              _buildStep(
                number: 2,
                title: 'Verificación Facial',
                description: 'Captura biométrica de su rostro',
              ),
              const SizedBox(height: 32),

              // Recomendaciones
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.grey.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Recomendaciones:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildRecommendation('Busque un lugar bien iluminado'),
                    _buildRecommendation('Evite sombras en su rostro'),
                    _buildRecommendation('Mantenga el documento sin reflejos'),
                    _buildRecommendation('Asegúrese de que la cámara esté limpia'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onCancel,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blueDarkColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text('Continuar'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep({
    required int number,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blueDarkColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blueDarkColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _blueDarkColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
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
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendation(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle,
            size: 6,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrsanfioHome extends StatefulWidget {
  final Map<String, dynamic> userData;

  const OrsanfioHome({super.key, required this.userData});

  @override
  State<OrsanfioHome> createState() => _OrsanfioHomeState();
}

class _OrsanfioHomeState extends State<OrsanfioHome> with WidgetsBindingObserver, TickerProviderStateMixin {
  final DocumentReaderService _documentService = DocumentReaderService();
  late FaceApiService _faceService;

  String _documentStatus = 'No escaneado';
  String _faceStatus = 'No capturado';
  bool _isLoading = false;
  String _currentStep = 'Complete las verificaciones para solicitar línea de crédito';
  Map<String, dynamic>? _lastDocumentResult;
  Map<String, dynamic>? _lastFaceResult;

  final TextEditingController _rutController = TextEditingController();
  String _rutError = '';

  // ✅ NUEVO: SELECTOR DE TIPO DE RELACIÓN
  String? _tipoRelacionSeleccionada; // 'autorizador' o 'representante'

  // ✅ Controlador para manejar la animación localmente
  late AnimationController _loadingController;
  OverlayEntry? _loadingOverlayEntry;
  bool _showLocalLoading = false;

  // ✅ FOCUS NODE PARA EL CAMPO RUT
  final FocusNode _rutFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _faceService = FaceApiService();

    // ✅ INICIALIZAR CONTROLADOR DE ANIMACIÓN LOCAL
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    print('🚀 REGISTRO INICIADO - Widget montado: $mounted');
    print('📊 Estado comprador recibido: ${widget.userData['comprador']?['estado_comprador']}');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        print('✅ Contexto de registro confirmado como montado');
      } else {
        print('❌ Contexto de registro NO está montado en post-frame');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadingController.dispose();
    _removeLoadingOverlay(); // ✅ LIMPIAR OVERLAY
    _rutController.dispose();
    _rutFocusNode.dispose(); // ✅ DISPOSE DEL FOCUS NODE
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 AppLifecycleState cambiado: $state');
  }

  // ✅ MÉTODO PARA MOSTRAR PANTALLA DE CONFIRMACIÓN
  void _showScanConfirmation() {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanConfirmationScreen(
          onConfirm: () {
            Navigator.pop(context);
            _scanDocument();
          },
          onCancel: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ✅ MOSTRAR ANIMACIÓN LOCAL
  void _showLocalLoadingAnimation() {
    if (!mounted) return;

    setState(() {
      _showLocalLoading = true;
    });

    _loadingController.repeat();

    _loadingOverlayEntry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _blueDarkColor.withOpacity(0.8), width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: AnimatedBuilder(
                  animation: _loadingController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _loadingController.value * 2 * 3.14159,
                      child: Image.asset(
                        'assets/images/logo_orsan.png',
                        width: 40,
                        height: 40,
                        color: _blueDarkColor.withOpacity(0.8),
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.autorenew,
                          size: 40,
                          color: _blueDarkColor.withOpacity(0.8),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_loadingOverlayEntry!);
  }

  // ✅ OCULTAR ANIMACIÓN LOCAL
  void _hideLocalLoadingAnimation() {
    if (_loadingOverlayEntry != null) {
      _loadingOverlayEntry!.remove();
      _loadingOverlayEntry = null;
    }

    _loadingController.stop();

    if (mounted) {
      setState(() {
        _showLocalLoading = false;
      });
    }
  }

  // ✅ MÉTODO PARA LIMPIAR OVERLAY
  void _removeLoadingOverlay() {
    if (_loadingOverlayEntry != null) {
      _loadingOverlayEntry!.remove();
      _loadingOverlayEntry = null;
    }
  }

  void _onRutChanged(String value) {
    if (value.isEmpty) {
      setState(() {
        _rutError = '';
      });
      return;
    }

    final cleanedValue = value.replaceAll(RegExp(r'[^0-9kK\.\-]'), '');
    if (cleanedValue != value) {
      _rutController.value = TextEditingValue(
        text: cleanedValue,
        selection: TextSelection.collapsed(offset: cleanedValue.length),
      );
    }

    final formattedRut = RutUtils.formatRut(cleanedValue);
    if (formattedRut != cleanedValue) {
      _rutController.value = TextEditingValue(
        text: formattedRut,
        selection: TextSelection.collapsed(offset: formattedRut.length),
      );
    }

    final isValid = RutUtils.validateRut(formattedRut);

    if (isValid) {
      _closeKeyboard();
    }

    setState(() {
      if (formattedRut.isNotEmpty && !isValid) {
        _rutError = 'RUT inválido';
      } else {
        _rutError = '';
      }
    });
  }

  // ✅ MÉTODO PARA CERRAR EL TECLADO
  void _closeKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      print('⚠️ No se puede mostrar SnackBar - Widget desmontado: $message');
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      print('❌ Error mostrando SnackBar: $e');
    }
  }

  Future<void> _scanDocument() async {
    if (!mounted) {
      print('❌ CRÍTICO: Widget no montado al iniciar escaneo');
      return;
    }

    setState(() {
      _isLoading = true;
      _currentStep = 'Escaneando documento...';
    });

    try {
      print('🔍 Iniciando escaneo con contexto específico...');

      final result = await _documentService.scanDocumentBothSides(specificContext: context);

      if (!mounted) {
        print('❌ CRÍTICO: Widget DESMONTADO durante el escaneo');
        return;
      }

      if (result != null && result['success'] == true) {
        setState(() {
          _documentStatus = '✓';
          _currentStep = _getCurrentStepMessage();
          _lastDocumentResult = result;
        });

        final hasBothSides = result['hasBothSides'] ?? false;
        final hasValidFacialImage = result['documentFaceImage']?['success'] == true;
        final isConsistent = result['consistencyCheck']?['isConsistent'] ?? false;

        String message = 'Documento escaneado automáticamente';
        if (hasBothSides) {
          message += ' - Ambas caras capturadas';
        } else {
          message += ' - Continuando con segunda cara...';
        }
        if (hasValidFacialImage) {
          message += ' - ✅ Foto facial válida para biometría';
        } else {
          message += ' - ⚠️ Imagen facial no apta para biometría';
        }
        if (!isConsistent) {
          message += ' - ⚠️ Verificar consistencia de datos';
        }

        _showSnackBar(message);

        if (_rutController.text.isNotEmpty && result['documentData'] != null) {
          final documentRun = result['documentData']['run'] ?? '';
          final enteredRun = _rutController.text.replaceAll('.', '').replaceAll('-', '').toUpperCase();
          final documentRunClean = documentRun.replaceAll('.', '').replaceAll('-', '').toUpperCase();

          if (documentRunClean != enteredRun) {
            _showSnackBar('⚠️ El RUT del documento no coincide con el ingresado');
          } else {
            _showSnackBar('✅ RUT del documento coincide con el ingresado');
          }
        }

        if (result['validDocument'] == true && hasValidFacialImage && hasBothSides) {
          await Future.delayed(const Duration(seconds: 1));
          await _captureFace();
        } else if (result['validDocument'] == true && !hasValidFacialImage && hasBothSides) {
          _showSnackBar('⚠️ Documento válido pero imagen facial no apta para biometría');
        }

      } else {
        String errorMessage = 'Escaneo falló o fue cancelado';
        if (result != null && result['error'] != null) {
          errorMessage = result['error'].toString();
        }

        _showSnackBar('$errorMessage - Puede intentar nuevamente');
        setState(() {
          _documentStatus = 'No escaneado';
          _currentStep = _getCurrentStepMessage();
        });
      }
    } catch (e) {
      print('❌ Error en escaneo: $e');
      if (mounted) {
        _showSnackBar('Error en escaneo: ${e.toString().split('\n').first} - Intente nuevamente');
        setState(() {
          _documentStatus = 'No escaneado';
          _currentStep = _getCurrentStepMessage();
          _isLoading = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _captureFace() async {
    if (!mounted) {
      print('❌ Widget no montado al iniciar captura facial');
      return;
    }

    // ✅ CORREGIDO: Ahora verifica solo si contiene '✓'
    if (!_documentStatus.contains('✓')) {
      _showSnackBar('Primero debe completar la verificación de documento');
      return;
    }

    final hasValidFacialImage = _lastDocumentResult?['documentFaceImage']?['success'] == true;
    if (!hasValidFacialImage) {
      _showSnackBar('El documento no tiene una imagen facial válida para comparación biométrica');
      return;
    }

    setState(() {
      _isLoading = true;
      _currentStep = 'Capturando rostro...';
    });

    try {
      final result = await _faceService.captureAndVerifyFace(
        documentData: _lastDocumentResult,
        specificContext: context,
      );

      if (!mounted) {
        print('❌ Widget DESMONTADO durante captura facial');
        return;
      }

      _lastFaceResult = result;

      if (result != null && result['success'] == true) {
        final isMatch = result['isMatch'] ?? false;
        final isLive = result['isLive'] ?? false;
        final similarity = result['similarity'] ?? 0.0;
        final livenessScore = result['livenessScore'] ?? 0.0;
        final livenessStatus = result['livenessStatus'] ?? 'No evaluado';

        String faceStatusText;
        String snackBarMessage;

        if (isLive && isMatch) {
          faceStatusText = '✓';
          snackBarMessage = '✅ Biometría exitosa - Similitud: ${similarity.toStringAsFixed(1)}% - Vivacidad: ${livenessScore.toStringAsFixed(1)}%';
        } else if (isLive && !isMatch) {
          faceStatusText = 'Rostro no coincide ✗';
          snackBarMessage = '❌ Rostro no coincide - Similitud: ${similarity.toStringAsFixed(1)}%';
        } else {
          faceStatusText = 'Vivacidad fallida ✗';
          snackBarMessage = '❌ Falló verificación de vivacidad: $livenessStatus';
        }

        setState(() {
          _faceStatus = faceStatusText;
          _currentStep = _getCurrentStepMessage();
        });

        _showSnackBar(snackBarMessage);

      } else {
        final error = result?['error'] ?? 'Captura facial falló o fue cancelada';
        _showSnackBar('❌ $error');
        setState(() {
          _faceStatus = 'No capturado';
          _currentStep = _getCurrentStepMessage();
        });
      }
    } catch (e) {
      _showSnackBar('Error en biometría: ${e.toString().split('\n').first} - Intente nuevamente');
      if (mounted) {
        setState(() {
          _faceStatus = 'No capturado';
          _currentStep = _getCurrentStepMessage();
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getCurrentStepMessage() {
    final hasValidRut = _rutController.text.isNotEmpty && _rutError.isEmpty;
    // ✅ CORREGIDO: Ahora verifica solo si contiene '✓'
    final hasDocument = _documentStatus.contains('✓');
    final hasFace = _faceStatus.contains('✓');
    final hasTipoRelacion = _tipoRelacionSeleccionada != null;

    if (hasValidRut && hasDocument && hasFace && hasTipoRelacion) {
      return '¡Listo! Puede solicitar su línea de crédito';
    } else if (!hasValidRut) {
      return 'Complete el RUT de empresa para continuar';
    } else if (!hasTipoRelacion) {
      return 'Seleccione el tipo de relación con la empresa';
    } else if (!hasDocument) {
      return 'Verifique su documento para continuar';
    } else if (!hasFace) {
      return 'Verifique su rostro para continuar';
    }
    return 'Complete las verificaciones para solicitar línea de crédito';
  }

  bool _canRequestCredit() {
    final hasValidRut = _rutController.text.isNotEmpty && _rutError.isEmpty;
    // ✅ CORREGIDO: Ahora verifica solo si contiene '✓'
    final hasDocument = _documentStatus.contains('✓');
    final hasFace = _faceStatus.contains('✓');
    final hasTipoRelacion = _tipoRelacionSeleccionada != null;

    final isFaceMatch = _lastFaceResult?['isMatch'] ?? false;
    final isFaceLive = _lastFaceResult?['isLive'] ?? false;
    final hasValidDocument = _lastDocumentResult?['validDocument'] ?? false;
    final hasBothSides = _lastDocumentResult?['hasBothSides'] ?? false;
    final hasValidFacialImage = _lastDocumentResult?['documentFaceImage']?['success'] ?? false;

    return hasValidRut &&
        hasTipoRelacion &&
        hasDocument &&
        hasFace &&
        isFaceMatch &&
        isFaceLive &&
        hasValidDocument &&
        hasBothSides &&
        hasValidFacialImage;
  }

  // ✅ MÉTODO PARA CONVERTIR TIPO DE RELACIÓN A VALOR NUMÉRICO
  String? _convertirTipoRelacionANumero(String? tipoRelacion) {
    if (tipoRelacion == 'autorizador') {
      return '1';
    } else if (tipoRelacion == 'representante') {
      return '2';
    }
    return null;
  }

  // ✅ MÉTODO PARA AUTENTICAR COMPRADOR
  Future<void> _solicitarLineaCredito() async {
    if (!mounted) {
      print('❌ Widget no montado al solicitar línea de crédito');
      return;
    }

    if (!_canRequestCredit()) {
      _showSnackBar('Por favor, complete todas las verificaciones primero');
      return;
    }

    setState(() {
      _isLoading = true;
      _currentStep = 'Solicitando línea de crédito...';
    });

    try {
      final String tokenComprador = _getTokenComprador();
      final Map<String, String> runComprador = _parseRunFromDocument();
      final Map<String, String> rutEmpresa = RutUtils.parseRut(_rutController.text);

      final String? tipoRelacionNumerico = _convertirTipoRelacionANumero(_tipoRelacionSeleccionada);

      final String detalleCarnet = _buildDetalleCarnet();

      print('🔐 Enviando solicitud de línea de crédito...');

      final response = await http.post(
        Uri.parse('${GlobalVariables.baseUrl}/AutenticarComprador/api/v1/'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'api-key': '${GlobalVariables.apiKey}',
        },
        body: json.encode({
          "token_comprador": tokenComprador,
          "run_comprador": runComprador['numero'] ?? '',
          "dv_comprador": runComprador['dv'] ?? '',
          "nombres_comprador": _lastDocumentResult?['documentData']?['nombres'] ?? '',
          "apellidos_comprador": _lastDocumentResult?['documentData']?['apellidos'] ?? '',
          "rut_empresa": rutEmpresa['numero'] ?? '',
          "dv_empresa": rutEmpresa['dv'] ?? '',
          "represetante_o_autorizador": tipoRelacionNumerico,
          "detalle_carnet": detalleCarnet
        }),
      ).timeout(const Duration(seconds: 30));

      print('📥 Response AutenticarComprador - Status: ${response.statusCode}');
      print('📥 Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _showSnackBar('✅ Solicitud de línea de crédito enviada exitosamente');

        _volverAlHome();
      } else {
        _showSnackBar('❌ Error en solicitud: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _isLoading = false;
            _currentStep = _getCurrentStepMessage();
          });
        }
      }

    } catch (e) {
      print('❌ Error en solicitud de línea de crédito: $e');
      _showSnackBar('Error en solicitud: ${e.toString().split('\n').first}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentStep = _getCurrentStepMessage();
        });
      }
    }
  }

  void _volverAlHome() {
    print('🏠 Volviendo al Home después de solicitud exitosa...');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => DashboardScreen(
          userData: widget.userData,
        ),
      ),
          (route) => false,
    );
  }

  String _getTokenComprador() {
    try {
      return widget.userData['comprador']?['token_comprador'] ?? '';
    } catch (e) {
      return '';
    }
  }

  Map<String, String> _parseRunFromDocument() {
    try {
      final String runCompleto = _lastDocumentResult?['documentData']?['run'] ?? '';
      if (runCompleto.isEmpty) return {'numero': '', 'dv': ''};

      String cleanRun = runCompleto.replaceAll('.', '').replaceAll('-', '');
      if (cleanRun.length < 2) return {'numero': '', 'dv': ''};

      String numero = cleanRun.substring(0, cleanRun.length - 1);
      String dv = cleanRun.substring(cleanRun.length - 1);

      return {'numero': numero, 'dv': dv};
    } catch (e) {
      return {'numero': '', 'dv': ''};
    }
  }

  String _buildDetalleCarnet() {
    try {
      final Map<String, dynamic> detalle = {
        'documento': _lastDocumentResult?['documentData'] ?? {},
        'biometria': _lastFaceResult ?? {},
        'fecha_solicitud': DateTime.now().toIso8601String(),
        'proceso_completo': true
      };

      return json.encode(detalle);
    } catch (e) {
      return json.encode({'error': 'No se pudo generar detalle del carnet'});
    }
  }

  void _resetVerification() {
    if (!mounted) return;

    setState(() {
      _documentStatus = 'No escaneado';
      _faceStatus = 'No capturado';
      _currentStep = _getCurrentStepMessage();
      _lastDocumentResult = null;
      _lastFaceResult = null;
      _rutController.clear();
      _rutError = '';
      _tipoRelacionSeleccionada = null;
    });
  }

  // ✅ NUEVO MÉTODO: CONSTRUIR SELECTOR DE TIPO DE RELACIÓN
  Widget _buildSelectorTipoRelacion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tipo de relación con la empresa',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _blueDarkColor,
          ),
        ),
        const SizedBox(height: 12),

        _buildOpcionRelacion(
          titulo: 'Autorizador',
          subtitulo: 'Persona autorizada para realizar compras',
          icono: Icons.person_outline,
          seleccionado: _tipoRelacionSeleccionada == 'autorizador',
          onTap: () {
            setState(() {
              _tipoRelacionSeleccionada = 'autorizador';
            });
          },
        ),

        const SizedBox(height: 12),

        _buildOpcionRelacion(
          titulo: 'Representante',
          subtitulo: 'Representante legal de la empresa',
          icono: Icons.badge_outlined,
          seleccionado: _tipoRelacionSeleccionada == 'representante',
          onTap: () {
            setState(() {
              _tipoRelacionSeleccionada = 'representante';
            });
          },
        ),
      ],
    );
  }

  // ✅ NUEVO MÉTODO: CONSTRUIR OPCIÓN DE RELACIÓN
  Widget _buildOpcionRelacion({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required bool seleccionado,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: seleccionado
              ? _blueDarkColor.withOpacity(0.1)
              : _approvedCardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: seleccionado
                ? _blueDarkColor
                : Colors.grey.shade300,
            width: seleccionado ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 3,
              offset: const Offset(0, 2),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: seleccionado
                    ? _blueDarkColor.withOpacity(0.1)
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: seleccionado
                      ? _blueDarkColor
                      : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: Icon(
                icono,
                color: seleccionado ? _blueDarkColor : Colors.grey.shade600,
                size: 20,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: seleccionado
                              ? Colors.black
                              : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (seleccionado)
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    subtitulo,
                    style: TextStyle(
                      fontSize: 12,
                      color: seleccionado
                          ? Colors.grey
                          : Colors.grey.shade600,
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

  @override
  Widget build(BuildContext context) {
    final hasValidRut = _rutController.text.isNotEmpty && _rutError.isEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _blueDarkColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Image.asset(
          'assets/images/logo_fio.png',
          height: 35,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: const [],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solicitar Línea de Crédito',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _blueDarkColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _currentStep,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),

              const SizedBox(height: 32),

              _buildRutField(hasValidRut: hasValidRut),

              const SizedBox(height: 24),

              _buildSelectorTipoRelacion(),

              const SizedBox(height: 24),

              _buildVerificationProgress(),

              const SizedBox(height: 32),

              _buildSolicitarButton(),

              const SizedBox(height: 20),

              _buildStatusInfo(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRutField({required bool hasValidRut}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RUT de empresa',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasValidRut ? _blueDarkColor.withOpacity(0.3) : Colors.grey.shade400,
            ),
            color: Colors.grey.shade50,
          ),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Icon(
                  Icons.business_outlined,
                  size: 20,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _rutController,
                  focusNode: _rutFocusNode,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Ej: 12.345.678-9',
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: _onRutChanged,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                  ),
                  textInputAction: TextInputAction.done,
                ),
              ),
              if (hasValidRut)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    width: 20, // ✅ EXACTO MISMO TAMAÑO
                    height: 20, // ✅ EXACTO MISMO TAMAÑO
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50), // ✅ MISMO VERDE
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 14, // ✅ MISMO TAMAÑO DE ÍCONO
                    ),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),

        if (_rutError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _rutError,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVerificationProgress() {
    final documentCompleted = _documentStatus.contains('✓');
    final faceCompleted = _faceStatus.contains('✓');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verificación de Identidad',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _blueDarkColor,
          ),
        ),
        const SizedBox(height: 16),

        // ✅ VERSIÓN SIMPLIFICADA SIN LayoutBuilder
        Container(
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: _buildSquareVerificationCard(
                  stepNumber: 1,
                  title: 'Carnet',
                  status: _documentStatus,
                  icon: Icons.credit_card,
                  onTap: _showScanConfirmation,
                  isCompleted: documentCompleted,
                  isEnabled: true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSquareVerificationCard(
                  stepNumber: 2,
                  title: 'Rostro',
                  status: _faceStatus,
                  icon: Icons.face,
                  onTap: _captureFace,
                  isCompleted: faceCompleted,
                  isEnabled: _documentStatus.contains('✓'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSquareVerificationCard({
    required int stepNumber,
    required String title,
    required String status,
    required IconData icon,
    required VoidCallback onTap,
    required bool isCompleted,
    required bool isEnabled,
  }) {
    // ✅ Determinar si es el botón de Rostro (stepNumber == 2) y está desactivado
    final bool isFaceCardDisabled = stepNumber == 2 && !isEnabled;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        // ✅ Si es el botón de Rostro desactivado, usar gris, sino el color normal
        color: isFaceCardDisabled
            ? Colors.grey.shade200  // Gris para Rostro desactivado
            : _approvedCardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted
              ? _blueDarkColor.withOpacity(0.5)
              : (isFaceCardDisabled
              ? Colors.grey.shade400  // Borde gris para Rostro desactivado
              : Colors.grey.shade300),
          width: isCompleted ? 2 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(isFaceCardDisabled ? 0.1 : 0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : (isEnabled ? onTap : null),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                // ÍCONO GRANDE
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? _blueDarkColor.withOpacity(0.15)
                        : (isFaceCardDisabled
                        ? Colors.grey.shade300  // Fondo gris para ícono desactivado
                        : (isEnabled
                        ? _blueDarkColor.withOpacity(0.1)
                        : Colors.grey.shade300)),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 36,
                    color: isCompleted
                        ? _blueDarkColor
                        : (isFaceCardDisabled
                        ? Colors.grey.shade500  // Ícono gris para Rostro desactivado
                        : (isEnabled
                        ? _blueDarkColor
                        : Colors.grey.shade600)),
                  ),
                ),

                const SizedBox(height: 16),

                // NÚMERO DE PASO Y TÍTULO
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? _blueDarkColor
                            : (isFaceCardDisabled
                            ? Colors.grey.shade500  // Círculo del número gris
                            : (isEnabled
                            ? _blueDarkColor
                            : Colors.grey.shade400)),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          stepNumber.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isFaceCardDisabled
                            ? Colors.grey.shade600  // Texto gris para Rostro desactivado
                            : (isEnabled ? Colors.black : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ESTADO
                Container(
                  constraints: BoxConstraints(
                    maxWidth: double.infinity,
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 14,
                      color: isCompleted
                          ? _blueDarkColor
                          : (isFaceCardDisabled
                          ? Colors.grey.shade500  // Estado en gris
                          : (isEnabled
                          ? Colors.grey.shade700
                          : Colors.grey.shade500)),
                      fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSolicitarButton() {
    final canRequest = _canRequestCredit();
    final buttonText = canRequest ? 'Solicitar Línea de Crédito' : 'Complete el formulario';

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading || !canRequest ? null : _solicitarLineaCredito,
        style: ElevatedButton.styleFrom(
          backgroundColor: canRequest ? _blueDarkColor : Colors.grey.shade400,
          foregroundColor: Colors.white,
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
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canRequest)
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
            if (canRequest) const SizedBox(width: 8),
            Flexible(
              child: Text(
                buttonText,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusInfo() {
    return Column(
      children: [
        if (_isLoading || _showLocalLoading) ...[
          LinearProgressIndicator(
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(_blueDarkColor),
          ),
          const SizedBox(height: 16),
          Text(
            _currentStep,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
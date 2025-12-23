import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class CameraScreen extends StatefulWidget {
  final String scanType;
  final Function(Uint8List) onImageCaptured;
  final Function() onCancel;

  const CameraScreen({
    Key? key,
    required this.scanType,
    required this.onImageCaptured,
    required this.onCancel,
  }) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  Timer? _autoCaptureTimer;
  bool _showCaptureEffect = false;
  int _countdown = 6;
  bool _hasCalledCallback = false; // ✅ NUEVO: Evitar llamadas duplicadas

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final firstCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        firstCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller.initialize();

      await _initializeControllerFuture;

      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
        _startAutoCapture();
      }
    } catch (e) {
      print('Error inicializando cámara: $e');
      if (mounted) {
        _cancelCapture();
      }
    }
  }

  void _startAutoCapture() {
    _countdown = 6;
    _autoCaptureTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _countdown--;
        });

        if (_countdown <= 0) {
          timer.cancel();
          _captureImage();
        }
      }
    });
  }

  Future<void> _captureImage() async {
    if (!_isCameraReady || _isCapturing || _hasCalledCallback) return;

    setState(() {
      _isCapturing = true;
      _showCaptureEffect = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final image = await _controller.takePicture();
      final File imageFile = File(image.path);

      final Uint8List imageBytes = await imageFile.readAsBytes();

      final Uint8List processedBytes = await _reduceImageSize(imageBytes);

      setState(() {
        _showCaptureEffect = false;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted && !_hasCalledCallback) {
        _hasCalledCallback = true; // ✅ PREVENIR LLAMADAS DUPLICADAS
        print('✅ Imagen capturada, llamando callback...');

        // ✅ IMPORTANTE: Cerrar esta pantalla ANTES de llamar al callback
        Navigator.of(context).pop(processedBytes);
      }
    } catch (e) {
      print('Error capturando imagen: $e');
      if (mounted && !_hasCalledCallback) {
        _hasCalledCallback = true;
        print('❌ Error en captura, cerrando cámara...');
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _cancelCapture() {
    if (_hasCalledCallback) return; // ✅ EVITAR LLAMADAS DUPLICADAS

    print('❌ Captura cancelada por usuario...');
    _hasCalledCallback = true;

    // ✅ Cerrar esta pantalla directamente
    Navigator.of(context).pop();
  }

  Future<Uint8List> _reduceImageSize(Uint8List imageBytes) async {
    if (imageBytes.length <= 500 * 1024) {
      print('✅ Imagen tamaño adecuado: ${imageBytes.length ~/ 1024} KB');
      return imageBytes;
    }

    try {
      final directory = await getTemporaryDirectory();
      final originalFile = File('${directory.path}/original_temp.jpg');
      await originalFile.writeAsBytes(imageBytes);

      print('⚠️ Imagen grande: ${imageBytes.length ~/ 1024} KB - Usando original');
      return imageBytes;

    } catch (e) {
      print('❌ Error procesando imagen: $e');
      return imageBytes;
    }
  }

  String _getInstructionText() {
    switch (widget.scanType) {
      case 'front':
        return 'Enfoque la cara frontal de su cédula de identidad';
      case 'back':
        return 'Ahora el reverso de su cédula de identidad';
      default:
        return 'Enfoque el documento';
    }
  }

  String _getSubInstructionText() {
    return 'La foto se tomará automáticamente';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isCameraReady)
              Center(
                child: Transform.scale(
                  scale: 1.0,
                  child: CameraPreview(_controller),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),

            if (_showCaptureEffect)
              Container(
                color: Colors.white.withOpacity(0.8),
              ),

            _buildInstructionOverlay(),

            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _cancelCapture,
              ),
            ),

            if (_isCapturing)
              const Positioned(
                bottom: 150,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    SizedBox(height: 16)
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionOverlay() {
    // ✅ USANDO LOS COLORES AZULES DE LAS TARJETAS
    final Color _blueDarkColor = Color(0xFF0055B8); // El mismo azul oscuro de las tarjetas
    final Color _approvedCardBackground = Color(0xFFE8F0FE); // El mismo azul claro de fondo

    return Positioned(
      top: MediaQuery.of(context).size.height * 0.3,
      left: 0,
      right: 0,
      child: Column(
        children: [
          Container(
            width: 300,
            height: 190,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                Icons.credit_card,
                color: Colors.white.withOpacity(0.6),
                size: 50,
              ),
            ),
          ),

          const SizedBox(height: 40),

          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  _getInstructionText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _getSubInstructionText(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // ✅ CONTADOR CON COLORES AZULES
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _approvedCardBackground, // Fondo azul claro (#E8F0FE)
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _blueDarkColor.withOpacity(0.3), // Borde azul oscuro con opacidad
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer,
                        color: _blueDarkColor, // Ícono en azul oscuro
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_countdown seg',
                        style: TextStyle(
                          color: _blueDarkColor, // Texto en azul oscuro
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ✅ BARRA DE PROGRESO EN AZUL
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: (6 - _countdown) / 6,
                    backgroundColor: Colors.grey.shade300, // Fondo gris claro
                    valueColor: AlwaysStoppedAnimation<Color>(_blueDarkColor), // Progreso en azul oscuro
                    minHeight: 6, // Un poco más gruesa
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
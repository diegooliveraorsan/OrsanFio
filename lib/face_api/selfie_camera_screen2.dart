import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SelfieCameraScreen extends StatefulWidget {
  final Function(Uint8List) onImageCaptured;
  final Function() onCancel;

  const SelfieCameraScreen({
    Key? key,
    required this.onImageCaptured,
    required this.onCancel,
  }) : super(key: key);

  @override
  _SelfieCameraScreenState createState() => _SelfieCameraScreenState();
}

class _SelfieCameraScreenState extends State<SelfieCameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _isCameraReady = false;
  bool _isCapturing = false;
  Timer? _autoCaptureTimer;
  bool _showCaptureEffect = false;
  int _countdown = 6;
  bool _isFrontCamera = true;

  // Colores definidos como propiedades
  final Color _borderColor = Colors.green.withOpacity(0.8);
  final Color _instructionBgColor = Colors.black.withOpacity(0.7);
  final Color _subtitleColor = Colors.white.withOpacity(0.8);
  final Color _cameraTextColor = Colors.white.withOpacity(0.6);
  final Color _captureEffectColor = Colors.white.withOpacity(0.8);

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

      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
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
      print('Error inicializando cámara selfie: $e');
      if (mounted) {
        widget.onCancel();
      }
    }
  }

  Future<void> _switchCamera() async {
    if (!_isCameraReady || _isCapturing) return;

    try {
      setState(() {
        _isCameraReady = false;
      });

      await _controller.dispose();

      final cameras = await availableCameras();
      final newCamera = _isFrontCamera
          ? cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      )
          : cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller.initialize();

      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _isFrontCamera = !_isFrontCamera;
        });
      }
    } catch (e) {
      print('Error cambiando cámara: $e');
      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
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
    if (!_isCameraReady || _isCapturing) return;

    setState(() {
      _isCapturing = true;
      _showCaptureEffect = true;
    });

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final image = await _controller.takePicture();
      final File imageFile = File(image.path);

      final Uint8List imageBytes = await imageFile.readAsBytes();

      // ✅ CORREGIR ROTACIÓN DE LA IMAGEN
      final Uint8List processedBytes = await _processSelfieImage(imageBytes);

      setState(() {
        _showCaptureEffect = false;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        widget.onImageCaptured(processedBytes);
      }
    } catch (e) {
      print('Error capturando selfie: $e');
      if (mounted) {
        widget.onCancel();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  Future<Uint8List> _processSelfieImage(Uint8List imageBytes) async {
    // Para selfies, generalmente no necesitamos reducir tanto el tamaño
    // pero mantenemos un límite razonable
    if (imageBytes.length <= 800 * 1024) {
      print('✅ Selfie tamaño adecuado: ${imageBytes.length ~/ 1024} KB');
      return imageBytes;
    }

    try {
      final directory = await getTemporaryDirectory();
      final originalFile = File('${directory.path}/selfie_temp.jpg');
      await originalFile.writeAsBytes(imageBytes);

      print('⚠️ Selfie grande: ${imageBytes.length ~/ 1024} KB - Usando original');
      return imageBytes;

    } catch (e) {
      print('❌ Error procesando selfie: $e');
      return imageBytes;
    }
  }

  void _retakePhoto() {
    if (_isCapturing) return;

    setState(() {
      _isCapturing = false;
    });
    _startAutoCapture();
  }

  String _getCameraText() {
    return _isFrontCamera ? 'frontal' : 'trasera';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ✅ CÁMARA PREVIEW
            if (_isCameraReady)
              Center(
                child: CameraPreview(_controller),
              )
            else
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Preparando cámara...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

            if (_showCaptureEffect)
              Container(
                color: _captureEffectColor,
              ),

            // ✅ OVERLAY CORREGIDO - CÍRCULO CENTRADO
            _buildSelfieOverlay(),

            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () {
                  _autoCaptureTimer?.cancel();
                  widget.onCancel();
                },
              ),
            ),

            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: Icon(
                  _isFrontCamera ? Icons.camera_rear : Icons.camera_front,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: _switchCamera,
              ),
            ),

            if (_isCapturing)
              Positioned(
                bottom: 150,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Procesando selfie...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _retakePhoto,
                      child: const Text(
                        'Tomar de nuevo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
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

  Widget _buildSelfieOverlay() {
    // ✅ USANDO LOS COLORES AZULES DE LAS TARJETAS
    final Color _blueDarkColor = Color(0xFF0055B8); // Azul oscuro
    final Color _approvedCardBackground = Color(0xFFE8F0FE); // Azul claro de fondo

    return Stack(
      children: [
        // ✅ CAPA SUPERIOR TRANSPARENTE CON MÁSCARA
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
        ),

        // ✅ CÍRCULO CENTRADO
        Positioned.fill(
          child: Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: _blueDarkColor.withOpacity(0.8),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(140),
              ),
            ),
          ),
        ),

        // ✅ INSTRUCCIONES EN LA PARTE INFERIOR
        Positioned(
          left: 20,
          right: 20,
          bottom: 50,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _instructionBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'SONRÍE PARA LA SELFIE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Asegúrate de que tu rostro esté centrado\nen el círculo y bien iluminado',
                  style: TextStyle(
                    color: _subtitleColor,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // ✅ CONTADOR
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _approvedCardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _blueDarkColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.face,
                        color: _blueDarkColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$_countdown seg',
                        style: TextStyle(
                          color: _blueDarkColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ✅ BARRA DE PROGRESO
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    value: (6 - _countdown) / 6,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(_blueDarkColor),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),

                const SizedBox(height: 8),
                Text(
                  'Cámara ${_getCameraText()}',
                  style: TextStyle(
                    color: _cameraTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
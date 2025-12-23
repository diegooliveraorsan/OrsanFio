import 'dart:async';
import 'package:flutter/material.dart';

class SimpleLoadingDialog extends StatefulWidget {
  final Completer<void> completer;
  final String message;

  // ✅ COLOR AZUL OSCURO DEFINIDO (IGUAL QUE EN MAIN)
  final Color _blueDarkColor = const Color(0xFF0055B8);

  const SimpleLoadingDialog({
    super.key,
    required this.completer,
    this.message = 'Procesando...',
  });

  static void show({
    required BuildContext context,
    required Completer<void> completer,
    String message = 'Procesando...',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SimpleLoadingDialog(
        completer: completer,
        message: message,
      ),
    );
  }

  static void hide(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  State<SimpleLoadingDialog> createState() => _SimpleLoadingDialogState();
}

class _SimpleLoadingDialogState extends State<SimpleLoadingDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Timeout de seguridad por si algo sale mal
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });

    // Cerrar cuando el completer se complete
    widget.completer.future.then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8), // ✅ FONDO NEGRO MANTENIDO
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget._blueDarkColor, // ✅ BORDE EN AZUL OSCURO
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _controller.value * 2 * 3.14159,
                    child: Image.asset(
                      'assets/images/logo_orsan.png',
                      width: 60,
                      height: 60,
                      color: widget._blueDarkColor, // ✅ IMAGEN EN AZUL OSCURO
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.autorenew,
                        size: 60,
                        color: widget._blueDarkColor, // ✅ ICONO EN AZUL OSCURO
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                widget.message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
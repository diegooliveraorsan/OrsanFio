import 'package:flutter/material.dart';

enum AnimationType {
  processing,
  transition,
  validating
}

class ProcessingAnimationScreen extends StatefulWidget {
  final String message;
  final AnimationType animationType;

  const ProcessingAnimationScreen({
    Key? key,
    required this.message,
    required this.animationType,
  }) : super(key: key);

  @override
  _ProcessingAnimationScreenState createState() => _ProcessingAnimationScreenState();
}

class _ProcessingAnimationScreenState extends State<ProcessingAnimationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAnimationContent() {
    switch (widget.animationType) {
      case AnimationType.processing:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(_controller),
              child: Icon(
                Icons.autorenew,
                size: 80,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );

      case AnimationType.transition:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _animation,
              child: Icon(
                Icons.arrow_forward,
                size: 80,
                color: Colors.green.shade500,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "Gire el documento",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade300,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        );

      case AnimationType.validating:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.verified,
                  size: 80,
                  color: Colors.green.shade500.withOpacity(0.3),
                ),
                ScaleTransition(
                  scale: _animation,
                  child: Icon(
                    Icons.verified,
                    size: 80,
                    color: Colors.green.shade500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              widget.message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.7),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Contenedor de la animación
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey.shade900.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildAnimationContent(),
              ),
            ),

            // Botón de cancelar (solo mostrar en procesamiento)
            if (widget.animationType == AnimationType.processing) ...[
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // También necesitaríamos cancelar el proceso en curso
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Cancelar Proceso'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
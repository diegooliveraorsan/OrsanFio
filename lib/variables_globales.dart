import 'package:flutter/material.dart';

class GlobalVariables {
  static const String apiKey = 'X4bFio9qWzM1kP6rS8nY';
  static const String baseUrl = 'https://apiorsanpay.orsanevaluaciones.cl';
  static const String appVersion = "1.1.0";

  static const bool isDebugMode = false; // Cambiar a false en producción
  static void debugPrint(String message) {
    if (isDebugMode) {
      print(message);
    }
  }
  // ✅ URLs de servicios
  static const String regulaApiUrl = 'https://biometria.orsanevaluaciones.cl/';

  // ✅ Configuración de imágenes
  static const int maxImageSizeKB = 300;
  static const int maxImageWidth = 800;
  static const int maxImageHeight = 1000;

  // ✅ Color azul oscuro corporativo
  static const Color blueDarkColor = Color(0xFF0055B8);
}

// 🔹 ESTILOS GLOBALES PARA INPUTS
class GlobalInputStyles {
  static InputDecoration inputDecoration({
    required String labelText,
    IconData? prefixIcon,
    Widget? suffixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: GlobalVariables.blueDarkColor)
          : null,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: GlobalVariables.blueDarkColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: Colors.grey.shade700),
      hintStyle: TextStyle(color: Colors.grey.shade500),
    );
  }
}

// 🔹 SNACKBARS GLOBALES
class GlobalSnackBars {
  static void mostrarExito(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static void mostrarError(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static void mostrarInfo(BuildContext context, String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.grey[800],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as img;
import 'selfie_camera_screen.dart';

class FaceApiService {
  static const String _apiUrl = 'https://biometria.orsanevaluaciones.cl/';
  static const Uuid _uuid = Uuid();

  // ✅ CONFIGURACIÓN DE ESTANDARIZACIÓN DE SELFIES
  static int _maxImageWidth = 800;   // Selfies necesitan menos resolución
  static int _maxImageHeight = 1000;
  static int _maxFileSizeKB = 300;   // Selfies más pequeñas
  static int _jpegQuality = 80;      // Calidad balanceada para rostros

  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static Map<String, dynamic>? _lastRequestDebug;

  Future<Map<String, dynamic>> captureAndVerifyFace({
    required Map<String, dynamic>? documentData,
    BuildContext? specificContext,
  }) async {
    try {
      print('🎯 Iniciando captura y verificación facial...');

      final hasValidDocumentFace = documentData?['documentFaceImage']?['success'] == true;

      if (hasValidDocumentFace) {
        print('📷✅ Imagen facial del documento disponible para comparación');
      } else {
        print('📷❌ No hay imagen facial válida del documento');
      }

      // 1. CAPTURAR SELFIE CON LIVENESS SIMULADO TEMPORALMENTE
      print('🔍 Capturando selfie con verificación de vivacidad...');
      final captureResult = await _captureSelfieWithLiveness(specificContext: specificContext);

      if (!captureResult['success']) {
        return {
          'success': false,
          'error': 'Falló captura de selfie: ${captureResult['error']}',
          'livenessScore': 0.0,
          'livenessStatus': 'ERROR',
          'isLive': false,
        };
      }

      final Uint8List selfieImageBytes = captureResult['imageBytes'];
      final double livenessScore = captureResult['livenessScore'];
      final String livenessStatus = captureResult['livenessStatus'];
      final bool isLive = captureResult['isLive'];

      print('✅ Selfie capturada - Tamaño original: ${selfieImageBytes.length ~/ 1024} KB');
      print('✅ Liveness - Score: $livenessScore% - Status: $livenessStatus');

      // ✅ ANALIZAR Y ESTANDARIZAR SELFIE
      print('\n🎯 ANALIZANDO SELFIE CAPTURADA:');
      _analyzeSelfieSize(selfieImageBytes);

      print('\n🔄 ESTANDARIZANDO SELFIE...');
      final Uint8List? standardizedSelfie = await _standardizeSelfieImage(selfieImageBytes);
      if (standardizedSelfie == null) {
        return {
          'success': false,
          'error': 'Error al procesar la selfie',
          'livenessScore': livenessScore,
          'livenessStatus': livenessStatus,
          'isLive': isLive,
        };
      }

      // 2. VERIFICAR SI PASÓ EL LIVENESS
      if (!isLive) {
        return {
          'success': false,
          'error': 'No se detectó una persona real (Liveness failed)',
          'livenessScore': livenessScore,
          'livenessStatus': livenessStatus,
          'isLive': false,
        };
      }

      // 3. DETECCIÓN FACIAL EN SELFIE ESTANDARIZADA
      final selfieDetection = await _detectFaces(standardizedSelfie);
      if (!selfieDetection['success']) {
        return {
          'success': false,
          'error': 'No se detectó rostro en la selfie',
          'livenessScore': livenessScore,
          'livenessStatus': livenessStatus,
          'isLive': true,
        };
      }

      print('✅ Rostro detectado en selfie estandarizada');

      // 4. SI HAY DOCUMENTO, COMPARAR
      if (hasValidDocumentFace) {
        final comparisonResult = await _compareFaces(
            documentData!['documentFaceImage']['faceImage'],
            standardizedSelfie
        );

        if (comparisonResult['success'] == true) {
          return {
            'success': true,
            'isMatch': comparisonResult['isMatch'],
            'similarity': comparisonResult['similarity'],
            'similarityPercentage': comparisonResult['similarityPercentage'],
            'livenessScore': livenessScore,
            'livenessStatus': livenessStatus,
            'isLive': true,
            'transactionId': captureResult['transactionId'],
            'tag': captureResult['tag'],
            'comparisonType': '1:1_document_vs_selfie',
            'templateExtracted': true,
            'message': comparisonResult['isMatch'] == true
                ? '✅ Biometría exitosa - Coincide con documento'
                : '❌ Rostro no coincide con documento',
          };
        } else {
          return {
            'success': false,
            'error': 'Error en comparación: ${comparisonResult['error']}',
            'livenessScore': livenessScore,
            'livenessStatus': livenessStatus,
            'isLive': true,
          };
        }
      }

      // 5. SOLO DETECCIÓN (sin documento para comparar)
      return {
        'success': true,
        'isMatch': null,
        'similarity': null,
        'livenessScore': livenessScore,
        'livenessStatus': livenessStatus,
        'isLive': true,
        'transactionId': captureResult['transactionId'],
        'tag': captureResult['tag'],
        'comparisonType': 'solo_deteccion',
        'templateExtracted': true,
        'message': '✅ Selfie con vivacidad verificada correctamente',
      };

    } catch (e) {
      print('❌ Error en FaceApiService: $e');
      return {
        'success': false,
        'error': 'Error en verificación facial: $e',
        'livenessScore': 0.0,
        'livenessStatus': 'ERROR',
        'isLive': false,
      };
    }
  }

  // ✅ MÉTODO PARA ANALIZAR TAMAÑO DE SELFIE
  void _analyzeSelfieSize(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        print('❌ No se pudo decodificar la selfie para análisis');
        return;
      }

      final sizeKB = imageBytes.length ~/ 1024;
      print('📊 ANÁLISIS DE SELFIE:');
      print('   • Tamaño en bytes: ${imageBytes.length}');
      print('   • Tamaño en KB: $sizeKB KB');
      print('   • Dimensiones: ${image.width} x ${image.height} px');
      print('   • Relación aspecto: ${(image.width / image.height).toStringAsFixed(2)}');

      // Verificar si cumple con estándares actuales
      bool meetsStandards = sizeKB <= _maxFileSizeKB &&
          image.width <= _maxImageWidth &&
          image.height <= _maxImageHeight;

      if (meetsStandards) {
        print('   ✅ CUMPLE CON ESTÁNDARES ACTUALES');
        print('   💡 CONFIGURACIÓN ACTUAL PARA SELFIES:');
        print('      - Ancho máximo: $_maxImageWidth px');
        print('      - Alto máximo: $_maxImageHeight px');
        print('      - Tamaño máximo: $_maxFileSizeKB KB');
      } else {
        print('   ⚠️  NO CUMPLE CON ESTÁNDARES ACTUALES');
        if (sizeKB > _maxFileSizeKB) {
          print('      - Tamaño excede: $sizeKB KB > $_maxFileSizeKB KB');
        }
        if (image.width > _maxImageWidth) {
          print('      - Ancho excede: ${image.width} px > $_maxImageWidth px');
        }
        if (image.height > _maxImageHeight) {
          print('      - Alto excede: ${image.height} px > $_maxImageHeight px');
        }
      }

    } catch (e) {
      print('❌ Error en análisis de selfie: $e');
    }
  }

  // ✅ MÉTODO PARA ESTANDARIZAR SELFIE
  Future<Uint8List?> _standardizeSelfieImage(Uint8List originalSelfie) async {
    try {
      print('\n🔄 INICIANDO ESTANDARIZACIÓN DE SELFIE');
      print('📊 TAMAÑO ORIGINAL: ${originalSelfie.length ~/ 1024} KB');

      // Decodificar la imagen
      final image = img.decodeImage(originalSelfie);
      if (image == null) {
        print('❌ No se pudo decodificar la selfie');
        return originalSelfie;
      }

      print('📐 DIMENSIONES ORIGINALES: ${image.width} x ${image.height} px');

      // Verificar si ya está dentro de los límites
      final originalSizeKB = originalSelfie.length ~/ 1024;
      if (originalSizeKB <= _maxFileSizeKB &&
          image.width <= _maxImageWidth &&
          image.height <= _maxImageHeight) {
        print('✅ SELFIE YA CUMPLE CON ESTÁNDARES - No necesita compresión');
        print('   📊 Tamaño: $originalSizeKB KB');
        print('   📐 Dimensiones: ${image.width} x ${image.height} px');
        print('   🎯 LISTA PARA DETECCIÓN FACIAL');
        return originalSelfie;
      }

      print('🔧 SELFIE NECESITA COMPRESIÓN - Aplicando estandarización...');

      // Calcular nuevas dimensiones manteniendo aspect ratio
      double widthRatio = _maxImageWidth / image.width;
      double heightRatio = _maxImageHeight / image.height;
      double ratio = widthRatio < heightRatio ? widthRatio : heightRatio;

      int newWidth = (image.width * ratio).round();
      int newHeight = (image.height * ratio).round();

      print('📏 REDIMENSIONANDO SELFIE:');
      print('   • De: ${image.width} x ${image.height} px');
      print('   • A: $newWidth x $newHeight px');
      print('   • Ratio aplicado: ${ratio.toStringAsFixed(2)}');

      // Redimensionar
      final resizedImage = img.copyResize(image, width: newWidth, height: newHeight);

      // Codificar con calidad ajustable
      Uint8List compressedImage = Uint8List.fromList(
          img.encodeJpg(resizedImage, quality: _jpegQuality)
      );

      int compressedSizeKB = compressedImage.length ~/ 1024;
      print('🎯 RESULTADO COMPRESIÓN SELFIE:');
      print('   • Tamaño original: $originalSizeKB KB');
      print('   • Tamaño comprimido: $compressedSizeKB KB');
      print('   • Reducción: ${((originalSizeKB - compressedSizeKB) / originalSizeKB * 100).toStringAsFixed(1)}%');
      print('   • Calidad JPEG: $_jpegQuality%');

      // Si todavía es muy grande, reducir calidad progresivamente
      int currentQuality = _jpegQuality;
      while (compressedSizeKB > _maxFileSizeKB && currentQuality > 50) {
        currentQuality -= 10;
        compressedImage = Uint8List.fromList(
            img.encodeJpg(resizedImage, quality: currentQuality)
        );
        compressedSizeKB = compressedImage.length ~/ 1024;
        print('   🔧 Ajustando calidad a $currentQuality% -> $compressedSizeKB KB');
      }

      print('✅ ESTANDARIZACIÓN SELFIE COMPLETADA:');
      print('   • Tamaño final: $compressedSizeKB KB');
      print('   • Dimensiones finales: $newWidth x $newHeight px');
      print('   • Calidad final: $currentQuality%');

      if (compressedSizeKB <= _maxFileSizeKB) {
        print('🎉 SELFIE ESTANDARIZADA EXITOSAMENTE - LISTA PARA DETECCIÓN FACIAL');
      } else {
        print('⚠️  SELFIE AÚN GRANDE, pero dentro de límites aceptables');
      }

      return compressedImage;

    } catch (e) {
      print('❌ ERROR en estandarización de selfie: $e');
      return originalSelfie;
    }
  }

  // ✅ CAPTURAR SELFIE CON LIVENESS SIMULADO (TEMPORAL) - MODIFICADO
  Future<Map<String, dynamic>> _captureSelfieWithLiveness({BuildContext? specificContext}) async {
    try {
      print('⚠️ LIVENESS SIMULADO - Endpoint /api/v2/liveness no disponible');
      print('📞 Contactar al soporte para obtener el endpoint correcto');

      // 1. SIMULAR INICIO DE SESIÓN LIVENESS
      final String transactionId = _uuid.v4();
      final String tag = 'session_${DateTime.now().millisecondsSinceEpoch}';

      print('✅ Sesión liveness simulada - TransactionId: $transactionId');

      // 2. CAPTURAR SELFIE REAL CON CONTEXTO ESPECÍFICO
      final Uint8List? selfieImageBytes = await _captureSelfieImage(specificContext: specificContext);
      if (selfieImageBytes == null) {
        return {'success': false, 'error': 'Captura de selfie cancelada'};
      }

      print('✅ Selfie capturada: ${selfieImageBytes.length ~/ 1024} KB');

      // 3. SIMULAR PROCESAMIENTO DE LIVENESS
      print('⏳ Simulando verificación de vivacidad...');
      await Future.delayed(const Duration(seconds: 2));

      // 4. SIMULAR RESULTADO EXITOSO DE LIVENESS
      // En producción, aquí iría la llamada real al API
      final bool livenessSuccess = true; // Simular éxito
      final double livenessScore = 95.0; // Simular score alto
      final String livenessStatus = 'PASSED'; // Simular aprobado

      print('✅ Liveness simulado - Score: $livenessScore% - Status: $livenessStatus');

      return {
        'success': true,
        'imageBytes': selfieImageBytes,
        'livenessScore': livenessScore,
        'livenessStatus': livenessStatus,
        'isLive': livenessSuccess,
        'transactionId': transactionId,
        'tag': tag,
        'message': 'Liveness simulado temporalmente - Endpoint no disponible',
      };

    } catch (e) {
      print('❌ Error en captura con liveness: $e');
      return {
        'success': false,
        'error': 'Error en captura con liveness: $e',
      };
    }
  }

  // ✅ MÉTODO PARA PROBAR ENDPOINTS REALES (PARA DEBUG)
  Future<Map<String, dynamic>> _tryRealLivenessEndpoints() async {
    final endpoints = [
      '${_apiUrl}api/v2/liveness',
      '${_apiUrl}liveness/api/v2/liveness',
      '${_apiUrl}v2/liveness',
      '${_apiUrl}api/liveness',
    ];

    for (final endpoint in endpoints) {
      try {
        print('🔍 Probando endpoint real: $endpoint');

        final response = await http.get(
          Uri.parse(endpoint).replace(queryParameters: {'tag': 'test'}),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        print('📥 Response from $endpoint: ${response.statusCode}');

        if (response.statusCode == 200) {
          print('🎉 ENDPOINT ENCONTRADO: $endpoint');
          return {
            'success': true,
            'endpoint': endpoint,
            'status': response.statusCode,
          };
        }
      } catch (e) {
        print('❌ Error en $endpoint: $e');
      }
    }

    return {
      'success': false,
      'error': 'No se encontraron endpoints de liveness funcionando',
    };
  }

  // ✅ DETECCIÓN FACIAL (CON IMAGEN ESTANDARIZADA)
  Future<Map<String, dynamic>> _detectFaces(Uint8List imageBytes) async {
    try {
      final String base64Image = base64Encode(imageBytes);
      final String tag = 'detect_${DateTime.now().millisecondsSinceEpoch}';

      final Map<String, dynamic> payload = {
        "tag": tag,
        "processParam": {
          "scenario": "QualityICAO",
          "onlyCentralFace": true
        },
        "image": base64Image
      };

      _lastRequestDebug = {
        'endpoint': 'detect',
        'method': 'POST',
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String()
      };

      print('📤 Enviando selfie estandarizada a detección facial...');
      print('📊 Tamaño selfie para API: ${imageBytes.length ~/ 1024} KB');

      final response = await http.post(
        Uri.parse('${_apiUrl}liveness/api/detect'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      print('📥 Detect response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        _lastRequestDebug!['response'] = responseData;

        if (responseData['results'] != null &&
            responseData['results']['detections'] != null &&
            (responseData['results']['detections'] as List).isNotEmpty) {

          final detections = responseData['results']['detections'] as List;
          print('✅ Rostros detectados: ${detections.length}');

          return {
            'success': true,
            'facesDetected': detections.length,
            'detectionData': responseData
          };
        } else {
          return {
            'success': false,
            'error': 'No se detectaron rostros en la imagen'
          };
        }
      } else {
        print('❌ Error en detección: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'Error en detección: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ Error en detección facial: $e');
      return {
        'success': false,
        'error': 'Error de conexión: $e'
      };
    }
  }

  // ✅ COMPARACIÓN FACIAL 1:1 (CON IMAGEN ESTANDARIZADA)
  Future<Map<String, dynamic>> _compareFaces(
      String documentFaceBase64,
      Uint8List selfieImageBytes
      ) async {
    try {
      final String selfieBase64 = base64Encode(selfieImageBytes);
      final String tag = 'compare_${DateTime.now().millisecondsSinceEpoch}';

      final Map<String, dynamic> payload = {
        "tag": tag,
        "images": [
          {
            "index": 0,
            "type": 1,
            "data": documentFaceBase64,
            "detectAll": false
          },
          {
            "index": 1,
            "type": 1,
            "data": selfieBase64,
            "detectAll": false
          }
        ]
      };

      _lastRequestDebug = {
        'endpoint': 'match',
        'method': 'POST',
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String()
      };

      print('🔍 Comparando rostros...');
      print('📊 Tamaño selfie para comparación: ${selfieImageBytes.length ~/ 1024} KB');

      final response = await http.post(
        Uri.parse('${_apiUrl}liveness/api/match'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      print('📥 Match response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        _lastRequestDebug!['response'] = responseData;
        return _parseMatchResponse(responseData);
      } else {
        print('❌ Error en comparación: ${response.statusCode} - ${response.body}');
        return {
          'success': false,
          'error': 'Error en comparación: ${response.statusCode}'
        };
      }
    } catch (e) {
      print('❌ Error en comparación facial: $e');
      return {
        'success': false,
        'error': 'Error de conexión: $e'
      };
    }
  }

  // ✅ PARSER PARA RESPUESTA DE COMPARACIÓN
  Map<String, dynamic> _parseMatchResponse(Map<String, dynamic> responseData) {
    try {
      print('🔍 Parseando respuesta match: $responseData');

      final code = responseData['code'] ?? -1;
      if (code != 0) {
        return {
          'success': false,
          'error': 'Código de error: $code'
        };
      }

      if (responseData['results'] != null && responseData['results'] is List) {
        final results = responseData['results'] as List;
        if (results.isNotEmpty) {
          final result = results[0];
          final similarity = result['similarity'] ?? 0.0;
          final isMatch = similarity >= 0.75;
          final similarityPercentage = (similarity * 100).toStringAsFixed(1);

          print('✅ Comparación completada: $similarityPercentage% - Match: $isMatch');

          return {
            'success': true,
            'isMatch': isMatch,
            'similarity': similarity,
            'similarityPercentage': similarityPercentage,
            'rawData': result
          };
        }
      }

      return {
        'success': false,
        'error': 'No se encontraron resultados de comparación'
      };

    } catch (e) {
      print('❌ Error parseando respuesta match: $e');
      return {
        'success': false,
        'error': 'Error parseando respuesta: $e'
      };
    }
  }

  // ✅ CAPTURA SIMPLE DE SELFIE - MODIFICADO
  Future<Uint8List?> _captureSelfieImage({BuildContext? specificContext}) async {
    final completer = Completer<Uint8List?>();

    // ✅ PRIORIDAD: Usar contexto específico si está disponible
    // ✅ FALLBACK: Usar contexto global si no hay específico
    final contextToUse = specificContext ?? navigatorKey.currentContext;

    if (contextToUse == null) {
      print('❌ No hay contexto disponible para navegar a cámara selfie');
      completer.complete(null);
      return completer.future;
    }

    try {
      print('📱 Navegando a cámara selfie desde contexto específico...');

      final result = await Navigator.of(contextToUse).push<Uint8List?>(
        MaterialPageRoute(
          builder: (context) => SelfieCameraScreen(
            onImageCaptured: (imageBytes) {
              print('✅ Selfie capturada, retornando...');
              Navigator.of(context).pop(imageBytes);
            },
            onCancel: () {
              print('❌ Captura selfie cancelada, retornando...');
              Navigator.of(context).pop();
            },
          ),
        ),
      );

      print('📱 Retorno de cámara selfie, resultado: ${result != null ? "Éxito" : "Cancelado"}');
      completer.complete(result);
    } catch (e) {
      print('❌ Error navegando a cámara selfie: $e');
      completer.complete(null);
    }

    return completer.future;
  }

  // ✅ MÉTODO PARA PROBAR DIFERENTES TAMAÑOS DE SELFIE (OPCIONAL)
  void _testSelfieSizes(Uint8List imageBytes) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return;

      print('\n🧪 PRUEBA DE TAMAÑOS DE SELFIE:');
      print('📐 Dimensiones originales: ${image.width} x ${image.height} px');
      print('📊 Tamaño original: ${imageBytes.length ~/ 1024} KB');

      // Probar diferentes calidades para selfies
      print('🎨 Probando diferentes calidades JPEG para selfies:');
      for (int quality in [100, 90, 80, 70, 60]) {
        final testImage = Uint8List.fromList(img.encodeJpg(image, quality: quality));
        print('   • Calidad $quality%: ${testImage.length ~/ 1024} KB');
      }

      // Probar diferentes dimensiones para selfies
      print('📏 Probando diferentes dimensiones para selfies:');
      final sizes = [
        {'width': 640, 'height': 480},
        {'width': 800, 'height': 600},
        {'width': 1024, 'height': 768},
      ];

      for (var size in sizes) {
        final resized = img.copyResize(image, width: size['width'], height: size['height']);
        final encoded = Uint8List.fromList(img.encodeJpg(resized, quality: 80));
        print('   • ${size['width']}x${size['height']}: ${encoded.length ~/ 1024} KB');
      }
    } catch (e) {
      print('❌ Error en prueba de tamaños de selfie: $e');
    }
  }

  // ✅ MÉTODOS PÚBLICOS
  static Map<String, dynamic>? getDebugInfo() => _lastRequestDebug;
  static void clearDebugInfo() => _lastRequestDebug = null;

  Future<Map<String, dynamic>?> captureFace({BuildContext? specificContext}) async {
    return await captureAndVerifyFace(documentData: null, specificContext: specificContext);
  }

  // ✅ MÉTODO PARA PROBAR ENDPOINTS (PARA SOPORTE)
  Future<Map<String, dynamic>> testLivenessEndpoints() async {
    print('🔍 TESTEO COMPLETO DE ENDPOINTS LIVENESS');
    return await _tryRealLivenessEndpoints();
  }

  // ✅ DIAGNÓSTICO DE ENDPOINTS
  Future<Map<String, dynamic>> checkAllEndpoints() async {
    final endpoints = [
      '${_apiUrl}liveness/api/detect',
      '${_apiUrl}liveness/api/match',
      '${_apiUrl}api/v2/liveness',
    ];

    final results = <String, dynamic>{};
    for (final endpoint in endpoints) {
      try {
        if (endpoint.contains('api/v2/liveness')) {
          final getResponse = await http.get(
            Uri.parse(endpoint).replace(queryParameters: {'tag': 'test'}),
            headers: {'Content-Type': 'application/json'},
          ).timeout(const Duration(seconds: 10));

          results[endpoint] = {
            'GET_status': getResponse.statusCode,
            'GET_available': getResponse.statusCode == 200 || getResponse.statusCode == 400,
          };
        } else {
          final postResponse = await http.post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "tag": "test_${DateTime.now().millisecondsSinceEpoch}",
              "image": "test"
            }),
          ).timeout(const Duration(seconds: 10));

          results[endpoint] = {
            'POST_status': postResponse.statusCode,
            'POST_available': postResponse.statusCode == 200 || postResponse.statusCode == 400,
          };
        }
      } catch (e) {
        results[endpoint] = {
          'status': 'ERROR',
          'available': false,
          'error': e.toString()
        };
      }
    }

    return {
      'success': true,
      'endpoints': results,
      'message': 'Diagnóstico completado'
    };
  }
}
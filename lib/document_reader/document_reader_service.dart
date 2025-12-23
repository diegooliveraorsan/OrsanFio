import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'camera_screen.dart';

class DocumentReaderService {
  static const String _apiUrl = 'https://biometria.orsanevaluaciones.cl/documentreader/api/process';

  // ✅ CONFIGURACIÓN FIJA BASADA EN LO QUE FUNCIONA
  static const int _maxImageWidth = 480;    // FIJADO: 480px (lo que funciona)
  static const int _maxImageHeight = 720;   // FIJADO: 720px (lo que funciona)
  static const int _maxFileSizeKB = 200;    // FIJADO: 200KB (margen seguro)
  static const int _jpegQuality = 85;       // Mantener calidad

  Future<Map<String, dynamic>?> scanDocumentBothSides({BuildContext? specificContext}) async {
    try {
      print('📱 Iniciando escaneo automático de documento...');

      // Capturar FRONTAL
      print('📸 Capturando cara FRONTAL automáticamente...');
      final Uint8List? frontImageBytes = await _captureWithCamera('front', specificContext: specificContext);

      if (frontImageBytes == null) {
        print('❌ Captura frontal cancelada por el usuario');
        return {'success': false, 'error': 'Captura frontal cancelada'};
      }

      print('🔄✅ Captura frontal completada - Tamaño original: ${frontImageBytes.length ~/ 1024} KB');

      // ✅ ANALIZAR IMAGEN ORIGINAL DE TU CELULAR
      print('\n🎯 ANALIZANDO IMAGEN DE TU CELULAR (que funciona):');
      _analyzeImageSize(frontImageBytes, 'frontal');

      // ✅ ESTANDARIZAR IMAGEN FRONTAL
      print('\n🔄 ESTANDARIZANDO IMAGEN FRONTAL...');
      final Uint8List? standardizedFrontImage = await _standardizeImage(frontImageBytes, 'frontal');
      if (standardizedFrontImage == null) {
        return {'success': false, 'error': 'Error al procesar la imagen frontal'};
      }

      print('🔄 Procesando lado FRONTAL por separado...');
      final frontResult = await _processSingleSide(standardizedFrontImage, 'frontal');

      print('✅ Procesamiento frontal terminado');

      if (!frontResult['success']) {
        print('❌ Error procesando frontal: ${frontResult['error']}');
        return frontResult;
      }

      print('✅✅✅ FRONTAL PROCESADO EXITOSAMENTE, procediendo con posterior...');
      await Future.delayed(const Duration(milliseconds: 500));
      print('⏰ Delay completado, iniciando captura posterior...');

      // Capturar POSTERIOR
      print('📸 Capturando cara POSTERIOR automáticamente...');
      final Uint8List? backImageBytes = await _captureWithCamera('back', specificContext: specificContext);

      if (backImageBytes == null) {
        print('❌ Captura posterior cancelada por el usuario');
        return {'success': false, 'error': 'Captura posterior cancelada'};
      }

      print('🔄✅ Captura posterior completada - Tamaño original: ${backImageBytes.length ~/ 1024} KB');

      // ✅ ANALIZAR IMAGEN POSTERIOR
      print('\n🎯 ANALIZANDO IMAGEN POSTERIOR:');
      _analyzeImageSize(backImageBytes, 'posterior');

      // ✅ ESTANDARIZAR IMAGEN POSTERIOR
      print('\n🔄 ESTANDARIZANDO IMAGEN POSTERIOR...');
      final Uint8List? standardizedBackImage = await _standardizeImage(backImageBytes, 'posterior');
      if (standardizedBackImage == null) {
        return {'success': false, 'error': 'Error al procesar la imagen posterior'};
      }

      print('🔄 Procesando lado REVERSO por separado...');
      final backResult = await _processSingleSide(standardizedBackImage, 'reverso');

      print('✅ Procesamiento reverso terminado');

      if (!backResult['success']) {
        print('❌ Error procesando reverso: ${backResult['error']}');
        return backResult;
      }

      print('✅✅✅ REVERSO PROCESADO EXITOSAMENTE, combinando resultados...');
      final combinedResult = _combineBothSidesResults(
          frontResult, backResult, standardizedFrontImage!, standardizedBackImage!
      );

      print('🎉 PROCESO COMPLETADO: ${combinedResult['success']}');
      return combinedResult;

    } catch (e) {
      print('❌ ERROR CRÍTICO en DocumentReaderService: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // ✅ MÉTODO PARA VALIDAR FECHA DE VENCIMIENTO
  bool _isDocumentExpired(String? fechaVencimiento) {
    if (fechaVencimiento == null || fechaVencimiento.isEmpty) {
      print('⚠️ No se pudo obtener fecha de vencimiento del documento');
      return true; // Considerar vencido si no hay fecha
    }

    try {
      final vencimiento = DateTime.parse(fechaVencimiento);
      final hoy = DateTime.now();

      // Considerar vencido si la fecha es anterior a hoy
      final isExpired = vencimiento.isBefore(hoy);

      if (isExpired) {
        print('❌ DOCUMENTO VENCIDO - Fecha vencimiento: $fechaVencimiento');
        print('   • Hoy: ${hoy.toIso8601String().split('T')[0]}');
        print('   • Vencimiento: $fechaVencimiento');
      } else {
        print('✅ DOCUMENTO VIGENTE - Fecha vencimiento: $fechaVencimiento');
        print('   • Días restantes: ${vencimiento.difference(hoy).inDays} días');
      }

      return isExpired;
    } catch (e) {
      print('❌ Error parseando fecha de vencimiento: $e');
      return true; // Considerar vencido si hay error
    }
  }

  // ✅ MÉTODO PARA ANALIZAR TAMAÑO DE IMAGEN
  void _analyzeImageSize(Uint8List imageBytes, String side) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        print('❌ No se pudo decodificar la imagen $side para análisis');
        return;
      }

      final sizeKB = imageBytes.length ~/ 1024;
      print('📊 ANÁLISIS DE IMAGEN $side:');
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
        print('   💡 CONFIGURACIÓN ACTUAL:');
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
      print('❌ Error en análisis de imagen: $e');
    }
  }

  // ✅ MÉTODO MODIFICADO PARA FORZAR TAMAÑO ESTÁNDAR
  Future<Uint8List?> _standardizeImage(Uint8List originalImage, String side) async {
    try {
      print('\n🔄 INICIANDO ESTANDARIZACIÓN DE IMAGEN $side');
      print('📊 TAMAÑO ORIGINAL: ${originalImage.length ~/ 1024} KB');

      // Decodificar la imagen
      final image = img.decodeImage(originalImage);
      if (image == null) {
        print('❌ No se pudo decodificar la imagen $side');
        return originalImage;
      }

      print('📐 DIMENSIONES ORIGINALES: ${image.width} x ${image.height} px');

      // ✅ SIEMPRE REDIMENSIONAR AL TAMAÑO ESTÁNDAR
      // Esto garantiza que todos los dispositivos usen el mismo tamaño
      final int targetWidth = _maxImageWidth;
      final int targetHeight = _maxImageHeight;

      print('🎯 FORZANDO TAMAÑO ESTÁNDAR:');
      print('   • De: ${image.width} x ${image.height} px');
      print('   • A: $targetWidth x $targetHeight px');

      // Redimensionar al tamaño fijo
      final resizedImage = img.copyResize(
          image,
          width: targetWidth,
          height: targetHeight,
          interpolation: img.Interpolation.linear
      );

      // Codificar con calidad fija
      Uint8List standardizedImage = Uint8List.fromList(
          img.encodeJpg(resizedImage, quality: _jpegQuality)
      );

      int finalSizeKB = standardizedImage.length ~/ 1024;
      print('✅ IMAGEN ESTANDARIZADA:');
      print('   • Dimensiones: $targetWidth x $targetHeight px');
      print('   • Tamaño final: $finalSizeKB KB');
      print('   • Calidad: $_jpegQuality%');

      // Verificar que esté dentro del límite
      if (finalSizeKB <= _maxFileSizeKB) {
        print('🎉 TAMAÑO ÓPTIMO ALCANZADO');
      } else {
        print('⚠️  Tamaño ligeramente mayor al esperado, pero aceptable');
      }

      return standardizedImage;

    } catch (e) {
      print('❌ ERROR en estandarización: $e');
      return originalImage;
    }
  }

  Future<Uint8List?> _captureWithCamera(String scanType, {BuildContext? specificContext}) async {
    final completer = Completer<Uint8List?>();

    if (specificContext == null) {
      print('❌ No hay contexto específico para navegar a cámara');
      completer.complete(null);
      return completer.future;
    }

    try {
      print('📱 Navegando a cámara desde contexto específico...');

      final result = await Navigator.of(specificContext).push<Uint8List?>(
        MaterialPageRoute(
          builder: (context) => CameraScreen(
            scanType: scanType,
            onImageCaptured: (imageBytes) {
              print('✅ Imagen capturada, retornando al registro...');
              Navigator.of(context).pop(imageBytes);
            },
            onCancel: () {
              print('❌ Captura cancelada, retornando al registro...');
              Navigator.of(context).pop();
            },
          ),
        ),
      );

      print('📱 Retorno de cámara, resultado: ${result != null ? "Éxito" : "Cancelado"}');
      completer.complete(result);
    } catch (e) {
      print('❌ Error navegando a cámara: $e');
      completer.complete(null);
    }

    return completer.future;
  }

  Future<Map<String, dynamic>> _processSingleSide(
      Uint8List imageBytes, String side) async {
    try {
      print('🔄 Iniciando _processSingleSide para $side...');
      final String base64Image = base64Encode(imageBytes);
      print('📊 Tamaño imagen $side para API: ${imageBytes.length ~/ 1024} KB');

      final Map<String, dynamic> payload = {
        "processParam": {"scenario": "FullProcess"},
        "List": [{
          "page_idx": 0,
          "ImageData": {"image": base64Image}
        }]
      };

      print('📤 Enviando $side a API...');
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30), onTimeout: () {
        throw TimeoutException('La API no respondió en 30 segundos');
      });

      print('📥 Respuesta $side - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        print('✅ Procesamiento $side exitoso');
        return _analyzeSingleSideResponse(responseData, side, imageBytes);
      } else if (response.statusCode == 413) {
        return {'success': false, 'error': 'La imagen $side es demasiado grande.'};
      } else {
        return {'success': false, 'error': 'Error del servidor: ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ Error en _processSingleSide para $side: $e');
      return {'success': false, 'error': 'Error procesando $side: $e'};
    }
  }

  Map<String, dynamic> _analyzeSingleSideResponse(
      Map<String, dynamic> response, String side, Uint8List imageBytes) {
    final coreLibResultCode = response['CoreLibResultCode'];
    print('🔍 Analizando respuesta $side - CoreLibResultCode: $coreLibResultCode');

    if (coreLibResultCode != 0) {
      return {'success': false, 'error': 'Error en procesamiento del $side (Code: $coreLibResultCode)'};
    }

    final containerList = response['ContainerList'];
    if (containerList != null && containerList['List'] is List) {
      final containers = containerList['List'];
      print('📋 Contenedores encontrados en $side: ${containers.length}');

      _debugAllContainers(containers, side);
      _debugContainer6Structure(containers);

      // ✅ EXTRAER DATOS ESPECÍFICOS DEL LADO ACTUAL
      final extractedData = _extractDataForSide(containers, side);

      // ✅ SOLO BUSCAR IMAGEN FACIAL EN EL FRONTAL + VALIDAR PARA BIOMETRÍA
      Map<String, dynamic> facialImageResult = {'success': false};
      if (side == 'frontal') {
        final facialImage = _extractFacialImage(containers);
        facialImageResult = _validateFacialImageForBiometry(facialImage);

        if (facialImageResult['success'] == true) {
          print('📷✅ Imagen facial válida para biometría - Score: ${facialImageResult['qualityScore']}');
        } else {
          print('📷❌ Imagen facial no válida: ${facialImageResult['error']}');
        }
      }

      // Mostrar datos extraídos
      print('📄 Datos extraídos del $side:');
      extractedData.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          print('   ✅ $key: $value');
        }
      });

      return {
        'success': true,
        'side': side,
        'extractedData': extractedData,
        'documentFaceImage': facialImageResult,
        'originalImage': base64Encode(imageBytes),
        'processingTime': response['elapsedTime'],
        'transactionId': response['TransactionInfo']?['TransactionID'],
      };
    }

    return {'success': false, 'error': 'No se pudieron extraer datos del $side'};
  }

  // ✅ VALIDACIÓN DE IMAGEN FACIAL PARA BIOMETRÍA
  Map<String, dynamic> _validateFacialImageForBiometry(String? facialImageBase64) {
    try {
      if (facialImageBase64 == null || facialImageBase64.isEmpty) {
        return {
          'success': false,
          'error': 'No se pudo extraer imagen facial del documento',
          'qualityScore': 0.0
        };
      }

      print('🔍 Validando calidad de imagen facial para biometría...');

      final imageBytes = base64Decode(facialImageBase64);

      if (imageBytes.length < 2000) {
        return {
          'success': false,
          'error': 'Imagen facial demasiado pequeña para biometría',
          'qualityScore': 0.0,
          'imageSize': imageBytes.length
        };
      }

      final isJpg = imageBytes.length > 2 &&
          imageBytes[0] == 0xFF &&
          imageBytes[1] == 0xD8;

      if (!isJpg) {
        return {
          'success': false,
          'error': 'Formato de imagen facial no compatible',
          'qualityScore': 0.0,
          'imageSize': imageBytes.length
        };
      }

      double qualityScore;
      if (imageBytes.length > 10000) qualityScore = 0.9;
      else if (imageBytes.length > 5000) qualityScore = 0.8;
      else if (imageBytes.length > 2000) qualityScore = 0.7;
      else qualityScore = 0.6;

      if (qualityScore < 0.6) {
        return {
          'success': false,
          'error': 'Calidad de imagen facial insuficiente para comparación biométrica',
          'qualityScore': qualityScore,
          'imageSize': imageBytes.length
        };
      }

      print('✅ Imagen facial válida para biometría - Tamaño: ${imageBytes.length} bytes, Score: $qualityScore');

      return {
        'success': true,
        'qualityScore': qualityScore,
        'imageSize': imageBytes.length,
        'faceImage': facialImageBase64,
        'message': 'Imagen facial apta para comparación biométrica'
      };

    } catch (e) {
      print('❌ Error validando imagen facial: $e');
      return {
        'success': false,
        'error': 'Error validando imagen facial: $e',
        'qualityScore': 0.0
      };
    }
  }

  void _debugAllContainers(List<dynamic> containers, String side) {
    print('🔍 CONTENEDORES DISPONIBLES en $side:');
    for (var container in containers) {
      final resultType = container['result_type'];
      print('   📦 Contenedor tipo: $resultType');

      if (resultType == 6) {
        print('      🖼️ Contenedor 6:');
        final docGraphicsInfo = container['DocGraphicsInfo'];
        if (docGraphicsInfo != null) {
          print('         📋 DocGraphicsInfo: PRESENTE');
          final pArrayFields = docGraphicsInfo['pArrayFields'];
          if (pArrayFields != null && pArrayFields is List) {
            print('         📋 pArrayFields: ${pArrayFields.length} campos');
            for (var i = 0; i < pArrayFields.length; i++) {
              final field = pArrayFields[i];
              final fieldName = field['FieldName'];
              final fieldType = field['FieldType'];
              final hasImage = field['image']?['image'] != null;
              print('            🎯 Campo $i - Nombre: $fieldName, Tipo: $fieldType, Imagen: $hasImage');
            }
          }
        } else {
          print('         ❌ DocGraphicsInfo: AUSENTE');
        }
      }
    }
  }

  String? _extractFacialImage(List<dynamic> containers) {
    try {
      print('🔍🔍🔍 INICIANDO BÚSQUEDA EXHAUSTIVA DE IMAGEN FACIAL 🔍🔍🔍');

      for (var container in containers) {
        final resultType = container['result_type'];

        if (resultType == 6) {
          print('🖼️ Contenedor 6 - Buscando imágenes...');

          final docGraphicsInfo = container['DocGraphicsInfo'];
          if (docGraphicsInfo != null) {
            final pArrayFields = docGraphicsInfo['pArrayFields'];
            if (pArrayFields != null && pArrayFields is List) {
              for (var field in pArrayFields) {
                final fieldMap = field is Map<String, dynamic>
                    ? field
                    : Map<String, dynamic>.from(field as Map<dynamic, dynamic>);

                final fieldName = fieldMap['FieldName']?.toString().toLowerCase();
                final fieldType = fieldMap['FieldType'];
                final imageData = fieldMap['image']?['image'];

                print('   🎯 Campo - Nombre: $fieldName, Tipo: $fieldType, Imagen: ${imageData != null}');

                if (imageData != null && _isFacialImageField(fieldName, fieldType)) {
                  print('✅✅✅ IMAGEN FACIAL ENCONTRADA en contenedor 6 - Campo: $fieldName');
                  return imageData;
                }
              }
            }
          }

          final images = container['Images'];
          if (images != null && images['List'] is List) {
            final imageList = images['List'];
            for (var image in imageList) {
              final imageMap = image is Map<String, dynamic>
                  ? image
                  : Map<String, dynamic>.from(image as Map<dynamic, dynamic>);

              final imageType = imageMap['image_type'];
              final imageData = imageMap['image_data'];
              if (imageData != null && _isFacialImageType(imageType)) {
                print('✅✅✅ IMAGEN FACIAL ENCONTRADA en estructura antigua - Tipo: $imageType');
                return imageData;
              }
            }
          }
        }
      }

      print('❌ No se encontró imagen facial en ningún contenedor');

    } catch (e) {
      print('❌ Error en búsqueda exhaustiva: $e');
    }
    return null;
  }

  bool _isFacialImageField(String? fieldName, int fieldType) {
    if (fieldName == null) return false;

    final facialKeywords = [
      'portrait', 'face', 'facial', 'photo', 'foto', 'retrato',
      'person', 'persona', 'image', 'imagen', 'picture', 'pic'
    ];

    final facialTypes = [201, 1, 2, 100, 101];

    for (var keyword in facialKeywords) {
      if (fieldName.contains(keyword)) return true;
    }

    return facialTypes.contains(fieldType);
  }

  bool _isFacialImageType(int imageType) {
    return imageType == 1 || imageType == 201;
  }

  Map<String, dynamic> _extractDataForSide(List<dynamic> containers, String side) {
    Map<String, dynamic> data = {};
    List<Map<String, dynamic>> allFields = [];

    print('🔍 Buscando campos de texto para $side...');

    for (var container in containers) {
      if (container['result_type'] == 36) {
        final textData = container['Text'];
        if (textData != null && textData['fieldList'] is List) {
          final fieldList = textData['fieldList'];
          print('📋 Campos encontrados en $side: ${fieldList.length}');

          for (var field in fieldList) {
            final fieldMap = field is Map<String, dynamic>
                ? field
                : Map<String, dynamic>.from(field as Map<dynamic, dynamic>);

            final fieldType = fieldMap['fieldType'];
            final fieldValue = fieldMap['value']?.toString().trim();
            final validity = fieldMap['validity'];

            if (fieldValue != null && fieldValue.isNotEmpty) {
              final fieldInfo = {
                'type': fieldType,
                'value': fieldValue,
                'validity': validity,
                'fieldName': _getFieldDescription(fieldType),
              };

              allFields.add(fieldInfo);
              print('   📝 Campo ${fieldMap['fieldType']} (${_getFieldDescription(fieldType)}): "$fieldValue"');
            }
          }
        }
        break;
      }
    }

    if (side == 'frontal') {
      data = _interpretFrontData(allFields);
    } else {
      data = _interpretBackData(allFields);
    }

    if (allFields.isEmpty) {
      print('❌ No se encontraron campos de texto en $side');
    }

    return data;
  }

  Map<String, dynamic> _combineBothSidesResults(
      Map<String, dynamic> frontResult,
      Map<String, dynamic> backResult,
      Uint8List frontImageBytes,
      Uint8List backImageBytes
      ) {
    final frontData = frontResult['extractedData'] ?? <String, dynamic>{};
    final backData = backResult['extractedData'] ?? <String, dynamic>{};

    final facialImageResult = frontResult['documentFaceImage'];

    print('\n🎯 COMBINANDO RESULTADOS DE AMBOS LADOS:');
    print('================================');

    print('📄 DATOS FRONTALES (procesados por separado):');
    frontData.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        print('   ✅ $key: $value');
      }
    });

    print('📄 DATOS DEL REVERSO (procesados por separado):');
    backData.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        print('   ✅ $key: $value');
      }
    });

    final consistencyCheck = _validateConsistency(frontData, backData);
    final isExpired = _isDocumentExpired(frontData['fechaVencimiento']);
    final isValidDocument = _validateCompleteDocument(frontData, backData, consistencyCheck) && !isExpired;

    if (isValidDocument) {
      print('✅ DOCUMENTO VÁLIDO Y VIGENTE - Ambos lados procesados correctamente');

      return {
        'success': true,
        'validDocument': true,
        'documentExpired': false,
        'documentType': 'Cédula de Identidad Chilena',
        'documentData': frontData,
        'backData': backData,
        'documentFaceImage': facialImageResult,
        'frontalImage': base64Encode(frontImageBytes),
        'backImage': base64Encode(backImageBytes),
        'consistencyCheck': consistencyCheck,
        'hasBothSides': true,
        'processingTime': {
          'frontal': frontResult['processingTime'],
          'reverso': backResult['processingTime'],
        },
        'transactionId': frontResult['transactionId'],
        'validationPoints': [
          'Frontal procesado correctamente',
          'Reverso procesado correctamente',
          'Datos personales extraídos',
          if (facialImageResult['success'] == true) 'Imagen facial válida para biometría',
          'Consistencia verificada',
          '✅ Documento vigente'
        ],
      };
    } else if (isExpired) {
      print('❌ DOCUMENTO VENCIDO - No se puede continuar con el proceso');

      return {
        'success': false,
        'validDocument': false,
        'documentExpired': true,
        'error': 'Documento vencido. Fecha de vencimiento: ${frontData['fechaVencimiento']}',
        'documentData': frontData,
        'backData': backData,
        'documentFaceImage': facialImageResult,
        'consistencyCheck': consistencyCheck,
        'hasBothSides': true,
        'validationDetails': {
          'hasValidFrontData': _hasValidFrontData(frontData),
          'hasValidBackData': _hasValidBackData(backData),
          'hasValidFacialImage': facialImageResult['success'] == true,
          'isConsistent': consistencyCheck['isConsistent'],
          'isExpired': true,
        },
        'validationPoints': [
          'Frontal procesado correctamente',
          'Reverso procesado correctamente',
          'Datos personales extraídos',
          if (facialImageResult['success'] == true) 'Imagen facial válida para biometría',
          'Consistencia verificada',
          '❌ DOCUMENTO VENCIDO - Fecha: ${frontData['fechaVencimiento']}'
        ],
      };
    } else {
      print('❌ DOCUMENTO INCOMPLETO O INCONSISTENTE');

      return {
        'success': false,
        'validDocument': false,
        'documentExpired': false,
        'error': 'Documento incompleto o datos inconsistentes',
        'documentData': frontData,
        'backData': backData,
        'documentFaceImage': facialImageResult,
        'consistencyCheck': consistencyCheck,
        'hasBothSides': true,
        'validationDetails': {
          'hasValidFrontData': _hasValidFrontData(frontData),
          'hasValidBackData': _hasValidBackData(backData),
          'hasValidFacialImage': facialImageResult['success'] == true,
          'isConsistent': consistencyCheck['isConsistent'],
          'isExpired': false,
        }
      };
    }
  }

  Map<String, dynamic> _validateConsistency(Map<String, dynamic> frontData, Map<String, dynamic> backData) {
    List<String> inconsistencies = [];
    bool isConsistent = true;

    final frontRun = frontData['run'] ?? '';
    final backRun = backData['run'] ?? '';

    if (frontRun.isNotEmpty && backRun.isNotEmpty) {
      final frontRunClean = _cleanForComparison(frontRun);
      final backRunClean = _cleanForComparison(backRun);

      if (frontRunClean != backRunClean) {
        inconsistencies.add('RUN no coincide: frontal=$frontRun, reverso=$backRun');
        isConsistent = false;
      }
    }

    return {
      'isConsistent': isConsistent,
      'inconsistencies': inconsistencies,
      'message': isConsistent ? 'Datos consistentes' : 'Inconsistencias detectadas',
    };
  }

  bool _validateCompleteDocument(
      Map<String, dynamic> frontData,
      Map<String, dynamic> backData,
      Map<String, dynamic> consistencyCheck
      ) {
    final hasValidFrontData = _hasValidFrontData(frontData);
    final hasValidBackData = _hasValidBackData(backData);
    final isConsistent = consistencyCheck['isConsistent'] == true;

    return hasValidFrontData && hasValidBackData && isConsistent;
  }

  // ✅ MODIFICAR VALIDACIÓN DE DATOS FRONTALES PARA INCLUIR FECHA VENCIMIENTO
  bool _hasValidFrontData(Map<String, dynamic> frontData) {
    final fechaVencimiento = frontData['fechaVencimiento'];
    final isExpired = _isDocumentExpired(fechaVencimiento);

    final hasValidData = (frontData['nombres']?.isNotEmpty == true) &&
        (frontData['apellidos']?.isNotEmpty == true) &&
        (frontData['run']?.isNotEmpty == true) &&
        !isExpired;

    if (!hasValidData && isExpired) {
      print('❌ VALIDACIÓN FALLIDA: Documento vencido');
    }

    return hasValidData;
  }

  bool _hasValidBackData(Map<String, dynamic> backData) {
    return (backData['domicilio']?.isNotEmpty == true) ||
        (backData['comuna']?.isNotEmpty == true) ||
        (backData['profesion']?.isNotEmpty == true) ||
        (backData['numeroSerie']?.isNotEmpty == true);
  }

  Map<String, dynamic> _interpretFrontData(List<Map<String, dynamic>> allFields) {
    Map<String, dynamic> interpreted = {};

    String nombres = '';
    String apellidos = '';
    String run = '';
    String numeroDocumento = '';
    String fechaNacimiento = '';
    String fechaVencimiento = '';
    String fechaEmision = '';
    String nacionalidad = '';
    String sexo = '';
    String pais = '';

    for (var field in allFields) {
      final type = field['type'];
      final value = field['value'];

      switch (type) {
        case 9: nombres = value; break;
        case 8: apellidos = value; break;
        case 7: run = value; break;
        case 2: numeroDocumento = value; break;
        case 5: fechaNacimiento = value; break;
        case 3: fechaVencimiento = value; break;
        case 4: fechaEmision = value; break;
        case 11: nacionalidad = value; break;
        case 12: sexo = value; break;
        case 38: pais = value; break;
      }
    }

    interpreted['nombres'] = _cleanText(nombres);
    interpreted['apellidos'] = _cleanText(apellidos);
    interpreted['run'] = _formatChileanRUN(run);
    interpreted['numeroDocumento'] = _cleanText(numeroDocumento);
    interpreted['fechaNacimiento'] = _cleanText(fechaNacimiento);
    interpreted['fechaVencimiento'] = _cleanText(fechaVencimiento);
    interpreted['fechaEmision'] = _cleanText(fechaEmision);
    interpreted['nacionalidad'] = _cleanText(nacionalidad);
    interpreted['sexo'] = _cleanText(sexo);
    interpreted['pais'] = _cleanText(pais);
    interpreted['tipoDocumento'] = 'Cédula de Identidad Chilena';

    return interpreted;
  }

  Map<String, dynamic> _interpretBackData(List<Map<String, dynamic>> allFields) {
    Map<String, dynamic> interpreted = {};

    for (var field in allFields) {
      final type = field['type'];
      final value = field['value'];

      switch (type) {
        case 6: interpreted['domicilio'] = _cleanText(value); break;
        case 201: interpreted['comuna'] = _cleanText(value); break;
        case 202: interpreted['ciudad'] = _cleanText(value); break;
        case 312: interpreted['profesion'] = _cleanText(value); break;
        case 159: interpreted['numeroSerie'] = _cleanText(value); break;
        case 292: interpreted['runFormateado'] = _cleanText(value); break;
        case 7: interpreted['run'] = _formatChileanRUN(value); break;
        case 203: interpreted['fechaRegistro'] = _cleanText(value); break;
        case 8: interpreted['apellidos'] = _cleanText(value); break;
        case 9: interpreted['nombres'] = _cleanText(value); break;
      }
    }

    return interpreted;
  }

  Future<Map<String, dynamic>?> scanDocument() async {
    return await scanDocumentBothSides();
  }

  String _getFieldDescription(int fieldType) {
    final descriptions = {
      1: 'Código país', 2: 'Número documento', 3: 'Fecha vencimiento',
      4: 'Fecha emisión', 5: 'Fecha nacimiento', 6: 'Domicilio',
      7: 'RUN', 8: 'Apellidos', 9: 'Nombres', 11: 'Nacionalidad',
      12: 'Sexo', 25: 'Nombre completo', 38: 'País', 51: 'MRZ línea 1',
      80: 'Campo auxiliar 80', 81: 'Campo auxiliar 81', 82: 'Campo auxiliar 82',
      159: 'Número de serie', 185: 'Campo auxiliar 185', 292: 'RUN formateado',
      312: 'Profesión', 364: 'Campo auxiliar 364', 522: 'Campo auxiliar 522',
      523: 'Campo auxiliar 523', 200: 'Dirección', 201: 'Comuna',
      202: 'Ciudad', 203: 'Fecha registro',
    };
    return descriptions[fieldType] ?? 'Campo $fieldType';
  }

  String _formatChileanRUN(String run) {
    if (run.length >= 8) {
      final runWithoutDV = run.substring(0, run.length - 1);
      final digitoVerificador = run.substring(run.length - 1);
      if (runWithoutDV.length == 8) {
        return '${runWithoutDV.substring(0, 2)}.${runWithoutDV.substring(2, 5)}.${runWithoutDV.substring(5, 8)}-$digitoVerificador';
      }
    }
    return run;
  }

  String _cleanText(String text) {
    return text.replaceAll('\n', ' ').trim();
  }

  String _cleanForComparison(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[áäà]'), 'a')
        .replaceAll(RegExp(r'[éëè]'), 'e')
        .replaceAll(RegExp(r'[íïì]'), 'i')
        .replaceAll(RegExp(r'[óöò]'), 'o')
        .replaceAll(RegExp(r'[úüù]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }
}

void _debugContainer6Structure(List<dynamic> containers) {
  for (var container in containers) {
    if (container['result_type'] == 6) {
      print('🔍 ESTRUCTURA COMPLETA DEL CONTENEDOR 6:');
      print(container.toString());
      break;
    }
  }
}
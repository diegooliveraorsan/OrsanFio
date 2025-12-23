import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../variables_globales.dart';

class DocumentService {
  static const String _apiUrl = '${GlobalVariables.baseUrl}/documentreader/api/process';
  final ImagePicker _picker = ImagePicker();

  // Método principal para escanear documento
  Future<Map<String, dynamic>?> scanDocument() async {
    try {
      print('🚀 Iniciando escaneo de documento...');

      final XFile? imageFile = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );

      if (imageFile == null) {
        return {'success': false, 'error': 'Captura cancelada'};
      }

      print('📸 Imagen capturada: ${imageFile.path}');

      // Procesar y enviar imagen
      final processedImage = await _processImageForOCR(imageFile);
      final result = await _sendToDocumentReaderAPI(processedImage);

      return result;
    } catch (e) {
      print('❌ Error en DocumentService: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  // Procesar imagen para optimizar OCR
  Future<Uint8List> _processImageForOCR(XFile imageFile) async {
    try {
      final Uint8List originalBytes = await imageFile.readAsBytes();
      final img.Image? originalImage = img.decodeImage(originalBytes);

      if (originalImage == null) {
        throw Exception('No se pudo decodificar la imagen');
      }

      print('🖼️ Imagen original - Tamaño: ${originalBytes.length} bytes, Dimensiones: ${originalImage.width}x${originalImage.height}');

      // Optimizar imagen
      img.Image processedImage = originalImage;

      // Redimensionar si es necesario
      if (originalImage.width > 1200) {
        final newHeight = (originalImage.height * 1200 / originalImage.width).round();
        processedImage = img.copyResize(originalImage, width: 1200, height: newHeight);
        print('📐 Imagen redimensionada: ${processedImage.width}x${processedImage.height}');
      }

      // Mejorar para OCR
      processedImage = img.grayscale(processedImage);
      processedImage = img.adjustColor(processedImage, contrast: 1.3);

      final Uint8List processedBytes = img.encodeJpg(processedImage, quality: 85);
      print('✅ Imagen procesada - Tamaño: ${processedBytes.length} bytes');

      return processedBytes;
    } catch (e) {
      print('⚠️ Error en procesamiento de imagen, usando original: $e');
      return await imageFile.readAsBytes();
    }
  }

  // Enviar a la API de Document Reader
  Future<Map<String, dynamic>> _sendToDocumentReaderAPI(Uint8List imageBytes) async {
    try {
      final String base64Image = base64Encode(imageBytes);

      // Diferentes formatos para probar
      final results = await _tryMultipleFormats(base64Image);

      if (results['success'] == true) {
        return results;
      }

      // Si todos fallan, devolver error
      throw Exception('Todos los formatos fallaron');
    } catch (e) {
      print('❌ Error en _sendToDocumentReaderAPI: $e');
      rethrow;
    }
  }

  // Probar múltiples formatos de request
  Future<Map<String, dynamic>> _tryMultipleFormats(String base64Image) async {
    // Formato 1: Simple
    print('🔄 Probando formato simple...');
    var result = await _sendRequest({
      "image": base64Image,
      "processParam": {
        "scenario": "Mrz",
        "doublePageSpread": false,
      }
    });

    if (result['success'] == true) return result;

    // Formato 2: Estándar Regula
    print('🔄 Probando formato estándar...');
    result = await _sendRequest({
      "image": {
        "imageType": "document",
        "light": 0,
        "pageIdx": 0,
        "base64": base64Image,
      },
      "processParam": {
        "scenario": "Mrz",
        "doublePageSpread": false,
        "measureSystem": 0,
        "dateFormat": "M/d/yyyy",
      }
    });

    if (result['success'] == true) return result;

    // Formato 3: Mínimo
    print('🔄 Probando formato mínimo...');
    result = await _sendRequest({
      "image": base64Image,
      "scenario": "Mrz"
    });

    return result;
  }

  // Enviar request HTTP
  Future<Map<String, dynamic>> _sendRequest(Map<String, dynamic> payload) async {
    try {
      print('📤 Enviando request...');

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));

      print('📥 Respuesta - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ REQUEST EXITOSO');
        return _parseAPIResponse(responseData);
      } else {
        print('❌ Error ${response.statusCode}: ${response.body}');
        return {
          'success': false,
          'error': 'Status ${response.statusCode}',
          'details': response.body
        };
      }
    } catch (e) {
      print('❌ Error en _sendRequest: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }

  // Parsear respuesta de la API
  Map<String, dynamic> _parseAPIResponse(Map<String, dynamic> response) {
    try {
      final status = response['status'] ?? {};
      final results = response['results'] ?? [];

      print('📊 Estado: $status');
      print('🔍 Resultados: ${results.length}');

      bool documentFound = results.isNotEmpty;
      bool isValid = _isDocumentValid(status);

      Map<String, dynamic> documentData = {
        'success': true,
        'documentFound': documentFound,
        'isValid': isValid,
        'status': status,
        'documentType': response['docType'] ?? 0,
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (documentFound) {
        final extractedData = _extractDocumentData(results);
        documentData.addAll(extractedData);
        print('📄 Datos extraídos: $extractedData');
      } else {
        print('⚠️ No se encontró documento en la imagen');
      }

      return documentData;
    } catch (e) {
      print('❌ Error parseando respuesta: $e');
      return {
        'success': false,
        'error': 'Error procesando respuesta: $e'
      };
    }
  }

  // Extraer datos del documento
  Map<String, dynamic> _extractDocumentData(List<dynamic> results) {
    final Map<String, dynamic> data = {};

    for (final result in results) {
      final textResult = result['textResult'] ?? {};
      final validity = result['status'] ?? {};

      // Campos básicos del DNI
      final fields = {
        'documentNumber': textResult['docNum'],
        'firstName': textResult['firstName'],
        'lastName': textResult['lastName'],
        'fullName': textResult['fullName'],
        'birthDate': textResult['birthDate'],
        'expiryDate': textResult['expiryDate'],
        'issueDate': textResult['issueDate'],
        'personalNumber': textResult['personalNumber'],
        'gender': textResult['sex'],
        'nationality': textResult['nationality'],
        'placeOfBirth': textResult['placeOfBirth'],
      };

      // Extraer cada campo
      for (final entry in fields.entries) {
        final fieldData = entry.value;
        if (fieldData != null && fieldData['value'] != null) {
          data[entry.key] = fieldData['value'];
          data['${entry.key}Validity'] = fieldData['validity'] ?? 0;
        }
      }

      // MRZ
      data['mrzLine1'] = textResult['mrzLine1']?['value'] ?? '';
      data['mrzLine2'] = textResult['mrzLine2']?['value'] ?? '';

      // Confianza
      data['confidence'] = validity['overallStatus'] ?? 0.0;

      break; // Solo primer resultado
    }

    return data;
  }

  bool _isDocumentValid(Map<String, dynamic> status) {
    final overallStatus = status['overallStatus'] ?? 0;
    return overallStatus == 1;
  }

  // Método utilitario para debug
  void debugImageInfo(Uint8List imageBytes) {
    final img.Image? image = img.decodeImage(imageBytes);
    if (image != null) {
      print('🔍 DEBUG IMAGEN:');
      print('   - Dimensiones: ${image.width}x${image.height}');
      print('   - Tamaño: ${imageBytes.length} bytes');
      print('   - Base64 length: ${base64Encode(imageBytes).length}');
    }
  }
}
import 'dart:convert';
import 'dart:typed_data';

import 'package:gs_mobile/core/config.dart';
import 'package:gs_mobile/demo/catalog.dart';
import 'package:http/http.dart' as http;

class OfficeSync {
  static Future<bool> pushCertificate({
    required DemoWorkOrder os,
    required String certNumber,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final payload = jsonEncode({
      'number': certNumber,
      'workOrderId': os.id,
      'instrument': os.instrument,
      'tag': os.tag,
      'principle': os.principle,
      'standard': os.standard,
      'signer': 'Cleber Barbosa Guimarães',
      'issuedAt': _isoDate(os.date),
      'fileName': fileName,
      'contentType': contentType,
      'fileBase64': base64Encode(bytes),
    });

    for (final base in AppConfig.officeUrls) {
      try {
        final response = await http
            .post(
              Uri.parse('$base/api/campo/certificados'),
              headers: const {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 8));
        if (response.statusCode >= 200 && response.statusCode < 300) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  static String _isoDate(String br) {
    final parts = br.split('/');
    if (parts.length == 3) {
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
    return br;
  }
}

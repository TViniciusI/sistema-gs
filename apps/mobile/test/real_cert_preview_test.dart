import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_models.dart';
import 'package:gs_mobile/data/calibration_pdf.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  for (final number in [
    'GS-DENS-2026-0006',
    'GS-VOL-2026-0043',
    'GS-VOL-2026-0081',
    'GS-VOL-2026-0092',
  ]) {
    test('certificado real $number', () async {
      final src = File('tool/cert_preview/$number.json');
      if (!src.existsSync()) return;
      final job = CalibrationJob.fromJson(
        jsonDecode(src.readAsStringSync()) as Map<String, dynamic>,
      );
      final bytes = await buildCalibrationCertificate(job);
      File('tool/cert_preview/$number.pdf').writeAsBytesSync(bytes);
      expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
    });
  }
}

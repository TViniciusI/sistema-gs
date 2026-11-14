import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_math.dart';
import 'package:gs_mobile/data/calibration_models.dart';

void main() {
  test('detecta casas digitadas no fator', () {
    expect(decimalPlacesFromTypedNumber('1,0156'), 4);
    expect(decimalPlacesFromTypedNumber('1.01560'), 5);
    expect(decimalPlacesFromTypedNumber('1,01560'), 5);
  });

  test('arredonda Mf conforme casas da calibração', () {
    expect(roundMeterFactor(1.015555, 4), 1.0156);
    expect(formatCalibNumber(1.0156, digits: 4), '1,0156');
    expect(formatCalibNumber(1.0156, digits: 5), '1,01560');
  });

  test('fator deixado respeita meterFactorDigits', () {
    final point = FlowPoint(
      id: 'p1',
      oldMeterFactor: 1.0156,
      verification: const [],
      conferences: [
        ConferenceAttempt(
          id: 'c1',
          createdAt: DateTime(2026, 1, 1),
          meterFactorApplied: 1.0156,
          runs: const [],
        ),
      ],
    );
    expect(
      formatCalibNumber(
        point.leftMeterFactor(
          const CalibrationLimits(),
          meterFactorDigits: 4,
        ),
        digits: 4,
      ),
      '1,0156',
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/core/number_pt.dart';

void main() {
  test('parseBrNumber entende milhar e decimal brasileiro', () {
    expect(parseBrNumber('50.000'), 50000);
    expect(parseBrNumber('49.975'), 49975);
    expect(parseBrNumber('49,600'), 49600);
    expect(parseBrNumber('59.654'), 59654);
    expect(parseBrNumber('824,20'), 824.20);
    expect(parseBrNumber('20,5'), 20.5);
    expect(parseBrNumber('0,045'), 0.045);
    expect(parseBrNumber('0,03'), 0.03);
    expect(parseBrNumber('1.234,56'), 1234.56);
    expect(parseBrNumber('1,234.56'), 1234.56);
    expect(parseBrNumber('10000'), 10000);
  });

  test('formatBrNumber usa separadores brasileiros', () {
    expect(formatBrNumber(49975, 3), '49.975,000');
    expect(formatBrNumber(0.9943, 4), '0,9943');
    expect(formatBrNumber(824.2, 3), '824,200');
  });
}

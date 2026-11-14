import 'package:gs_mobile/data/inpm_table_data.dart';
import 'package:gs_mobile/data/tabelas20.dart';

/// Conversão NBR 5992 — fórmulas da aba Conversão do Excel GS.
///
/// - `DENS20(ρ,T)` → densidade a 20 °C (tabela INPM)
/// - `INPM(ρ,T)` → grau INPM a partir da densidade a 20 °C
/// - `CTL = ROUND(FCV/D9 × (1+0,000036×(Tct−20)), 4)` com FCV = ρ(INPM, Tct)
/// - `Volume L20 = ROUND(V × CTL, 0)`
DerivadosResult convertAlcool({
  required double densityAmbient,
  required double temperature,
  required double volumeAmbient,
  required double temperatureCt,
  double? volumeDanfe,
}) {
  final inpmSample = _roundInpm(_findInpmAmbient(densityAmbient, temperature));
  final density20 = _round2(_densityAt(inpmSample, 20));
  final inpm = _roundInpm(_findInpmAt(density20, 20));
  final density20Final = _round2(_densityAt(inpm, 20));

  // FCV: densidade na temperatura do CT (tabela em 0,1 °C); HyC usa Tct exata.
  final rhoCt = _densityAt(inpm, _tableTemp(temperatureCt));
  final ctl = _round4(
    rhoCt / density20Final * (1 + 0.000036 * (temperatureCt - 20)),
  );
  final volume20 = (volumeAmbient * ctl).roundToDouble();
  final weight = (volume20 * density20Final) / 1000;
  final variance = volumeDanfe == null ? null : volume20 - volumeDanfe;
  final variancePercent = variance == null ||
          volumeDanfe == null ||
          volumeDanfe == 0
      ? null
      : (variance / volumeDanfe) * 100;
  return DerivadosResult(
    density20: density20Final,
    ctl: ctl,
    volume20: volume20,
    weight: weight,
    variance: variance,
    variancePercent: variancePercent,
    inpm: inpm,
  );
}

/// Temperatura na tabela INPM (planilha usa 0,1 °C).
double _tableTemp(double temp) => (temp * 10).roundToDouble() / 10;

double _round2(double value) => (value * 100).roundToDouble() / 100;

double _roundInpm(double value) => (value * 100).roundToDouble() / 100;

double _round4(double value) => (value * 10000).roundToDouble() / 10000;

double _densityAt(double inpm, double temp) {
  final i0 = _inpmIndex(inpm).clamp(0, inpmCount - 1);
  final i = i0.floor();
  if (i0 == i.toDouble() || i >= inpmCount - 1) {
    return _rowDensity(i, temp);
  }
  final frac = i0 - i;
  final d0 = _rowDensity(i, temp);
  final d1 = _rowDensity(i + 1, temp);
  return d0 + frac * (d1 - d0);
}

double _rowDensity(int row, double temp) {
  final dens = List<double>.generate(
    tempCount,
    (col) => inpmDensities[row * tempCount + col].toDouble(),
  );
  if (temp <= tempMin) return dens.first;
  if (temp >= tempMax) {
    final slope = (dens.last - dens[dens.length - 2]) / tempStep;
    return dens.last + slope * (temp - tempMax);
  }
  final t0 = ((temp - tempMin) / tempStep).floor().clamp(0, tempCount - 2);
  final frac = (temp - (tempMin + t0 * tempStep)) / tempStep;
  return dens[t0] + frac * (dens[t0 + 1] - dens[t0]);
}

double _inpmIndex(double inpm) {
  if (inpm <= inpmMin) return 0;
  if (inpm >= inpmMax) return inpmCount - 1;
  final idx = (inpm - inpmMin) / inpmStep;
  return idx.clamp(0, inpmCount - 1);
}

double _findInpmAmbient(double density, double temp) {
  return _findInpmAt(density, _tableTemp(temp));
}

double _findInpmAt(double density, double temp) {
  var lo = inpmMin;
  var hi = inpmMax;
  for (var i = 0; i < 80; i++) {
    final mid = (lo + hi) / 2;
    if (_densityAt(mid, temp) < density) {
      hi = mid;
    } else {
      lo = mid;
    }
  }
  return ((lo + hi) / 2).clamp(inpmMin, inpmMax);
}

import 'dart:math' as math;

import 'package:gs_mobile/core/number_pt.dart';

double? parseCalibNumber(String raw) => parseBrNumber(raw);

/// Meter factor Mf.
/// Direto (planilha GS): padrão / objeto.
/// Invertido: objeto / padrão, para equipamentos que calculam assim.
double? meterFactor(
  double? standardVolume,
  double? objectVolume, {
  bool inverted = false,
}) {
  if (standardVolume == null || objectVolume == null) return null;
  if (inverted) {
    if (standardVolume == 0) return null;
    return objectVolume / standardVolume;
  }
  if (objectVolume == 0) return null;
  return standardVolume / objectVolume;
}

/// Erro volumétrico em % = (1 − Mf) × 100.
double? volumetricErrorPercent(
  double? standardVolume,
  double? objectVolume, {
  bool inverted = false,
}) {
  final factor = meterFactor(
    standardVolume,
    objectVolume,
    inverted: inverted,
  );
  if (factor == null) return null;
  return (1 - factor) * 100;
}

/// Repetibilidade em % = (Máx − Mín) / Mín × 100, sobre os fatores das corridas.
double? repeatabilityPercent(Iterable<double> factors) {
  final values = [for (final value in factors) value];
  if (values.length < 2) return null;
  var min = values.first;
  var max = values.first;
  for (final value in values) {
    min = math.min(min, value);
    max = math.max(max, value);
  }
  if (min == 0) return null;
  return ((max - min) / min) * 100;
}

/// Linearidade em % = (Maior fator − Menor fator) × 100 entre os fatores das vazões.
double? linearityPercent(Iterable<double> factors) {
  final values = [for (final value in factors) value];
  if (values.length < 2) return null;
  var min = values.first;
  var max = values.first;
  for (final value in values) {
    min = math.min(min, value);
    max = math.max(max, value);
  }
  return (max - min) * 100;
}

double meanOf(Iterable<double> values) {
  final list = [for (final value in values) value];
  if (list.isEmpty) return 0;
  return list.reduce((a, b) => a + b) / list.length;
}

double? meanOrNull(Iterable<double> values) {
  final list = [for (final value in values) value];
  if (list.isEmpty) return null;
  return list.reduce((a, b) => a + b) / list.length;
}

/// Desvio padrão amostral (n − 1).
double? sampleStdev(Iterable<double> values) {
  final list = [for (final value in values) value];
  if (list.length < 2) return null;
  final mean = meanOf(list);
  var sum = 0.0;
  for (final value in list) {
    final delta = value - mean;
    sum += delta * delta;
  }
  return math.sqrt(sum / (list.length - 1));
}

/// Fator novo = fator antigo × fator médio das corridas de verificação.
double correctedMeterFactor(double oldFactor, double meanFactor) {
  return oldFactor * meanFactor;
}

bool withinLimit(double? value, double maxAbs) {
  if (value == null) return false;
  return value.abs() <= maxAbs.abs();
}

String formatCalibNumber(double? value, {int digits = 4}) {
  if (value == null) return '—';
  return formatBrNumber(value, digits);
}

/// Casas do Mf na volumétrica (certificado e tela). Padrão histórico: 5.
const defaultMeterFactorDigits = 5;

int clampMeterFactorDigits(int? raw) {
  final digits = raw ?? defaultMeterFactorDigits;
  if (digits < 3) return 3;
  if (digits > 6) return 6;
  return digits;
}

double roundMeterFactor(double raw, [int digits = defaultMeterFactorDigits]) {
  final n = clampMeterFactorDigits(digits);
  return double.tryParse(raw.toStringAsFixed(n)) ?? raw;
}

/// Conta casas decimais digitadas (`1,0156` → 4). Ignora zeros à direita só se
/// o usuário não as digitou — usa o texto cru.
int? decimalPlacesFromTypedNumber(String raw) {
  final text = raw.trim().replaceAll(' ', '').replaceAll('%', '');
  if (text.isEmpty) return null;
  final sep = text.contains(',')
      ? text.lastIndexOf(',')
      : text.lastIndexOf('.');
  if (sep < 0) return 0;
  final frac = text.substring(sep + 1).replaceAll(RegExp(r'[^0-9]'), '');
  if (frac.isEmpty) return 0;
  return frac.length;
}

String formatPercent(double? value, {int digits = 3}) {
  if (value == null) return '—';
  return '${formatBrNumber(value, digits)} %';
}

double? parsePercentNumber(String raw) {
  return parseCalibNumber(raw.replaceAll('%', ''));
}

/// Excel TINV(p, df): inverso bilateral da t de Student.
double excelTInv(double p, double df) {
  if (!df.isFinite || df < 1) return 2;
  if (p <= 0) return double.infinity;
  if (p >= 1) return 0;
  final target = 1 - p / 2;
  var lo = 0.0;
  var hi = 4.0;
  while (_studentTCdf(hi, df) < target) {
    hi *= 2;
    if (hi > 1e6) return hi;
  }
  for (var i = 0; i < 70; i++) {
    final mid = (lo + hi) / 2;
    if (_studentTCdf(mid, df) < target) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return (lo + hi) / 2;
}

double _studentTCdf(double t, double df) {
  if (t < 0) return 1 - _studentTCdf(-t, df);
  if (t == 0) return 0.5;
  final x = df / (df + t * t);
  return 1 - 0.5 * _regularizedIncompleteBeta(df / 2, 0.5, x);
}

double _regularizedIncompleteBeta(double a, double b, double x) {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  final logBt = _logGamma(a + b) -
      _logGamma(a) -
      _logGamma(b) +
      a * math.log(x) +
      b * math.log(1 - x);
  final bt = math.exp(logBt);
  if (x < (a + 1) / (a + b + 2)) {
    return bt * _betaContinuedFraction(a, b, x) / a;
  }
  return 1 - bt * _betaContinuedFraction(b, a, 1 - x) / b;
}

double _betaContinuedFraction(double a, double b, double x) {
  const maxIt = 200;
  const eps = 3e-14;
  const fpMin = 1e-30;
  final qab = a + b;
  final qap = a + 1;
  final qam = a - 1;
  var c = 1.0;
  var d = 1.0 - qab * x / qap;
  if (d.abs() < fpMin) d = fpMin;
  d = 1 / d;
  var h = d;
  for (var m = 1; m <= maxIt; m++) {
    final m2 = 2 * m;
    var aa = m * (b - m) * x / ((qam + m2) * (a + m2));
    d = 1 + aa * d;
    if (d.abs() < fpMin) d = fpMin;
    c = 1 + aa / c;
    if (c.abs() < fpMin) c = fpMin;
    d = 1 / d;
    h *= d * c;
    aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
    d = 1 + aa * d;
    if (d.abs() < fpMin) d = fpMin;
    c = 1 + aa / c;
    if (c.abs() < fpMin) c = fpMin;
    d = 1 / d;
    final del = d * c;
    h *= del;
    if ((del - 1).abs() < eps) break;
  }
  return h;
}

double _logGamma(double z) {
  const coeffs = [
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224128,
    771.3234287779073,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.984369654078991e-6,
    1.5056327351493116e-7,
  ];
  if (z < 0.5) {
    return math.log(math.pi / math.sin(math.pi * z)) - _logGamma(1 - z);
  }
  final x0 = z - 1;
  var acc = coeffs[0];
  for (var i = 1; i < coeffs.length; i++) {
    acc += coeffs[i] / (x0 + i);
  }
  final t = x0 + 7.5;
  return 0.5 * math.log(2 * math.pi) + (x0 + 0.5) * math.log(t) - t + math.log(acc);
}

/// Graus efetivos do padrão na planilha GS (LOOKUP do k do certificado).
double veffFromStandardK(double k) {
  const table = <(double, double)>[
    (2.00, 10000),
    (2.02, 100),
    (2.03, 80),
    (2.04, 60),
    (2.05, 50),
    (2.06, 40),
    (2.07, 35),
    (2.13, 20),
    (2.28, 10),
    (2.37, 8),
    (2.43, 7),
    (2.52, 6),
    (2.65, 5),
    (2.87, 4),
    (3.31, 3),
    (4.53, 2),
    (13.97, 1),
  ];
  var result = table.first.$2;
  for (final pair in table) {
    if (k + 1e-9 >= pair.$1) result = pair.$2;
  }
  return result;
}

class UncertaintyBudget {
  const UncertaintyBudget({
    required this.expandedPercent,
    required this.coverageK,
    required this.effectiveDof,
  });

  final double expandedPercent;
  final double coverageK;
  final double effectiveDof;

  String get uLabel => '${formatBrNumber(expandedPercent, 2)}%';

  String get kLabel => formatBrNumber(coverageK, 2);

  String get veffLabel =>
      effectiveDof > 501 ? '∞' : formatCalibNumber(effectiveDof, digits: 1);
}

/// Orçamento EA-4/02 da planilha GS (aba Contribuições): litros → U% = U/M̄×100.
UncertaintyBudget? volumetricUncertainty({
  required List<double> relativeVolumeErrors,
  required List<double> objectVolumes,
  double? standardExpandedPercent,
  double standardK = 2,
  double? standardResolutionLiters,
  double? instrumentResolutionLiters,
  double? standardStabilityPercent,
}) {
  final meanObject = meanOrNull(objectVolumes);
  if (meanObject == null || meanObject <= 0) return null;

  final kStd = standardK <= 0 ? 2.0 : standardK;
  final terms = <({double uLiters, double nu})>[];
  double? uaLiters;
  double? uaNu;
  double? ubLiters;
  double? ubNu;

  if (relativeVolumeErrors.length >= 2) {
    final stdev = sampleStdev(relativeVolumeErrors);
    if (stdev != null) {
      uaLiters =
          stdev / math.sqrt(relativeVolumeErrors.length) * meanObject;
      uaNu = relativeVolumeErrors.length - 1.0;
      terms.add((uLiters: uaLiters!, nu: uaNu!));
    }
  }

  if (standardExpandedPercent != null && standardExpandedPercent > 0) {
    ubLiters = (standardExpandedPercent / 100 / kStd) * meanObject;
    ubNu = kStd == 2 ? 10000.0 : veffFromStandardK(kStd);
    terms.add((uLiters: ubLiters!, nu: ubNu!));
  }

  if (terms.isEmpty) return null;

  if (standardResolutionLiters != null && standardResolutionLiters > 0) {
    terms.add((
      uLiters: standardResolutionLiters / 2 / math.sqrt(3),
      nu: 10000,
    ));
  }

  if (instrumentResolutionLiters != null && instrumentResolutionLiters > 0) {
    terms.add((
      uLiters: instrumentResolutionLiters / 2 / 1.73,
      nu: 10000,
    ));
  }

  if (standardStabilityPercent != null && standardStabilityPercent > 0) {
    terms.add((
      uLiters:
          standardStabilityPercent * (meanObject / 100) / math.sqrt(3),
      nu: 10000,
    ));
  }

  var uc2 = 0.0;
  for (final term in terms) {
    uc2 += term.uLiters * term.uLiters;
  }
  if (uc2 <= 0) {
    return const UncertaintyBudget(
      expandedPercent: 0,
      coverageK: 2,
      effectiveDof: 10000,
    );
  }

  final ucLiters = math.sqrt(uc2);

  var veffDenom = 0.0;
  if (uaLiters != null && uaNu != null && uaNu > 0) {
    veffDenom += math.pow(uaLiters, 4) / uaNu;
  }
  if (ubLiters != null && ubNu != null && ubNu > 0) {
    veffDenom += math.pow(ubLiters, 4) / ubNu;
  }

  var veff = veffDenom <= 0
      ? 10000.0
      : _excelRoundUp(math.pow(ucLiters, 4) / veffDenom, 3);
  if (veff > 10000) veff = 10000;

  final k = veff > 100 ? 2.0 : excelTInv(0.0455, veff);
  final expandedLiters = _excelRoundUp(ucLiters * k, 3);
  final expandedPercent = expandedLiters / meanObject * 100;

  return UncertaintyBudget(
    expandedPercent: expandedPercent,
    coverageK: k,
    effectiveDof: veff,
  );
}

double _excelRoundUp(double value, int decimals) {
  final factor = math.pow(10, decimals).toDouble();
  return (value * factor).ceilToDouble() / factor;
}

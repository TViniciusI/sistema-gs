import 'package:gs_mobile/core/number_pt.dart';
import 'package:gs_mobile/data/derivados_tables.dart';

class DerivadosResult {
  const DerivadosResult({
    required this.density20,
    required this.ctl,
    required this.volume20,
    required this.weight,
    this.variance,
    this.variancePercent,
    this.inpm,
  });

  final double density20;
  final double ctl;
  final double volume20;
  final double weight;
  final double? variance;
  final double? variancePercent;
  /// Grau INPM (% massa) — preenchido apenas na correção de álcool (NBR 5992).
  final double? inpm;
}

class ValidacaoResult {
  const ValidacaoResult({
    required this.base,
    required this.systemVol20,
    required this.varianceLit,
    required this.variancePct,
  });

  final DerivadosResult base;
  final double systemVol20;
  final double varianceLit;
  final double variancePct;
}

/// Conversão ASTM / tabela GS (DNS_20 + FCV_20 da planilha REV.01).
DerivadosResult convertDerivados({
  required double densityAmbient,
  required double temperature,
  required double volumeAmbient,
  required double temperatureCt,
  double? volumeDanfe,
}) {
  final density20 = density20FromAmbient(
    densityAmbient: densityAmbient,
    temperature: temperature,
  );
  final ctl = _round4(
    ctlFromDensity20(
      density20: density20,
      temperatureCt: temperatureCt,
    ),
  );
  // Planilha GS aba 1952: Volume L20 = ROUND(V × CTL, 2)
  final volume20 = _roundDerivadosVolume(volumeAmbient * ctl);
  final weight = (volume20 * density20) / 1000;
  final variance = volumeDanfe == null ? null : volume20 - volumeDanfe;
  final reference = volumeDanfe;
  final variancePercent = variance == null || reference == null || reference == 0
      ? null
      : (variance / reference) * 100;
  return DerivadosResult(
    density20: density20,
    ctl: ctl,
    volume20: volume20,
    weight: weight,
    variance: variance,
    variancePercent: variancePercent,
  );
}

ValidacaoResult convertValidacao({
  required double volumeBaseAmbient,
  required double densityAmbient,
  required double temperature,
  required double volumeSistema,
}) {
  final base = convertDerivados(
    densityAmbient: densityAmbient,
    temperature: temperature,
    volumeAmbient: volumeBaseAmbient,
    temperatureCt: temperature,
  );
  final varianceLit = volumeSistema - base.volume20;
  final variancePct = base.volume20 == 0
      ? 0.0
      : (varianceLit / base.volume20) * 100.0;
  return ValidacaoResult(
    base: base,
    systemVol20: volumeSistema,
    varianceLit: varianceLit,
    variancePct: variancePct,
  );
}

String formatVarianceDisplay({
  required double variance,
  double? variancePercent,
  required bool showPercent,
  int litDigits = 3,
  int pctDigits = 3,
  String unit = 'L20',
}) {
  final lit = '${formatPt(variance, litDigits)} $unit';
  if (!showPercent || variancePercent == null) return lit;
  return '${formatPt(variancePercent, pctDigits)} % · $lit';
}

double _round4(double value) => (value * 10000).round() / 10000;

double _roundDerivadosVolume(double value) =>
    (value * 100).roundToDouble() / 100;

/// Alias histórico — use [parseBrNumber] em código novo.
double? parsePtNumber(String raw) => parseBrNumber(raw);

/// Alias histórico — use [formatBrNumber] em código novo.
String formatPt(double value, [int digits = 2]) => formatBrNumber(value, digits);

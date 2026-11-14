import 'package:gs_mobile/data/derivados_table_data.dart';

/// Coeficientes P1–P4 por faixa de densidade (VLOOKUP aproximado da planilha GS).
List<double> lookupDerivadosCoeffs(double key, List<DerivadosCoeffsRow> table) {
  if (table.isEmpty) {
    return [0, 0, 0, 0];
  }
  if (key < table.first.damb) {
    final row = table.first;
    return [row.p1, row.p2, row.p3, row.p4];
  }
  for (var i = table.length - 1; i >= 0; i--) {
    if (key >= table[i].damb) {
      final row = table[i];
      return [row.p1, row.p2, row.p3, row.p4];
    }
  }
  final row = table.first;
  return [row.p1, row.p2, row.p3, row.p4];
}

/// Densidade a 20 °C — fórmula da planilha GS (aba 1952 / DNS_20).
double density20FromAmbient({
  required double densityAmbient,
  required double temperature,
}) {
  final rhoG = densityAmbient / 1000;
  final dt = temperature - 20;
  final coeffs = lookupDerivadosCoeffs(densityAmbient, dns20Table);
  final p1 = coeffs[0];
  final p2 = coeffs[1];
  final p3 = coeffs[2];
  final p4 = coeffs[3];
  final numerator = rhoG - p1 * dt - p3 * dt * dt;
  final denominator = 1 + p2 * dt + p4 * dt * dt;
  final hyc = 1 - 0.000023 * dt - 0.00000002 * dt * dt;
  return (numerator / denominator) * hyc * 1000;
}

/// Fator CTL — fórmula da planilha GS (aba 1952 / FCV_20, chave = densidade a 20 °C).
double ctlFromDensity20({
  required double density20,
  required double temperatureCt,
}) {
  final dt = temperatureCt - 20;
  final coeffs = lookupDerivadosCoeffs(density20, fcv20Table);
  final p1 = coeffs[0];
  final p2 = coeffs[1];
  final p3 = coeffs[2];
  final p4 = coeffs[3];
  final rho20G = density20 / 1000;
  return 1 +
      p2 * dt +
      p4 * dt * dt +
      (p1 * dt + p3 * dt * dt) / rho20G;
}

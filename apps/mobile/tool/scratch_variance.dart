import 'package:gs_mobile/core/number_pt.dart';
import 'package:gs_mobile/data/inpm_table_data.dart';
import 'package:gs_mobile/data/tabelas_alcool.dart';

void main() {
  print('49,600 => ${parseBrNumber("49,600")}');
  final r = convertAlcool(
    densityAmbient: 809,
    temperature: 23.5,
    volumeAmbient: 50000,
    temperatureCt: 23.5,
    volumeDanfe: 49600,
  );
  print('809/23.5: inpm=${r.inpm} d20=${r.density20} ctl=${r.ctl} vol=${r.volume20} var=${r.variance}');

  // direct INPM row like Excel display
  final inpm = 93.53;
  final d20 = _densityAtDirect(inpm, 20);
  final ctl = _ctlDirect(inpm, 23.5);
  final vol = 50000 * ((ctl * 10000).round() / 10000);
  print('forced inpm 93.53: d20=$d20 ctl=$ctl vol=$vol var=${vol - 49600}');
}

double _densityAtDirect(double inpm, double temp) {
  final idx = ((inpm - inpmMin) / inpmStep).round().clamp(0, inpmCount - 1);
  final dens = List<double>.generate(
    tempCount,
    (col) => inpmDensities[idx * tempCount + col].toDouble(),
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

double _ctlDirect(double inpm, double tempCt) {
  final rho20 = _densityAtDirect(inpm, 20);
  final rhoCt = _densityAtDirect(inpm, tempCt);
  final hyC = 1 + 0.000036 * (tempCt - 20);
  return rhoCt / rho20 * hyC;
}

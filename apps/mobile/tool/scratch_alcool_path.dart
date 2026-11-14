import 'package:gs_mobile/data/derivados_tables.dart';
import 'package:gs_mobile/data/tabelas_alcool.dart';

void main() {
  final d20Deriv = density20FromAmbient(
    densityAmbient: 809,
    temperature: 23.5,
  );
  print('derivados d20 from 809@23.5: $d20Deriv');
  final r = convertAlcool(
    densityAmbient: 809,
    temperature: 23.5,
    volumeAmbient: 50000,
    temperatureCt: 23.5,
    volumeDanfe: 49600,
  );
  print('current alcool: inpm=${r.inpm} d20=${r.density20} ctl=${r.ctl} var=${r.variance}');
}

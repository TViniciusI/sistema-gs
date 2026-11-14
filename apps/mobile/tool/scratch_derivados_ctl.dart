import 'package:gs_mobile/data/derivados_tables.dart';

void main() {
  final d20 = 808.28;
  final ctl = ctlFromDensity20(density20: d20, temperatureCt: 23.5);
  final vol = 50000 * ctl;
  print('derivados ctl $ctl vol $vol var ${vol - 49600}');
}

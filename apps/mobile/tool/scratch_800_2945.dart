import 'package:gs_mobile/data/tabelas_alcool.dart';

void main() {
  final r = convertAlcool(
    densityAmbient: 800,
    temperature: 29.45,
    volumeAmbient: 50000,
    temperatureCt: 29.45,
    volumeDanfe: 49600,
  );
  print('inpm=${r.inpm} d20=${r.density20} ctl=${r.ctl} vol=${r.volume20} var=${r.variance}');
}

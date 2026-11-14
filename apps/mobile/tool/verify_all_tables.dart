import 'package:gs_mobile/data/tabelas20.dart';
import 'package:gs_mobile/data/tabelas_alcool.dart';

void main() {
  void deriv(String name, DerivadosResult r) {
    print('$name d20=${r.density20} ctl=${r.ctl} vol=${r.volume20} var=${r.variance} pct=${r.variancePercent}');
  }

  deriv(
    '723/25',
    convertDerivados(
      densityAmbient: 723,
      temperature: 25,
      volumeAmbient: 10000,
      temperatureCt: 25,
      volumeDanfe: 9940,
    ),
  );
  deriv(
    'S10',
    convertDerivados(
      densityAmbient: 824.20,
      temperature: 32.18,
      volumeAmbient: 55548,
      temperatureCt: 36.12,
      volumeDanfe: 54803.66,
    ),
  );
  final v = convertValidacao(
    volumeBaseAmbient: 55548,
    densityAmbient: 872.84,
    temperature: 36.12,
    volumeSistema: 49880,
  );
  print('validacao d20=${v.base.density20} ctl=${v.base.ctl} vol=${v.base.volume20} varLit=${v.varianceLit} pct=${v.variancePct}');

  final a = convertAlcool(
    densityAmbient: 800,
    temperature: 29.45,
    volumeAmbient: 50000,
    temperatureCt: 29.45,
    volumeDanfe: 49600,
  );
  print('alcool 800/29.45 var=${a.variance}');
}

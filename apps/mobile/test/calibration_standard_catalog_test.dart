import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/data/calibration_models.dart';

void main() {
  test('padrão guarda categoria, dono e locais', () {
    const item = CatalogStandard(
      id: 'p1',
      name: 'GS 001 - D',
      categories: [StandardCategory.density],
      owner: standardOwnerClient,
      ownerClientId: 'c1',
      ownerClientName: 'VIBRA ENERGIA S.A.',
      locations: ['DTC Goiânia/GO', 'Base Senador Canedo'],
    );
    final back = CatalogStandard.fromJson(item.toJson());
    expect(back.categories, [StandardCategory.density]);
    expect(back.isClientOwned, isTrue);
    expect(back.ownerLabel, 'Cliente: VIBRA ENERGIA S.A.');
    expect(back.locations, ['DTC Goiânia/GO', 'Base Senador Canedo']);
    expect(
      back.belongsToClient(clientId: '', clientName: 'Vibra Energia S.A.'),
      isTrue,
    );
    expect(back.locationMatching('DTC GOIANIA'), 'DTC Goiânia/GO');
    expect(back.locationMatching('DTC Rio Verde'), isEmpty);
  });

  test('padrão antigo abre como da GS, sem categoria', () {
    final old = CatalogStandard.fromJson({
      'id': 'x',
      'name': 'GS 001',
      'type': 'MEDIDOR CORIOLIS',
      'uncertainty': '0,08%',
    });
    expect(old.categories, isEmpty);
    expect(old.owner, standardOwnerGs);
    expect(old.ownerLabel, 'GS Soluções');
  });

  test('sugere a categoria pelo nome e pela unidade', () {
    StandardCategory? guess(String name, String type, String u) =>
        guessStandardCategory(name: name, type: type, uncertainty: u);
    expect(guess('GS 001', 'MEDIDOR CORIOLIS', '0,08%'),
        StandardCategory.volumetric);
    expect(guess('GS 001 - T', 'MEDIDOR CORIOLIS', '0,5%'),
        StandardCategory.temperature);
    expect(guess('GS 001 - D', 'Medidor Coriolis', '0,3 kg/m³'),
        StandardCategory.density);
    expect(guess('FLB-40.121/2025', 'TERMÔMETRO DIGITAL', '0,2°C'),
        StandardCategory.temperature);
    expect(standardCategoryForKind(CalibrationKind.temperatureMesh),
        StandardCategory.temperature);
  });
}

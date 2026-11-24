import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/data/calibration_models.dart';

void main() {
  test('prioriza técnico da OS e ignora conta de desenvolvedor', () {
    expect(
      preferredCalibrationTechnician(
        osTechnicianName: 'Eduardo Wallenberg Pereira Ribeiro',
        userName: 'Vinicius Magalhães',
        userIsDeveloper: true,
      ),
      'Eduardo Wallenberg Pereira Ribeiro',
    );

    expect(
      preferredCalibrationTechnician(
        osTechnicianName: '',
        userName: 'Vinicius Magalhães',
        userIsDeveloper: true,
      ),
      '',
    );

    expect(
      preferredCalibrationTechnician(
        osTechnicianName: '',
        userName: 'Felipe Souza',
        userIsDeveloper: false,
      ),
      'Felipe Souza',
    );
  });
}

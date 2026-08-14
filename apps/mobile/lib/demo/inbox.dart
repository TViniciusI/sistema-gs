import 'package:flutter/foundation.dart';
import 'package:gs_mobile/demo/catalog.dart';

class OfficeInbox extends ChangeNotifier {
  OfficeInbox._();
  static final instance = OfficeInbox._();

  final List<FieldCertificate> certificates = [
    const FieldCertificate(
      number: '2303126',
      workOrderId: 'os-034',
      workOrderNumber: 'GS 034/26',
      client: 'ALESAT Combustíveis S.A.',
      instrument: 'Medidor Coriolis Yokogawa · FT-01',
      issuedAt: '18/07/2026',
      sentToOffice: true,
      fileName: 'CERTIFICADO 2303126.xlsx',
    ),
  ];

  int _seq = 2303127;

  String peekNumber() => '$_seq';

  String nextNumber() => '${_seq++}';

  void addFromField(FieldCertificate certificate) {
    certificates.removeWhere((item) => item.number == certificate.number);
    certificates.insert(0, certificate);
    if (certificate.number == '$_seq') _seq++;
    notifyListeners();
  }

  void markSent(String number) {
    final index = certificates.indexWhere((item) => item.number == number);
    if (index < 0) return;
    final current = certificates[index];
    certificates[index] = FieldCertificate(
      number: current.number,
      workOrderId: current.workOrderId,
      workOrderNumber: current.workOrderNumber,
      client: current.client,
      instrument: current.instrument,
      issuedAt: current.issuedAt,
      sentToOffice: true,
      fileName: current.fileName,
      fileBytes: current.fileBytes,
      contentType: current.contentType,
    );
    notifyListeners();
  }
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gs_mobile/core/app_version.dart';

void main() {
  test('appBuild e appVersion batem com o pubspec (+N)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec precisa de version: x.y.z+N');
    final version = match!.group(1)!;
    final build = int.parse(match.group(2)!);
    expect(
      appVersion,
      version,
      reason:
          'app_version.dart ($appVersion) desalinhado do pubspec ($version). '
          'Isso deixa a faixa "Nova versão disponível" presa no celular.',
    );
    expect(
      appBuild,
      build,
      reason:
          'appBuild ($appBuild) desalinhado do +N do pubspec ($build). '
          'version.json usa o +N; se appBuild for menor, a faixa nunca some.',
    );
  });
}

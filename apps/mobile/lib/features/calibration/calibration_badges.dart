import 'package:flutter/material.dart';
import 'package:gs_mobile/core/theme.dart';
import 'package:gs_mobile/data/calibration_catalog.dart';
import 'package:gs_mobile/data/calibration_models.dart';

class GsPill extends StatelessWidget {
  const GsPill({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

GsPill kindPill(CalibrationKind kind) {
  switch (kind) {
    case CalibrationKind.volumetric:
      return const GsPill(
        label: 'Vazão',
        foreground: Color(0xFF0B4F8A),
        background: Color(0xFFD6E8F8),
      );
    case CalibrationKind.volumetricInverted:
      return const GsPill(
        label: 'Vazão invertida',
        foreground: Color(0xFF0B4F8A),
        background: Color(0xFFC9E4F2),
      );
    case CalibrationKind.density:
      return const GsPill(
        label: 'Densidade',
        foreground: Color(0xFF5B2C91),
        background: Color(0xFFE8D9F6),
      );
    case CalibrationKind.temperatureMesh:
      return const GsPill(
        label: 'Malha de temperatura',
        foreground: Color(0xFF8A4B00),
        background: Color(0xFFF8E2C4),
      );
    case CalibrationKind.temperature:
      return const GsPill(
        label: 'Temperatura',
        foreground: Color(0xFF8A6A00),
        background: Color(0xFFF7EDC2),
      );
    case CalibrationKind.pressure:
      return const GsPill(
        label: 'Pressão',
        foreground: Color(0xFF0F5B52),
        background: Color(0xFFD4F0EC),
      );
    case CalibrationKind.conductivity:
      return const GsPill(
        label: 'Condutividade',
        foreground: Color(0xFF1A4D7C),
        background: Color(0xFFD4E8F7),
      );
    case CalibrationKind.telemetry:
      return const GsPill(
        label: 'Telemetria',
        foreground: GsTheme.navy,
        background: Color(0xFFE4E7EA),
      );
  }
}

GsPill statusPill(CalibrationJobStatus status) {
  switch (status) {
    case CalibrationJobStatus.done:
      return const GsPill(
        label: 'Concluída',
        foreground: Color(0xFF1B6B3A),
        background: Color(0xFFD8F3E2),
      );
    case CalibrationJobStatus.pendingReview:
      return const GsPill(
        label: 'Em análise',
        foreground: Color(0xFF8A5A00),
        background: Color(0xFFFFE8C2),
      );
    case CalibrationJobStatus.inProgress:
      return const GsPill(
        label: 'Em andamento',
        foreground: Color(0xFF0B4F8A),
        background: Color(0xFFD6E8F8),
      );
    case CalibrationJobStatus.draft:
      return const GsPill(
        label: 'Rascunho',
        foreground: Color(0xFF5C6570),
        background: Color(0xFFE8EAED),
      );
  }
}

GsPill resultPill(bool? passed) {
  if (passed == null) {
    return const GsPill(
      label: 'Sem resultado',
      foreground: Color(0xFF5C6570),
      background: Color(0xFFE8EAED),
    );
  }
  return passed
      ? const GsPill(
          label: 'Aprovado',
          foreground: Color(0xFF1B6B3A),
          background: Color(0xFFD8F3E2),
        )
      : const GsPill(
          label: 'Reprovado',
          foreground: Color(0xFF8A1F1F),
          background: Color(0xFFF8D6D6),
        );
}

GsPill validityPill(StandardValidity status) {
  switch (status) {
    case StandardValidity.valid:
      return const GsPill(
        label: 'Válido',
        foreground: Color(0xFF1B6B3A),
        background: Color(0xFFD8F3E2),
      );
    case StandardValidity.expiring:
      return const GsPill(
        label: 'A vencer',
        foreground: Color(0xFF8A4B00),
        background: Color(0xFFF8E2C4),
      );
    case StandardValidity.expired:
      return const GsPill(
        label: 'Vencido',
        foreground: Color(0xFF8A1F1F),
        background: Color(0xFFF8D6D6),
      );
    case StandardValidity.unknown:
      return const GsPill(
        label: 'Sem data',
        foreground: Color(0xFF5C6570),
        background: Color(0xFFE8EAED),
      );
  }
}

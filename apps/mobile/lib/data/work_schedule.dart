import 'dart:convert';

import 'package:gs_mobile/data/week_agenda.dart';

/// Período de carga horária de um técnico (ex.: 6x1 8h/dia a partir de 01/12).
class WorkSchedulePeriod {
  const WorkSchedulePeriod({
    required this.id,
    required this.start,
    this.end,
    this.hoursPerDay = 8,
    this.overtimePercent = 50,
    this.label = '',
  });

  final String id;
  final DateTime start;
  final DateTime? end;
  final double hoursPerDay;
  final double overtimePercent;
  final String label;

  int get dailyLimitMinutes {
    final minutes = (hoursPerDay * 60).round();
    return minutes < 0 ? 0 : minutes;
  }

  bool covers(DateTime day) {
    final d = dateOnly(day);
    if (d.isBefore(dateOnly(start))) return false;
    final until = end;
    if (until == null) return true;
    return !d.isAfter(dateOnly(until));
  }

  WorkSchedulePeriod copyWith({
    String? id,
    DateTime? start,
    DateTime? end,
    bool clearEnd = false,
    double? hoursPerDay,
    double? overtimePercent,
    String? label,
  }) {
    return WorkSchedulePeriod(
      id: id ?? this.id,
      start: start ?? this.start,
      end: clearEnd ? null : (end ?? this.end),
      hoursPerDay: hoursPerDay ?? this.hoursPerDay,
      overtimePercent: overtimePercent ?? this.overtimePercent,
      label: label ?? this.label,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': dateOnly(start).toIso8601String(),
    if (end != null) 'end': dateOnly(end!).toIso8601String(),
    'hoursPerDay': hoursPerDay,
    'overtimePercent': overtimePercent,
    if (label.trim().isNotEmpty) 'label': label.trim(),
  };

  factory WorkSchedulePeriod.fromJson(Map<String, dynamic> json) {
    DateTime? parseDay(dynamic raw) {
      final text = '$raw'.trim();
      if (text.isEmpty) return null;
      final parsed = DateTime.tryParse(text);
      return parsed == null ? null : dateOnly(parsed);
    }

    double numOf(dynamic raw, double fallback) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('$raw'.replaceAll(',', '.')) ?? fallback;
    }

    return WorkSchedulePeriod(
      id: (json['id']?.toString() ?? '').trim().isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : json['id'].toString().trim(),
      start: parseDay(json['start'] ?? json['from']) ??
          dateOnly(DateTime.now()),
      end: parseDay(json['end'] ?? json['to']),
      hoursPerDay: numOf(json['hoursPerDay'] ?? json['horasDia'], 8),
      overtimePercent: numOf(
        json['overtimePercent'] ?? json['extraPercent'] ?? json['percentExtra'],
        50,
      ),
      label: (json['label'] ?? json['escala'] ?? '').toString().trim(),
    );
  }
}

WorkSchedulePeriod? scheduleForDay(
  Iterable<WorkSchedulePeriod> periods,
  DateTime day,
) {
  WorkSchedulePeriod? best;
  for (final period in periods) {
    if (!period.covers(day)) continue;
    if (best == null || dateOnly(period.start).isAfter(dateOnly(best.start))) {
      best = period;
    }
  }
  return best;
}

List<WorkSchedulePeriod> decodeWorkSchedules(dynamic raw) {
  if (raw == null) return const [];
  if (raw is String) {
    final text = raw.trim();
    if (text.isEmpty) return const [];
    try {
      return decodeWorkSchedules(jsonDecode(text));
    } catch (_) {
      return const [];
    }
  }
  if (raw is! List) return const [];
  final out = <WorkSchedulePeriod>[];
  for (final item in raw) {
    if (item is Map) {
      out.add(WorkSchedulePeriod.fromJson(Map<String, dynamic>.from(item)));
    } else if (item is String && item.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(item.trim());
        if (decoded is Map) {
          out.add(
            WorkSchedulePeriod.fromJson(Map<String, dynamic>.from(decoded)),
          );
        }
      } catch (_) {}
    }
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

String encodeWorkSchedules(Iterable<WorkSchedulePeriod> periods) {
  return jsonEncode([for (final p in periods) p.toJson()]);
}

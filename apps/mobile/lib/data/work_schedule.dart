import 'dart:convert';

import 'package:gs_mobile/data/week_agenda.dart';

const scheduleWeekdayLabels = [
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado',
  'Domingo',
];

/// Regra de um dia da semana dentro da escala (horas normais + % extra).
class WorkDayRule {
  const WorkDayRule({this.hours = 8, this.overtimePercent = 50});

  /// Horas normais do dia. 0 = folga: tudo trabalhado conta como extra.
  final double hours;
  final double overtimePercent;

  int get limitMinutes {
    final minutes = (hours * 60).round();
    return minutes < 0 ? 0 : minutes;
  }

  WorkDayRule copyWith({double? hours, double? overtimePercent}) {
    return WorkDayRule(
      hours: hours ?? this.hours,
      overtimePercent: overtimePercent ?? this.overtimePercent,
    );
  }

  Map<String, dynamic> toJson() => {
    'hours': hours,
    'overtimePercent': overtimePercent,
  };

  factory WorkDayRule.fromJson(Map<String, dynamic> json, {double? fallbackHours, double? fallbackPercent}) {
    double numOf(dynamic raw, double fallback) {
      if (raw is num) return raw.toDouble();
      return double.tryParse('$raw'.replaceAll(',', '.')) ?? fallback;
    }

    return WorkDayRule(
      hours: numOf(json['hours'] ?? json['horas'], fallbackHours ?? 8),
      overtimePercent: numOf(
        json['overtimePercent'] ?? json['extraPercent'] ?? json['percent'],
        fallbackPercent ?? 50,
      ),
    );
  }
}

List<WorkDayRule> defaultWeekdayRules({
  double hours = 8,
  double overtimePercent = 50,
}) =>
    List<WorkDayRule>.generate(
      7,
      (_) => WorkDayRule(hours: hours, overtimePercent: overtimePercent),
    );

/// Período de carga horária com regra por dia da semana (seg–dom).
class WorkSchedulePeriod {
  WorkSchedulePeriod({
    required this.id,
    required this.start,
    this.end,
    List<WorkDayRule>? weekdays,
    this.hoursPerDay = 8,
    this.overtimePercent = 50,
    this.label = '',
  }) : weekdays = _normalizeWeekdays(
         weekdays,
         hours: hoursPerDay,
         overtimePercent: overtimePercent,
       );

  final String id;
  final DateTime start;
  final DateTime? end;

  /// Índice 0 = segunda … 6 = domingo (`DateTime.weekday - 1`).
  final List<WorkDayRule> weekdays;

  /// Compatível com escalas antigas (valor “base” / resumo).
  final double hoursPerDay;
  final double overtimePercent;
  final String label;

  static List<WorkDayRule> _normalizeWeekdays(
    List<WorkDayRule>? raw, {
    required double hours,
    required double overtimePercent,
  }) {
    if (raw == null || raw.isEmpty) {
      return defaultWeekdayRules(hours: hours, overtimePercent: overtimePercent);
    }
    final out = [...raw];
    while (out.length < 7) {
      out.add(WorkDayRule(hours: hours, overtimePercent: overtimePercent));
    }
    return out.take(7).toList(growable: false);
  }

  WorkDayRule ruleForDate(DateTime day) => weekdays[day.weekday - 1];

  int limitMinutesFor(DateTime day) => ruleForDate(day).limitMinutes;

  double overtimePercentFor(DateTime day) => ruleForDate(day).overtimePercent;

  bool covers(DateTime day) {
    final d = dateOnly(day);
    if (d.isBefore(dateOnly(start))) return false;
    final until = end;
    if (until == null) return true;
    return !d.isAfter(dateOnly(until));
  }

  String get weekdaysSummary {
    final parts = <String>[];
    for (var i = 0; i < 7; i++) {
      final rule = weekdays[i];
      final short = scheduleWeekdayLabels[i].substring(0, 3);
      final h = rule.hours % 1 == 0
          ? rule.hours.toStringAsFixed(0)
          : rule.hours.toString();
      final p = rule.overtimePercent % 1 == 0
          ? rule.overtimePercent.toStringAsFixed(0)
          : '${rule.overtimePercent}';
      parts.add('$short ${h}h/${p}%');
    }
    return parts.join(' · ');
  }

  WorkSchedulePeriod copyWith({
    String? id,
    DateTime? start,
    DateTime? end,
    bool clearEnd = false,
    List<WorkDayRule>? weekdays,
    double? hoursPerDay,
    double? overtimePercent,
    String? label,
  }) {
    return WorkSchedulePeriod(
      id: id ?? this.id,
      start: start ?? this.start,
      end: clearEnd ? null : (end ?? this.end),
      weekdays: weekdays ?? this.weekdays,
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
    'weekdays': [for (final day in weekdays) day.toJson()],
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

    final baseHours = numOf(json['hoursPerDay'] ?? json['horasDia'], 8);
    final basePercent = numOf(
      json['overtimePercent'] ?? json['extraPercent'] ?? json['percentExtra'],
      50,
    );

    List<WorkDayRule>? days;
    final rawDays = json['weekdays'] ?? json['dias'] ?? json['days'];
    if (rawDays is List && rawDays.isNotEmpty) {
      days = [
        for (final item in rawDays)
          if (item is Map)
            WorkDayRule.fromJson(
              Map<String, dynamic>.from(item),
              fallbackHours: baseHours,
              fallbackPercent: basePercent,
            )
          else if (item is num)
            WorkDayRule(hours: item.toDouble(), overtimePercent: basePercent)
          else
            WorkDayRule(hours: baseHours, overtimePercent: basePercent),
      ];
    }

    return WorkSchedulePeriod(
      id: (json['id']?.toString() ?? '').trim().isEmpty
          ? DateTime.now().microsecondsSinceEpoch.toString()
          : json['id'].toString().trim(),
      start: parseDay(json['start'] ?? json['from']) ??
          dateOnly(DateTime.now()),
      end: parseDay(json['end'] ?? json['to']),
      weekdays: days,
      hoursPerDay: baseHours,
      overtimePercent: basePercent,
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

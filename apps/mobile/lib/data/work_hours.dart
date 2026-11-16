import 'package:gs_mobile/data/models.dart';

const dailyLimitMinutes = 8 * 60;
const saturdayLimitMinutes = 4 * 60;
const defaultLunchMinutes = 60;
const lunchRequiredAfterMinutes = 6 * 60;
const nightStartMinutes = 22 * 60;
const nightEndMinutes = 5 * 60;
const minutesPerDay = 24 * 60;

int? parseClockMinutes(String raw) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw.trim());
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.parse(match[2]!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

int clockOutOnTimeline(int clockIn, int clockOut) {
  return clockOut <= clockIn ? clockOut + minutesPerDay : clockOut;
}

int overlapMinutes(int start, int end, int windowStart, int windowEnd) {
  final from = start > windowStart ? start : windowStart;
  final to = end < windowEnd ? end : windowEnd;
  return to > from ? to - from : 0;
}

int minutesInNightWindow(int start, int end) {
  var total = 0;
  for (var day = 0; day <= 2; day++) {
    final base = day * minutesPerDay;
    total += overlapMinutes(
      start,
      end,
      base + nightStartMinutes,
      base + minutesPerDay,
    );
    total += overlapMinutes(start, end, base, base + nightEndMinutes);
  }
  return total;
}

int rdoPresenceMinutes(SavedRdo rdo) {
  final clockIn = parseClockMinutes(rdo.clockIn);
  final clockOut = parseClockMinutes(rdo.clockOut);
  if (clockIn == null || clockOut == null) return 0;
  return clockOutOnTimeline(clockIn, clockOut) - clockIn;
}

int rdoRecordedLunchMinutes(SavedRdo rdo) {
  final lunchStart = parseClockMinutes(rdo.lunchStart);
  final lunchEnd = parseClockMinutes(rdo.lunchEnd);
  if (lunchStart == null || lunchEnd == null || lunchEnd == lunchStart) {
    return 0;
  }
  return clockOutOnTimeline(lunchStart, lunchEnd) - lunchStart;
}

int rdoLunchMinutes(SavedRdo rdo) {
  final presence = rdoPresenceMinutes(rdo);
  if (presence <= 0) return 0;
  final recorded = rdoRecordedLunchMinutes(rdo);
  if (recorded > 0) return recorded > presence ? presence : recorded;
  if (presence > lunchRequiredAfterMinutes) {
    return defaultLunchMinutes > presence ? presence : defaultLunchMinutes;
  }
  return 0;
}

int rdoWorkedMinutes(SavedRdo rdo) => dayHoursFromRdos([rdo]).workedMinutes;

int rdoNightMinutes(SavedRdo rdo) => dayHoursFromRdos([rdo]).nightMinutes;

class DayWorkHours {
  const DayWorkHours({this.workedMinutes = 0, this.nightMinutes = 0});

  final int workedMinutes;
  final int nightMinutes;
}

class _Span {
  const _Span(this.start, this.end);

  final int start;
  final int end;

  int get minutes => end > start ? end - start : 0;
}

_Span? _presenceSpan(SavedRdo rdo) {
  final clockIn = parseClockMinutes(rdo.clockIn);
  final clockOut = parseClockMinutes(rdo.clockOut);
  if (clockIn == null || clockOut == null) return null;
  return _Span(clockIn, clockOutOnTimeline(clockIn, clockOut));
}

_Span? _recordedLunchSpan(SavedRdo rdo, _Span presence) {
  final lunchStart = parseClockMinutes(rdo.lunchStart);
  final lunchEnd = parseClockMinutes(rdo.lunchEnd);
  if (lunchStart == null || lunchEnd == null || lunchEnd == lunchStart) {
    return null;
  }
  var start = lunchStart;
  var end = clockOutOnTimeline(lunchStart, lunchEnd);
  if (end <= presence.start) {
    start += minutesPerDay;
    end += minutesPerDay;
  }
  return _Span(start, end);
}

List<_Span> _mergeSpans(Iterable<_Span> input) {
  final spans = [for (final span in input) if (span.minutes > 0) span]
    ..sort((a, b) => a.start.compareTo(b.start));
  if (spans.isEmpty) return const [];
  final merged = <_Span>[];
  var current = spans.first;
  for (var i = 1; i < spans.length; i++) {
    final next = spans[i];
    if (next.start <= current.end) {
      current = _Span(
        current.start,
        next.end > current.end ? next.end : current.end,
      );
    } else {
      merged.add(current);
      current = next;
    }
  }
  merged.add(current);
  return merged;
}

int _spansMinutes(List<_Span> spans) =>
    spans.fold(0, (sum, span) => sum + span.minutes);

List<_Span> _subtractSpans(List<_Span> base, List<_Span> cut) {
  final cuts = _mergeSpans(cut);
  final result = <_Span>[];
  for (final span in _mergeSpans(base)) {
    var start = span.start;
    final end = span.end;
    for (final piece in cuts) {
      if (piece.end <= start || piece.start >= end) continue;
      if (piece.start > start) {
        result.add(_Span(start, piece.start < end ? piece.start : end));
      }
      if (piece.end > start) start = piece.end;
      if (start >= end) break;
    }
    if (start < end) result.add(_Span(start, end));
  }
  return result;
}

int _nightInSpans(List<_Span> spans) {
  var total = 0;
  for (final span in spans) {
    total += minutesInNightWindow(span.start, span.end);
  }
  return total;
}

int _defaultLunchMinutes(List<_Span> presence, List<_Span> recordedLunch) {
  var extra = 0;
  for (final block in presence) {
    final hasLunch = recordedLunch.any(
      (lunch) => lunch.start < block.end && lunch.end > block.start,
    );
    if (hasLunch) continue;
    if (block.minutes > lunchRequiredAfterMinutes) {
      extra += defaultLunchMinutes > block.minutes
          ? block.minutes
          : defaultLunchMinutes;
    }
  }
  return extra;
}

/// Junta os RDOs do mesmo dia: horário sobreposto de duas OS conta uma vez.
DayWorkHours dayHoursFromRdos(Iterable<SavedRdo> rdos) {
  final presence = <_Span>[];
  final lunches = <_Span>[];
  for (final rdo in rdos) {
    final span = _presenceSpan(rdo);
    if (span == null) continue;
    presence.add(span);
    final lunch = _recordedLunchSpan(rdo, span);
    if (lunch != null) lunches.add(lunch);
  }
  final mergedPresence = _mergeSpans(presence);
  if (mergedPresence.isEmpty) return const DayWorkHours();
  final recordedLunch = _mergeSpans(lunches);
  final afterLunch = _subtractSpans(mergedPresence, recordedLunch);
  final defaultLunch = _defaultLunchMinutes(mergedPresence, recordedLunch);
  final worked = _spansMinutes(afterLunch) - defaultLunch;
  var night = _nightInSpans(afterLunch);
  if (night < 0) night = 0;
  final safeWorked = worked < 0 ? 0 : worked;
  return DayWorkHours(
    workedMinutes: safeWorked,
    nightMinutes: night > safeWorked ? safeWorked : night,
  );
}

int dailyOvertimeMinutes(int workedMinutes) {
  final extra = workedMinutes - dailyLimitMinutes;
  return extra < 0 ? 0 : extra;
}

int extraMinutesForWeekIndex(
  int mondayBasedIndex,
  int workedMinutes, {
  int? dailyLimitOverride,
}) {
  if (workedMinutes <= 0) return 0;
  if (mondayBasedIndex >= 6) return workedMinutes;
  if (dailyLimitOverride != null) {
    final extra = workedMinutes - dailyLimitOverride;
    return extra < 0 ? 0 : extra;
  }
  if (mondayBasedIndex == 5) {
    final extra = workedMinutes - saturdayLimitMinutes;
    return extra < 0 ? 0 : extra;
  }
  return dailyOvertimeMinutes(workedMinutes);
}

int extraMinutesForDay({
  required int workedMinutes,
  required DateTime day,
  required bool holiday,
  int? dailyLimitOverride,
}) {
  if (workedMinutes <= 0) return 0;
  if (holiday || day.weekday == DateTime.sunday) return workedMinutes;
  if (dailyLimitOverride != null) {
    final extra = workedMinutes - dailyLimitOverride;
    return extra < 0 ? 0 : extra;
  }
  if (day.weekday == DateTime.saturday) {
    final extra = workedMinutes - saturdayLimitMinutes;
    return extra < 0 ? 0 : extra;
  }
  return dailyOvertimeMinutes(workedMinutes);
}

String formatWorkedHours(int minutes) {
  if (minutes <= 0) return '0h';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '${hours}h';
  return '${hours}h ${rest.toString().padLeft(2, '0')}min';
}

String rdoClockRange(String clockIn, String clockOut) {
  final inn = clockIn.trim();
  final out = clockOut.trim();
  if (inn.isEmpty && out.isEmpty) return 'Sem horário';
  if (inn.isEmpty) return 'até $out';
  if (out.isEmpty) return 'desde $inn';
  return '$inn às $out';
}

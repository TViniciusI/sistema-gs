import 'package:flutter/material.dart';

Future<DateTime?> pickAppDate(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  var first = DateTime(firstDate.year, firstDate.month, firstDate.day);
  var last = DateTime(lastDate.year, lastDate.month, lastDate.day);
  var initial = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
  );
  if (last.isBefore(first)) last = first;
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    locale: const Locale('pt', 'BR'),
    builder: (context, child) {
      if (child == null) return const SizedBox.shrink();
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: child,
        ),
      );
    },
  );
}

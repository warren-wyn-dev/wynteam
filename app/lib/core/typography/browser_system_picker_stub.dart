import 'package:flutter/material.dart';

Future<DateTime?> pickBrowserSystemDate({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  DateTime? lastDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate ?? DateTime(2100),
  );
}

Future<TimeOfDay?> pickBrowserSystemTime({
  required BuildContext context,
  required TimeOfDay initialTime,
}) {
  return showTimePicker(context: context, initialTime: initialTime);
}

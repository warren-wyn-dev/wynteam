import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Future<DateTime?> pickBrowserSystemDate(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  DateTime? lastDate,
}) async {
  final value = await _pickWithNativeInput(
    type: 'date',
    value: _formatDate(initialDate),
    min: _formatDate(firstDate),
    max: lastDate == null ? null : _formatDate(lastDate),
  );
  if (value == null || value.isEmpty) return null;
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

Future<TimeOfDay?> pickBrowserSystemTime(
  BuildContext context, {
  required TimeOfDay initialTime,
}) async {
  final value = await _pickWithNativeInput(
    type: 'time',
    value:
        '${initialTime.hour.toString().padLeft(2, '0')}:${initialTime.minute.toString().padLeft(2, '0')}',
  );
  if (value == null || value.isEmpty) return null;
  final parts = value.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

Future<String?> _pickWithNativeInput({
  required String type,
  required String value,
  String? min,
  String? max,
}) {
  final completer = Completer<String?>();
  final input = web.document.createElement('input') as web.HTMLInputElement;
  input
    ..type = type
    ..value = value;
  if (min != null) input.setAttribute('min', min);
  if (max != null) input.setAttribute('max', max);
  input.style
    ..position = 'fixed'
    ..left = '-10000px'
    ..top = '0'
    ..width = '1px'
    ..height = '1px'
    ..opacity = '0';

  void finish(String? result) {
    if (completer.isCompleted) return;
    final parent = input.parentNode;
    if (parent != null) parent.removeChild(input);
    completer.complete(result);
  }

  input.addEventListener(
    'change',
    ((web.Event event) => finish(input.value)).toJS,
  );
  input.addEventListener('cancel', ((web.Event event) => finish(null)).toJS);
  input.addEventListener(
    'blur',
    ((web.Event event) {
      Future<void>.delayed(const Duration(milliseconds: 50), () {
        if (!completer.isCompleted) finish(null);
      });
    }).toJS,
  );

  web.document.body?.appendChild(input);
  input.focus();
  input.click();
  return completer.future;
}

String _formatDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

import 'package:flutter/material.dart';

/// Shared by every composer screen that lets a user leave with unpublished
/// content (caption/media) still in memory -- mirrors confirmDeletePost's
/// AlertDialog shape exactly, but for "leaving loses this" rather than
/// "deleting loses this". See
/// .wyn/docs/design/wyn-025-drop-composer-polish.md, R2.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('ทิ้งการเปลี่ยนแปลง?'),
      content: const Text('สิ่งที่พิมพ์หรือเลือกไว้จะหายไปถ้าออกตอนนี้'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('ทิ้ง'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

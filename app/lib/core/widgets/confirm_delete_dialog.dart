import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

/// Shared by every screen that lets a user delete their own content
/// (Drop/Pop/comments) so the confirmation copy can't drift between them.
/// [itemLabel] names what's being deleted -- default matches the
/// original WYN-004 copy ("ลบโพสต์นี้?").
Future<bool> confirmDeletePost(
  BuildContext context, {
  String itemLabel = 'โพสต์',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: BrowserSystemText('ลบ$itemLabelนี้?'),
      content: const BrowserSystemText('ลบแล้วไม่สามารถกู้คืนได้'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const BrowserSystemText('ยกเลิก'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const BrowserSystemText('ลบ'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

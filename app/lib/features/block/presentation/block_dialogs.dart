import 'package:flutter/material.dart';

/// Confirmation dialogs for WYN-027 (Block) -- same plain `AlertDialog`
/// shape as `confirmDeletePost`/`ClubPage._confirmLeave` (no red/error
/// styling on the confirm action, matching how this app has never used
/// destructive-red for a confirm button anywhere else). See
/// .wyn/docs/design/wyn-027-block-system.md, Screen 2 and Screen 5.
Future<bool> confirmBlock(BuildContext context, {required String username}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('บล็อก @$username?'),
      content: const Text(
        'คุณจะไม่เห็นเนื้อหาของกันและกันอีกต่อไป การติดตามระหว่างกัน (ถ้ามี) '
        'จะถูกยกเลิกทันที ยกเลิกการบล็อกได้ภายหลังที่ตั้งค่า',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('บล็อก'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

Future<bool> confirmUnblock(BuildContext context, {required String username}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('เลิกบล็อก @$username?'),
      content: const Text(
        'คุณจะเห็นเนื้อหาของกันและกันได้อีกครั้ง — การติดตามเดิม (ถ้ามี) '
        'จะไม่กลับมาอัตโนมัติ',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('เลิกบล็อก'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

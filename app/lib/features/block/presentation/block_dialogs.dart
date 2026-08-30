import 'package:flutter/material.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';

/// Confirmation dialogs for WYN-027 (Block) -- same plain `AlertDialog`
/// shape as `confirmDeletePost`/`ClubPage._confirmLeave` (no red/error
/// styling on the confirm action, matching how this app has never used
/// destructive-red for a confirm button anywhere else). 21-report-block.tsx
/// restyles [confirmBlock]'s title with the same sapphire warning icon +
/// Fraunces treatment the reference's own `BlockConfirmSheet` uses -- kept
/// as a title/content/actions `AlertDialog` (not converted to a bottom
/// sheet, and the actions stay plain `TextButton`s) since that widget
/// shape/type is exercised by name across many existing tests; only the
/// title styling changed. See .wyn/docs/design/wyn-027-block-system.md,
/// Screen 2 and Screen 5.
Future<bool> confirmBlock(BuildContext context, {required String username}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 28, color: WynColors.sapphire),
          const SizedBox(height: WynSpacing.space2),
          Text(
            'บล็อก @$username?',
            textAlign: TextAlign.center,
            style: WynTypography.fraunces(fontSize: 17, color: WynColors.ink),
          ),
        ],
      ),
      content: const Text(
        'คุณจะไม่เห็นเนื้อหาของกันและกันอีกต่อไป การติดตามระหว่างกัน (ถ้ามี) '
        'จะถูกยกเลิกทันที ยกเลิกการบล็อกได้ภายหลังที่ตั้งค่า',
        textAlign: TextAlign.center,
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

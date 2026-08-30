import 'package:flutter/material.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/widgets/action_sheet_row.dart';

/// Confirmation for WYN-027 (Block) -- 21-report-block.tsx's
/// `BlockConfirmSheet`: a bottom sheet (icon + title-style header text +
/// supportive line + two full-width pill buttons), not the plain
/// `AlertDialog` this used before. `confirmUnblock` stays an
/// `AlertDialog` -- the reference doesn't design an unblock sheet, and
/// unblock isn't the consequential action block is (WYN-027 Design,
/// Screen 5's own "reversible but still consequential" framing is about
/// block specifically).
Future<bool> confirmBlock(BuildContext context, {required String username}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SheetDragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              WynSpacing.space6, 0, WynSpacing.space6, WynSpacing.space4,
            ),
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 28, color: WynColors.sapphire),
                const SizedBox(height: WynSpacing.space3),
                Text(
                  'บล็อก @$username?',
                  textAlign: TextAlign.center,
                  style: WynTypography.screenTitle(fontSize: 17, color: WynColors.ink),
                ),
                const SizedBox(height: WynSpacing.space2),
                const Text(
                  'คุณจะไม่เห็นเนื้อหาของกันและกันอีกต่อไป การติดตามระหว่างกัน '
                  '(ถ้ามี) จะถูกยกเลิกทันที ยกเลิกการบล็อกได้ภายหลังที่ตั้งค่า',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: WynColors.graphite, height: 1.4),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(true),
                    child: const Text('บล็อก'),
                  ),
                ),
                const SizedBox(height: WynSpacing.space2 + 2),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WynColors.ink,
                      side: const BorderSide(color: WynColors.hairline),
                    ),
                    onPressed: () => Navigator.of(sheetContext).pop(false),
                    child: const Text('ยกเลิก'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: WynSpacing.space4),
        ],
      ),
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

import 'package:flutter/material.dart';

/// WYN-037: Drop delete is now a soft delete (30-day restore window
/// via `soft_delete_drop()`/`restore_drop()` -- see supabase/
/// schema.sql), so this can no longer reuse the shared
/// `confirmDeletePost` dialog (`core/widgets/confirm_delete_dialog.dart`)
/// verbatim -- its "ลบแล้วไม่สามารถกู้คืนได้" copy would now be false
/// for a Drop specifically (still true for comments/Pop, which stay
/// hard-delete-only, so that shared dialog is untouched for them).
Future<bool> confirmDeleteDrop(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('ลบโพสต์นี้?'),
      content: const Text(
        'โพสต์นี้จะหายไปจากทุกที่ทันที แต่คุณกู้คืนได้ภายใน 30 วัน '
        'จาก "รายการที่ลบ" ในหน้าการตั้งค่า',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('ลบ'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

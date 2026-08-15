import 'package:flutter/material.dart';

/// Duplicated from `app/lib/core/widgets/confirm_delete_dialog.dart` --
/// used by `ProductVariantEditor` for hard-deleting an already-saved
/// variant (a real, permanent delete -- see the Product spec's
/// Requirements #4, "product_variants: hard-delete ได้จริง"). Not used
/// for "ลบสินค้า" on the product itself, which is a soft-delete and
/// needs `confirmHideProduct` instead -- its body copy here
/// ("ลบแล้วไม่สามารถกู้คืนได้") would be false for that case.
Future<bool> confirmDeletePost(
  BuildContext context, {
  String itemLabel = 'โพสต์',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('ลบ$itemLabelนี้?'),
      content: const Text('ลบแล้วไม่สามารถกู้คืนได้'),
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

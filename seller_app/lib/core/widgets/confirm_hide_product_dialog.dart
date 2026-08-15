import 'package:flutter/material.dart';

/// A new confirm dialog for "ลบสินค้า" -- deliberately **not** a reuse
/// of `confirmDeletePost`, whose body copy ("ลบแล้วไม่สามารถกู้คืนได้")
/// is false here: SELLER-002's "ลบสินค้า" is a soft-delete
/// (`is_active = false`), fully recoverable through the "ปิดการขาย"
/// filter in `SellerProductListScreen`. Same `AlertDialog` shape/style
/// as `confirmDeletePost` otherwise -- only the content differs. See
/// .wyn/docs/design/seller-002-product-management.md, Dialog:
/// soft-delete confirm.
Future<bool> confirmHideProduct(
  BuildContext context, {
  required String productName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('ลบสินค้า "$productName"?'),
      content: const Text(
        'สินค้านี้จะถูกซ่อนจากลูกค้าทันที ประวัติคำสั่งซื้อเดิมไม่ได้รับผลกระทบ '
        'กู้คืนได้ภายหลังผ่านตัวกรอง \'ปิดการขาย\' ในรายการสินค้า',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('ลบสินค้า'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

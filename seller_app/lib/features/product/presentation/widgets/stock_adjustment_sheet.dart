import 'package:flutter/material.dart';

import '../../../store/data/seller_repository.dart';

/// Opens StockAdjustmentSheet as a modal bottom sheet, same hosting
/// pattern as showReviewFormSheet (ZOKY-004).
Future<void> showStockAdjustmentSheet(
  BuildContext context, {
  required int initialStock,
  required Future<int> Function(int delta) onAdjust,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StockAdjustmentSheet(
      initialStock: initialStock,
      onAdjust: onAdjust,
    ),
  );
}

/// The only place in this app stock can change for an *existing*
/// product/variant (a brand-new one's initial stock is set directly at
/// create time instead -- see the Product spec's Requirements #5) --
/// a delta stepper only, never an absolute-value field, so the
/// underlying `adjust_product_stock`/`adjust_variant_stock` RPC (see
/// supabase/schema.sql) stays the only way stock is ever written.
/// [onAdjust] is `SellerRepository.adjustProductStock`/
/// `adjustVariantStock` bound to a specific product/variant id by the
/// caller -- this widget itself never sees the id, keeping it
/// reusable for both scopes. See
/// .wyn/docs/design/seller-002-product-management.md, Screen:
/// StockAdjustmentSheet.
class StockAdjustmentSheet extends StatefulWidget {
  const StockAdjustmentSheet({
    super.key,
    required this.initialStock,
    required this.onAdjust,
  });

  final int initialStock;
  final Future<int> Function(int delta) onAdjust;

  @override
  State<StockAdjustmentSheet> createState() => _StockAdjustmentSheetState();
}

class _StockAdjustmentSheetState extends State<StockAdjustmentSheet> {
  late int _currentStock = widget.initialStock;
  int _delta = 0;
  bool _isSubmitting = false;

  Future<void> _confirm() async {
    if (_delta == 0 || _isSubmitting) return;
    final delta = _delta;
    setState(() => _isSubmitting = true);
    try {
      final newStock = await widget.onAdjust(delta);
      if (!mounted) return;
      setState(() {
        _currentStock = newStock;
        _delta = 0;
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ปรับสต็อกสำเร็จ')));
    } on InsufficientStockException {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('สต็อกไม่พอ')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ปรับสต็อกไม่สำเร็จ ลองใหม่อีกครั้ง')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // A UX hint only -- the real ceiling that stops stock going
    // negative is the server-side RPC/CHECK constraint, not this.
    final atFloor = _currentStock + _delta <= 0;
    final deltaLabel = _delta > 0 ? '+$_delta' : '$_delta';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'สต็อกปัจจุบัน: $_currentStock ชิ้น',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Center(
              child: Semantics(
                label: _delta == 0
                    ? 'สต็อกปัจจุบัน $_currentStock ชิ้น'
                    : 'สต็อกปัจจุบัน $_currentStock ชิ้น จะปรับเป็น ${_currentStock + _delta} ชิ้น',
                excludeSemantics: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      tooltip: 'ลดจำนวน',
                      onPressed:
                          (_isSubmitting || atFloor) ? null : () => setState(() => _delta--),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        deltaLabel,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      tooltip: 'เพิ่มจำนวน',
                      onPressed: _isSubmitting ? null : () => setState(() => _delta++),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_delta != 0 && !_isSubmitting) ? _confirm : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ยืนยันการปรับสต็อก'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

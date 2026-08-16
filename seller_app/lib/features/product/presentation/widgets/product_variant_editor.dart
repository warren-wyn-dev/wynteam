import 'package:flutter/material.dart';

import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../store/data/seller_repository.dart';
import '../../data/product_variant.dart';
import 'stock_adjustment_sheet.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Add/edit/remove Color/Size variants inside SellerProductFormScreen --
/// a flat list per type, matching ZOKY-001's existing data model
/// exactly (no combination-matrix rework -- see the Product spec's
/// Requirements #3). See
/// .wyn/docs/design/seller-002-product-management.md, Widget:
/// ProductVariantEditor.
class ProductVariantEditor extends StatefulWidget {
  const ProductVariantEditor({
    super.key,
    required this.variants,
    required this.sellerRepository,
    required this.onChanged,
  });

  /// Mutated in place by this widget -- the parent form reads it back
  /// on submit.
  final List<VariantInput> variants;

  final SellerRepository sellerRepository;

  /// Called after every mutation (add/remove row, or a stock
  /// adjustment that changed an existing row's stock) so the parent
  /// form can rebuild.
  final VoidCallback onChanged;

  @override
  State<ProductVariantEditor> createState() => _ProductVariantEditorState();
}

class _ProductVariantEditorState extends State<ProductVariantEditor> {
  final Map<VariantInput, TextEditingController> _valueControllers = {};
  final Map<VariantInput, TextEditingController> _priceDeltaControllers = {};
  final Map<VariantInput, TextEditingController> _stockControllers = {};

  @override
  void dispose() {
    for (final controller in _valueControllers.values) {
      controller.dispose();
    }
    for (final controller in _priceDeltaControllers.values) {
      controller.dispose();
    }
    for (final controller in _stockControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _valueController(VariantInput variant) => _valueControllers
      .putIfAbsent(variant, () => TextEditingController(text: variant.value));

  TextEditingController _priceDeltaController(VariantInput variant) =>
      _priceDeltaControllers.putIfAbsent(
        variant,
        () => TextEditingController(
          text: variant.priceDelta == null ? '' : variant.priceDelta!.toStringAsFixed(0),
        ),
      );

  TextEditingController _stockController(VariantInput variant) => _stockControllers.putIfAbsent(
        variant,
        () => TextEditingController(text: variant.stock == 0 ? '' : '${variant.stock}'),
      );

  void _addVariant(VariantType type) {
    setState(() {
      widget.variants.add(VariantInput(type: type, value: '', stock: 0));
    });
    widget.onChanged();
  }

  Future<void> _removeVariant(VariantInput variant) async {
    // Only an already-persisted row (has a real id) needs confirmation
    // -- it's a real, permanent DB delete. A row added this session
    // (id == null) is just local form state, safely undone by adding
    // it again, per the Design spec's Interactions/ยืนยัน.
    if (variant.id != null) {
      final confirmed = await confirmDeletePost(context, itemLabel: 'ตัวเลือกสินค้า');
      if (!confirmed) return;
    }
    if (!mounted) return;
    setState(() {
      widget.variants.remove(variant);
      _valueControllers.remove(variant)?.dispose();
      _priceDeltaControllers.remove(variant)?.dispose();
      _stockControllers.remove(variant)?.dispose();
    });
    widget.onChanged();
  }

  Future<void> _adjustVariantStock(VariantInput variant) {
    return showStockAdjustmentSheet(
      context,
      initialStock: variant.stock,
      onAdjust: (delta) async {
        final newStock = await widget.sellerRepository.adjustVariantStock(variant.id!, delta);
        if (mounted) {
          setState(() => variant.stock = newStock);
          widget.onChanged();
        }
        return newStock;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ตัวเลือกสินค้า (ไม่บังคับ)', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: WynSpacing.space2),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _addVariant(VariantType.color),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มสี'),
              ),
            ),
            const SizedBox(width: WynSpacing.space2),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _addVariant(VariantType.size),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มขนาด'),
              ),
            ),
          ],
        ),
        for (final variant in widget.variants) _buildRow(variant),
      ],
    );
  }

  Widget _buildRow(VariantInput variant) {
    // A row with no id yet is still local, unsaved form state -- its
    // stock is a plain editable starting value (same reasoning as a
    // brand-new product's initial stock, see the Product spec's
    // Requirements #5), unlike an already-persisted row's stock, which
    // may only change through StockAdjustmentSheet's RPC call.
    final isNewRow = variant.id == null;
    return Padding(
      padding: const EdgeInsets.only(top: WynSpacing.space2),
      child: Container(
        padding: const EdgeInsets.all(WynSpacing.space2),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _valueController(variant),
                    decoration: InputDecoration(
                      labelText: variant.type == VariantType.color ? 'สี' : 'ขนาด',
                    ),
                    onChanged: (text) => variant.value = text,
                  ),
                ),
                const SizedBox(width: WynSpacing.space2),
                Expanded(
                  child: TextField(
                    controller: _priceDeltaController(variant),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'ส่วนต่างราคา (ไม่บังคับ)'),
                    onChanged: (text) => variant.priceDelta = double.tryParse(text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: WynSpacing.space2),
            Row(
              children: [
                Expanded(
                  child: isNewRow
                      ? TextField(
                          controller: _stockController(variant),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'สต็อกเริ่มต้น'),
                          onChanged: (text) => variant.stock = int.tryParse(text) ?? 0,
                        )
                      : Row(
                          children: [
                            Expanded(child: Text('สต็อก: ${variant.stock}')),
                            IconButton(
                              icon: const Icon(Icons.tune, size: 20),
                              tooltip: 'ปรับสต็อกของ ${variant.value}',
                              onPressed: () => _adjustVariantStock(variant),
                            ),
                          ],
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'ลบตัวเลือกนี้',
                  onPressed: () => _removeVariant(variant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

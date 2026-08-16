import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/confirm_hide_product_dialog.dart';
import '../../store/data/seller_repository.dart';
import '../data/category.dart';
import '../data/product.dart';
import '../data/product_variant.dart';
import 'widgets/product_variant_editor.dart';
import 'widgets/stock_adjustment_sheet.dart';
import '../../../core/design/wyn_spacing.dart';

/// Create *and* edit share this single screen -- [existingProduct] null
/// means create mode, non-null means edit mode -- mirroring
/// `ReviewFormSheet`'s `existingReview` ternary shape (ZOKY-004) rather
/// than two separate classes duplicating the whole field/validation
/// set. See .wyn/docs/design/seller-002-product-management.md, Screen:
/// SellerProductFormScreen.
class SellerProductFormScreen extends StatefulWidget {
  const SellerProductFormScreen({
    super.key,
    required this.sellerRepository,
    required this.storeId,
    this.existingProduct,
  });

  final SellerRepository sellerRepository;
  final String storeId;
  final Product? existingProduct;

  @override
  State<SellerProductFormScreen> createState() => _SellerProductFormScreenState();
}

class _SellerProductFormScreenState extends State<SellerProductFormScreen> {
  static const _maxImages = 10;

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skuController = TextEditingController();
  final _initialStockController = TextEditingController();

  final List<String> _existingImageUrls = [];
  final List<Uint8List> _newImages = [];
  final List<String> _newImageExtensions = [];

  List<Category> _categories = [];
  List<VariantInput> _variants = [];
  Category? _selectedCategory;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _originalPriceError;

  late int _currentStock = widget.existingProduct?.stock ?? 0;
  late bool _isActive = widget.existingProduct?.isActive ?? true;

  bool get _isEditing => widget.existingProduct != null;
  int get _totalImageCount => _existingImageUrls.length + _newImages.length;

  @override
  void initState() {
    super.initState();
    final product = widget.existingProduct;
    if (product != null) {
      _nameController.text = product.name;
      _priceController.text = _formatNumber(product.price);
      if (product.originalPrice != null) {
        _originalPriceController.text = _formatNumber(product.originalPrice!);
      }
      _descriptionController.text = product.description ?? '';
      _skuController.text = product.sku ?? '';
      _existingImageUrls.addAll(product.imageUrls);
    }
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _originalPriceController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _initialStockController.dispose();
    super.dispose();
  }

  String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();

  Future<void> _load() async {
    final categories = await widget.sellerRepository.fetchCategories();
    var selected = <Category>[];
    final product = widget.existingProduct;
    if (product != null && product.categoryId != null) {
      selected = categories.where((c) => c.id == product.categoryId).toList();
    }

    var variantInputs = <VariantInput>[];
    if (product != null) {
      final existingVariants = await widget.sellerRepository.fetchProductVariants(product.id);
      variantInputs = existingVariants
          .map((v) => VariantInput(
                id: v.id,
                type: v.type,
                value: v.value,
                priceDelta: v.priceDelta,
                stock: v.stock,
              ))
          .toList();
    }

    if (!mounted) return;
    setState(() {
      _categories = categories;
      _selectedCategory = selected.isNotEmpty ? selected.first : null;
      _variants = variantInputs;
      _isLoading = false;
    });
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _totalImageCount;
    if (remaining <= 0) return;

    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      limit: remaining,
    );
    if (picked.isEmpty) return;

    for (final file in picked.take(remaining)) {
      final bytes = await file.readAsBytes();
      final extension =
          file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
      _newImages.add(bytes);
      _newImageExtensions.add(extension);
    }
    if (!mounted) return;
    setState(() {});
  }

  void _removeImage(int index) {
    setState(() {
      if (index < _existingImageUrls.length) {
        _existingImageUrls.removeAt(index);
      } else {
        final newIndex = index - _existingImageUrls.length;
        _newImages.removeAt(newIndex);
        _newImageExtensions.removeAt(newIndex);
      }
    });
  }

  bool get _canSubmit {
    if (_isSubmitting || _isLoading) return false;
    if (_nameController.text.trim().isEmpty) return false;
    if (_totalImageCount == 0) return false;
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price < 0) return false;
    if (!_isEditing && _selectedCategory == null) return false;
    return true;
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    // Mirrors _canSubmit's own price >= 0 gate -- re-checked here too
    // (not just relied on via the disabled button) in case this is
    // ever reached programmatically, same defensive-guard shape as
    // every other submit handler in this codebase.
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price < 0) return;

    double? originalPrice;
    final originalPriceText = _originalPriceController.text.trim();
    if (originalPriceText.isNotEmpty) {
      originalPrice = double.tryParse(originalPriceText);
    }

    setState(() {
      _originalPriceError = null;
      _errorMessage = null;
    });

    if (originalPrice != null && originalPrice < price) {
      setState(() => _originalPriceError = 'ราคาก่อนลดต้องมากกว่าหรือเท่ากับราคาจริง');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isEditing) {
        await widget.sellerRepository.updateProduct(
          productId: widget.existingProduct!.id,
          name: name,
          price: price,
          originalPrice: originalPrice,
          categoryId: _selectedCategory?.id,
          description: _descriptionController.text,
          sku: _skuController.text,
          imageUrls: _existingImageUrls,
          newImages: _newImages,
          newImageExtensions: _newImageExtensions,
          variants: _variants,
        );
      } else {
        await widget.sellerRepository.createProduct(
          storeId: widget.storeId,
          name: name,
          price: price,
          originalPrice: originalPrice,
          categoryId: _selectedCategory?.id,
          description: _descriptionController.text,
          sku: _skuController.text,
          initialStock: int.tryParse(_initialStockController.text.trim()) ?? 0,
          images: _newImages,
          imageExtensions: _newImageExtensions,
          variants: _variants,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            _isEditing ? 'บันทึกสินค้าไม่สำเร็จ ลองใหม่อีกครั้ง' : 'สร้างสินค้าไม่สำเร็จ ลองใหม่อีกครั้ง';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _adjustProductStock() {
    final product = widget.existingProduct!;
    return showStockAdjustmentSheet(
      context,
      initialStock: _currentStock,
      onAdjust: (delta) async {
        final newStock = await widget.sellerRepository.adjustProductStock(product.id, delta);
        if (mounted) setState(() => _currentStock = newStock);
        return newStock;
      },
    );
  }

  Future<void> _toggleActive() async {
    final product = widget.existingProduct!;
    if (_isActive) {
      final confirmed = await confirmHideProduct(context, productName: product.name);
      if (!confirmed) return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.sellerRepository.setProductActive(product.id, !_isActive);
      if (!mounted) return;
      setState(() {
        _isActive = !_isActive;
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isActive ? 'เปิดขายสินค้านี้แล้ว' : 'ซ่อนสินค้าแล้ว')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ดำเนินการไม่สำเร็จ ลองใหม่อีกครั้ง')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(_isEditing ? 'แก้ไขสินค้า' : 'เพิ่มสินค้า'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: WynSpacing.space2),
            child: Center(
              child: TextButton(
                onPressed: _canSubmit ? _submit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'บันทึกการแก้ไข' : 'สร้างสินค้า'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_totalImageCount > 0) _buildImageRow(),
                    const SizedBox(height: WynSpacing.space1),
                    Text(
                      'รูปแรกจะเป็นรูปหน้าปกสินค้า',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: WynSpacing.space2),
                    OutlinedButton.icon(
                      onPressed: (_isSubmitting || _totalImageCount >= _maxImages)
                          ? null
                          : _pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('แนบรูปสินค้า'),
                    ),
                    const SizedBox(height: WynSpacing.space4),
                    TextField(
                      controller: _nameController,
                      maxLength: 200,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(labelText: 'ชื่อสินค้า'),
                      onChanged: (_) => setState(() {}),
                    ),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(labelText: 'ราคา'),
                      onChanged: (_) => setState(() {}),
                    ),
                    TextField(
                      controller: _originalPriceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      enabled: !_isSubmitting,
                      decoration: InputDecoration(
                        labelText: 'ราคาก่อนลด (ไม่บังคับ)',
                        errorText: _originalPriceError,
                      ),
                    ),
                    const SizedBox(height: WynSpacing.space2),
                    DropdownButtonFormField<Category>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                      items: _categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() => _selectedCategory = value),
                    ),
                    const SizedBox(height: WynSpacing.space2),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 4,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(labelText: 'คำอธิบาย (ไม่บังคับ)'),
                    ),
                    TextField(
                      controller: _skuController,
                      enabled: !_isSubmitting,
                      decoration: const InputDecoration(labelText: 'SKU (ไม่บังคับ)'),
                    ),
                    const SizedBox(height: WynSpacing.space2),
                    if (_isEditing) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(WynSpacing.space3),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text('สต็อกปัจจุบัน: $_currentStock ชิ้น'),
                              ),
                              TextButton(
                                onPressed: _isSubmitting ? null : _adjustProductStock,
                                child: const Text('ปรับสต็อก'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      TextField(
                        controller: _initialStockController,
                        keyboardType: TextInputType.number,
                        enabled: !_isSubmitting,
                        decoration: const InputDecoration(
                          labelText: 'จำนวนสินค้าเริ่มต้น',
                          hintText: '0',
                        ),
                      ),
                    ],
                    const SizedBox(height: WynSpacing.space4),
                    ProductVariantEditor(
                      variants: _variants,
                      sellerRepository: widget.sellerRepository,
                      onChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: WynSpacing.space4),
                    FilledButton(
                      onPressed: _canSubmit ? _submit : null,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isEditing ? 'บันทึกการแก้ไข' : 'สร้างสินค้า'),
                    ),
                    if (_isSubmitting) ...[
                      const SizedBox(height: WynSpacing.space2),
                      Text(
                        'กำลังอัปโหลดรูปภาพ...',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: WynSpacing.space4),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    if (_isEditing) ...[
                      const SizedBox(height: WynSpacing.space1),
                      TextButton(
                        onPressed: _isSubmitting ? null : _toggleActive,
                        style: TextButton.styleFrom(
                          foregroundColor: _isActive
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.tertiary,
                        ),
                        child: Text(_isActive ? 'ลบสินค้า' : 'เปิดขายอีกครั้ง'),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildImageRow() {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),
        itemCount: _totalImageCount,
        separatorBuilder: (context, index) => const SizedBox(width: WynSpacing.space2),
        itemBuilder: (context, index) {
          final isExisting = index < _existingImageUrls.length;
          final imageWidget = isExisting
              ? Image.network(
                  _existingImageUrls[index],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                )
              : Image.memory(
                  _newImages[index - _existingImageUrls.length],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                );
          return Stack(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(WynSpacing.radiusSm), child: imageWidget),
              Positioned(
                right: 0,
                top: 0,
                child: Semantics(
                  label: 'ลบรูปที่ ${index + 1}',
                  button: true,
                  child: GestureDetector(
                    onTap: _isSubmitting ? null : () => _removeImage(index),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../search/presentation/widgets/search_state_message.dart';
import '../../data/category.dart';
import '../../data/product.dart';
import '../../data/zoky_repository.dart';
import '../product_detail_screen.dart';
import 'product_grid_tile.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Search's Product tab (ZOKY-002) -- category/price filter + sort
/// controls above a GridView of ProductGridTile, same widget ZOKY Home's
/// main grid uses. Query comes from [query], a prop from the shared
/// search box in ZokySearchScreen, same debounce pattern as
/// SearchDropResultsTab/SearchClubResultsTab (WYN-009/WYN-015).
class ZokyProductResultsTab extends StatefulWidget {
  const ZokyProductResultsTab({
    super.key,
    required this.query,
    required this.zokyRepository,
    this.initialCategory,
  });

  final String query;
  final ZokyRepository zokyRepository;
  final Category? initialCategory;

  @override
  State<ZokyProductResultsTab> createState() => _ZokyProductResultsTabState();
}

class _ZokyProductResultsTabState extends State<ZokyProductResultsTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final List<Product> _products = [];
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  Category? _category;
  double? _minPrice;
  double? _maxPrice;
  ProductSortBy _sortBy = ProductSortBy.newest;

  @override
  bool get wantKeepAlive => true;

  bool get _queryTooShort => widget.query.trim().length < 2;

  int get _activeFilterCount =>
      (_category != null ? 1 : 0) + (_minPrice != null || _maxPrice != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _scrollController.addListener(_onScroll);
    if (!_queryTooShort) _search(reset: true);
  }

  @override
  void didUpdateWidget(covariant ZokyProductResultsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _products.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      if (!_queryTooShort) _search(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || !_hasMore || _queryTooShort) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _search(reset: false);
    }
  }

  Future<void> _search({required bool reset}) async {
    setState(() {
      _isLoading = true;
      if (reset) _error = null;
    });
    try {
      final page = reset ? 0 : _page + 1;
      final results = await widget.zokyRepository.searchProducts(
        query: widget.query.trim(),
        categoryId: _category?.id,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        sortBy: _sortBy,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _products
            ..clear()
            ..addAll(results);
        } else {
          _products.addAll(results);
        }
        _page = page;
        _hasMore = results.length == ZokyRepository.searchPageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'ค้นหาไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          zokyRepository: widget.zokyRepository,
          product: product,
        ),
      ),
    );
  }

  Future<void> _openFilterSheet() async {
    final minController = TextEditingController(text: _minPrice?.toStringAsFixed(0) ?? '');
    final maxController = TextEditingController(text: _maxPrice?.toStringAsFixed(0) ?? '');
    final categoriesFuture = widget.zokyRepository.fetchCategories();

    final result = await showModalBottomSheet<({Category? category, double? min, double? max})>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var selectedCategory = _category;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('ตัวกรอง', style: Theme.of(context).textTheme.titleMedium),
                      if (selectedCategory != null ||
                          minController.text.isNotEmpty ||
                          maxController.text.isNotEmpty)
                        TextButton(
                          onPressed: () => setSheetState(() {
                            selectedCategory = null;
                            minController.clear();
                            maxController.clear();
                          }),
                          child: const Text('ล้างตัวกรอง'),
                        ),
                    ],
                  ),
                  const SizedBox(height: WynSpacing.space2),
                  Text('หมวดหมู่', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: WynSpacing.space2),
                  FutureBuilder<List<Category>>(
                    future: categoriesFuture,
                    builder: (context, snapshot) {
                      final categories = snapshot.data ?? const [];
                      return Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('ทั้งหมด'),
                            selected: selectedCategory == null,
                            onSelected: (_) => setSheetState(() => selectedCategory = null),
                          ),
                          ...categories.map(
                            (category) => ChoiceChip(
                              label: Text(category.name),
                              selected: selectedCategory?.id == category.id,
                              onSelected: (_) =>
                                  setSheetState(() => selectedCategory = category),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: WynSpacing.space4),
                  Text('ช่วงราคา', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: WynSpacing.space2),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'ราคาต่ำสุด'),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: WynSpacing.space2),
                        child: Text('–'),
                      ),
                      Expanded(
                        child: TextField(
                          controller: maxController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'ราคาสูงสุด'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: WynSpacing.space4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop((
                        category: selectedCategory,
                        min: double.tryParse(minController.text.trim()),
                        max: double.tryParse(maxController.text.trim()),
                      )),
                      child: const Text('แสดงผลลัพธ์'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() {
      _category = result.category;
      _minPrice = result.min;
      _maxPrice = result.max;
    });
    if (!_queryTooShort) _search(reset: true);
  }

  Future<void> _openSortMenu() async {
    final box = context.findRenderObject() as RenderBox?;
    final selected = await showMenu<ProductSortBy>(
      context: context,
      position: RelativeRect.fromLTRB(
        box?.size.width ?? 0,
        kToolbarHeight,
        0,
        0,
      ),
      items: const [
        PopupMenuItem(value: ProductSortBy.newest, child: Text('ใหม่ล่าสุด')),
        PopupMenuItem(value: ProductSortBy.priceLowToHigh, child: Text('ราคา: ต่ำ → สูง')),
        PopupMenuItem(value: ProductSortBy.priceHighToLow, child: Text('ราคา: สูง → ต่ำ')),
      ],
    );
    if (selected == null || selected == _sortBy) return;
    setState(() => _sortBy = selected);
    if (!_queryTooShort) _search(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space2),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openFilterSheet,
                  icon: const Icon(Icons.tune),
                  label: Text(_activeFilterCount > 0 ? 'ตัวกรอง ($_activeFilterCount)' : 'ตัวกรอง'),
                ),
              ),
              const SizedBox(width: WynSpacing.space2),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openSortMenu,
                  icon: const Icon(Icons.sort),
                  label: const Text('เรียงลำดับ'),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildResults(context)),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_queryTooShort) {
      return const SearchStateMessage(
        icon: Icons.inventory_2_outlined,
        text: 'พิมพ์ชื่อสินค้าเพื่อค้นหา',
      );
    }

    if (_isLoading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: () => _search(reset: true), child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      return SearchStateMessage(
        icon: Icons.inventory_2_outlined,
        text: 'ไม่พบสินค้าสำหรับ "${widget.query.trim()}"',
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return ProductGridTile(product: product, onTap: () => _openProduct(product));
      },
    );
  }
}

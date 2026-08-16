import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/widgets/search_state_message.dart';
import '../../store/data/seller_repository.dart';
import '../../store/data/store.dart';
import '../data/product.dart';
import 'seller_product_form_screen.dart';
import 'widgets/seller_product_list_tile.dart';
import '../../../core/design/wyn_spacing.dart';

/// Tab 2 ("สินค้า") of `SellerHomeShell`, replacing
/// `SellerComingSoonScreen(label: 'สินค้า')`. See
/// .wyn/docs/design/seller-002-product-management.md, Screen:
/// SellerProductListScreen.
class SellerProductListScreen extends StatefulWidget {
  const SellerProductListScreen({
    super.key,
    required this.store,
    required this.sellerRepository,
  });

  final Store store;
  final SellerRepository sellerRepository;

  @override
  State<SellerProductListScreen> createState() => _SellerProductListScreenState();
}

class _SellerProductListScreenState extends State<SellerProductListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounceTimer;

  final List<Product> _products = [];
  int _page = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  ProductStatusFilter _filter = ProductStatusFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  void _onQueryChanged(String text) {
    _debounceTimer?.cancel();
    setState(() {});
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _query = text.trim());
      _loadInitial();
    });
  }

  void _clearQuery() {
    _debounceTimer?.cancel();
    _searchController.clear();
    setState(() => _query = '');
    _loadInitial();
  }

  void _selectFilter(ProductStatusFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await widget.sellerRepository.fetchProducts(
        storeId: widget.store.id,
        filter: _filter,
        query: _query,
        page: 0,
      );
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(page);
        _page = 0;
        _hasMore = page.length == SellerRepository.productsPageSize;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดรายการสินค้าไม่สำเร็จ';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final page = await widget.sellerRepository.fetchProducts(
      storeId: widget.store.id,
      filter: _filter,
      query: _query,
      page: nextPage,
    );
    if (!mounted) return;
    setState(() {
      _products.addAll(page);
      _page = nextPage;
      _hasMore = page.length == SellerRepository.productsPageSize;
      _isLoadingMore = false;
    });
  }

  Future<void> _openForm({Product? product}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SellerProductFormScreen(
          sellerRepository: widget.sellerRepository,
          storeId: widget.store.id,
          existingProduct: product,
        ),
      ),
    );
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สินค้า')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space2),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อสินค้า/SKU',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : Semantics(
                        label: 'ล้างคำค้นหา',
                        button: true,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _clearQuery,
                        ),
                      ),
              ),
              onChanged: _onQueryChanged,
            ),
          ),
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'เพิ่มสินค้า',
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChips() {
    const options = [
      (ProductStatusFilter.all, 'ทั้งหมด'),
      (ProductStatusFilter.active, 'กำลังขาย'),
      (ProductStatusFilter.inactive, 'ปิดการขาย'),
      (ProductStatusFilter.outOfStock, 'สินค้าหมด'),
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: WynSpacing.space2),
        children: [
          for (final (filter, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: WynSpacing.space2),
              child: ChoiceChip(
                label: Text(label),
                selected: _filter == filter,
                onSelected: (_) => _selectFilter(filter),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_products.isEmpty) {
      final isFilteredOrSearched = _filter != ProductStatusFilter.all || _query.isNotEmpty;
      if (isFilteredOrSearched) {
        return SearchStateMessage(
          icon: Icons.inventory_2_outlined,
          text: _query.isNotEmpty ? 'ไม่พบสินค้าสำหรับ "$_query"' : 'ไม่พบสินค้าที่ตรงกับตัวกรอง',
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: WynSpacing.space4),
              const Text(
                'ยังไม่มีสินค้าในร้านเลย เริ่มเพิ่มสินค้าชิ้นแรกกันเถอะ',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: WynSpacing.space4),
              FilledButton(
                onPressed: () => _openForm(),
                child: const Text('+ เพิ่มสินค้า'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _products.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _products.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final product = _products[index];
          return SellerProductListTile(
            product: product,
            onTap: () => _openForm(product: product),
          );
        },
      ),
    );
  }
}

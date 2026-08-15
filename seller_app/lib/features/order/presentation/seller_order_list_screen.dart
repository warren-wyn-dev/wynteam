import 'package:flutter/material.dart';

import '../../../core/widgets/search_state_message.dart';
import '../../store/data/seller_repository.dart';
import '../../store/data/store.dart';
import '../data/order.dart';
import '../data/order_item.dart';
import 'seller_order_detail_screen.dart';
import 'widgets/seller_order_list_tile.dart';

/// Tab 3 ("คำสั่งซื้อ") of `SellerHomeShell`, replacing
/// `SellerComingSoonScreen(label: 'คำสั่งซื้อ')` (SELLER-003). See
/// .wyn/docs/design/seller-003-order-management.md, Screen:
/// SellerOrderListScreen.
class SellerOrderListScreen extends StatefulWidget {
  const SellerOrderListScreen({
    super.key,
    required this.store,
    required this.sellerRepository,
  });

  final Store store;
  final SellerRepository sellerRepository;

  @override
  State<SellerOrderListScreen> createState() => _SellerOrderListScreenState();
}

class _SellerOrderListScreenState extends State<SellerOrderListScreen> {
  final _scrollController = ScrollController();

  final List<(Order, List<OrderItem>)> _orders = [];
  int _page = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  OrderStatus? _filter;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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

  void _selectFilter(OrderStatus? filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _loadInitial();
  }

  Future<List<(Order, List<OrderItem>)>> _fetchPage(int page) async {
    final orders = await widget.sellerRepository.fetchStoreOrders(
      storeId: widget.store.id,
      filter: _filter,
      page: page,
    );
    final result = <(Order, List<OrderItem>)>[];
    for (final order in orders) {
      final items = await widget.sellerRepository.fetchStoreOrderItems(order.id);
      result.add((order, items));
    }
    return result;
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await _fetchPage(0);
      if (!mounted) return;
      setState(() {
        _orders
          ..clear()
          ..addAll(page);
        _page = 0;
        _hasMore = page.length == SellerRepository.ordersPageSize;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดรายการคำสั่งซื้อไม่สำเร็จ';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final page = await _fetchPage(nextPage);
    if (!mounted) return;
    setState(() {
      _orders.addAll(page);
      _page = nextPage;
      _hasMore = page.length == SellerRepository.ordersPageSize;
      _isLoadingMore = false;
    });
  }

  void _openOrder(Order order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerOrderDetailScreen(
          sellerRepository: widget.sellerRepository,
          orderId: order.id,
        ),
      ),
    );
    // Always reload -- the order may have had its status changed while
    // the detail screen was open, same reasoning as
    // SellerProductListScreen._openForm not checking the return value.
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คำสั่งซื้อ')),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    const options = <(OrderStatus?, String)>[
      (null, 'ทั้งหมด'),
      (OrderStatus.paid, 'ชำระเงินแล้ว'),
      (OrderStatus.sellerProcessing, 'ร้านค้ากำลังเตรียมสินค้า'),
      (OrderStatus.readyToShip, 'พร้อมจัดส่ง'),
      (OrderStatus.shipped, 'จัดส่งแล้ว'),
      (OrderStatus.delivered, 'ได้รับสินค้าแล้ว'),
      (OrderStatus.cancelled, 'ยกเลิกแล้ว'),
      (OrderStatus.refunded, 'คืนเงินแล้ว'),
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final (filter, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
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
            const SizedBox(height: 12),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      if (_filter != null) {
        return const SearchStateMessage(
          icon: Icons.receipt_long_outlined,
          text: 'ไม่พบคำสั่งซื้อในสถานะนี้',
        );
      }
      return const SearchStateMessage(
        icon: Icons.receipt_long_outlined,
        text: 'ยังไม่มีคำสั่งซื้อเข้ามา',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _orders.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _orders.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final (order, items) = _orders[index];
          return SellerOrderListTile(
            order: order,
            items: items,
            onTap: () => _openOrder(order),
          );
        },
      ),
    );
  }
}

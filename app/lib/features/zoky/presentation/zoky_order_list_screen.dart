import 'package:flutter/material.dart';

import '../../search/presentation/widgets/search_state_message.dart';
import '../data/order.dart';
import '../data/order_item.dart';
import '../data/zoky_repository.dart';
import 'widgets/order_summary_card.dart';
import 'zoky_order_detail_screen.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_zoky_accent.dart';

/// Screen 5 (ZOKY-003) -- the buyer's order history. Opened from ZOKY
/// Home's Orders icon (replacing the SnackBar placeholder from
/// ZOKY-001). See .wyn/docs/design/zoky-003-cart-checkout-order.md,
/// Screen 5.
class ZokyOrderListScreen extends StatefulWidget {
  const ZokyOrderListScreen({super.key, required this.zokyRepository});

  final ZokyRepository zokyRepository;

  @override
  State<ZokyOrderListScreen> createState() => _ZokyOrderListScreenState();
}

class _ZokyOrderListScreenState extends State<ZokyOrderListScreen> {
  final _scrollController = ScrollController();
  final List<(Order, List<OrderItem>)> _orders = [];
  int _page = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

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

  Future<List<(Order, List<OrderItem>)>> _fetchPage(int page) async {
    final orders = await widget.zokyRepository.fetchOrders(page: page);
    final result = <(Order, List<OrderItem>)>[];
    for (final order in orders) {
      final items = await widget.zokyRepository.fetchOrderItems(order.id);
      result.add((order, items));
    }
    return result;
  }

  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);
    final page = await _fetchPage(0);
    if (!mounted) return;
    setState(() {
      _orders
        ..clear()
        ..addAll(page);
      _page = 0;
      _hasMore = page.length == ZokyRepository.ordersPageSize;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    final nextPage = _page + 1;
    final page = await _fetchPage(nextPage);
    if (!mounted) return;
    setState(() {
      _orders.addAll(page);
      _page = nextPage;
      _hasMore = page.length == ZokyRepository.ordersPageSize;
      _isLoadingMore = false;
    });
  }

  void _openOrder(Order order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZokyOrderDetailScreen(
          zokyRepository: widget.zokyRepository,
          orderId: order.id,
        ),
      ),
    );
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return ZokyAccentTheme(child: Scaffold(
      appBar: AppBar(title: const Text('คำสั่งซื้อของฉัน')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const SearchStateMessage(
                  icon: Icons.receipt_long_outlined,
                  text: 'ยังไม่มีคำสั่งซื้อ',
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),
                  itemCount: _orders.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index >= _orders.length) {
                      return const Padding(
                        padding: EdgeInsets.all(WynSpacing.space4),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final (order, items) = _orders[index];
                    return OrderSummaryCard(
                      order: order,
                      items: items,
                      onTap: () => _openOrder(order),
                    );
                  },
                ),
    ));
  }
}

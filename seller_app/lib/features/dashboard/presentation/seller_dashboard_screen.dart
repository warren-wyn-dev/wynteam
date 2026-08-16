import 'package:flutter/material.dart';

import '../../../core/text_utils.dart';
import '../../notification/data/seller_notification_repository.dart';
import '../../notification/presentation/seller_notification_list_screen.dart';
import '../../store/data/seller_repository.dart';
import '../../store/data/store.dart';
import '../../../core/design/wyn_spacing.dart';

class _DashboardStats {
  const _DashboardStats({
    required this.newOrders,
    required this.totalOrders,
    required this.todaySales,
    required this.monthSales,
    required this.allTimeSales,
    required this.bestSelling,
  });

  final int newOrders;
  final int totalOrders;
  final double todaySales;
  final double monthSales;
  final double allTimeSales;
  final List<(String, int)> bestSelling;
}

/// Seller Dashboard -- the only fully-built tab in SellerHomeShell this
/// round (the other 4 are SellerComingSoonScreen placeholders). See
/// .wyn/docs/design/seller-001-foundation.md, Screen:
/// SellerDashboardScreen.
class SellerDashboardScreen extends StatefulWidget {
  const SellerDashboardScreen({
    super.key,
    required this.store,
    required this.sellerRepository,
    required this.notificationRepository,
  });

  final Store store;
  final SellerRepository sellerRepository;
  final SellerNotificationRepository notificationRepository;

  @override
  State<SellerDashboardScreen> createState() => _SellerDashboardScreenState();
}

class _SellerDashboardScreenState extends State<SellerDashboardScreen> {
  Future<_DashboardStats>? _statsFuture;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _loadUnreadNotificationCount();
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await widget.notificationRepository.countUnread();
      if (!mounted) return;
      setState(() => _unreadNotificationCount = count);
    } catch (_) {
      // Silent, same as `app/`'s HomeFeedScreen -- a failed badge-count
      // fetch just leaves the badge showing its last known value.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerNotificationListScreen(
          notificationRepository: widget.notificationRepository,
          sellerRepository: widget.sellerRepository,
        ),
      ),
    );
    // SellerNotificationListScreen marks everything as read on open --
    // refresh so the badge reflects that once the user comes back.
    _loadUnreadNotificationCount();
  }

  Widget _buildNotificationButton(BuildContext context) {
    final count = _unreadNotificationCount;
    final badgeText = count > 9 ? '9+' : '$count';

    return Semantics(
      label: count > 0 ? 'การแจ้งเตือน มี $count รายการที่ยังไม่อ่าน' : 'การแจ้งเตือน',
      button: true,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _openNotifications,
          ),
          if (count > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space1, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                ),
                child: Text(
                  badgeText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _load() {
    // Deliberately a block body, not `setState(() => _statsFuture =
    // _fetchStats())` -- an arrow closure returns the value of its
    // body expression, and an assignment expression evaluates to the
    // assigned value, so that shorthand would make this callback
    // return a Future (silently, since it type-checks against
    // VoidCallback fine) and trip Flutter's "setState() callback
    // argument returned a Future" assertion at runtime.
    setState(() {
      _statsFuture = _fetchStats();
    });
  }

  /// Every number here is a fresh query, every time this screen loads
  /// or is pulled-to-refresh -- never cached/denormalized (Product
  /// spec: "ทุกค่าคำนวณจาก query สดทุกครั้งที่เปิดหน้า").
  Future<_DashboardStats> _fetchStats() async {
    final storeId = widget.store.id;
    final orderCounts = await widget.sellerRepository.fetchOrderCounts(storeId);
    final salesSummary =
        await widget.sellerRepository.fetchSalesSummary(storeId);
    final bestSelling =
        await widget.sellerRepository.fetchBestSellingProducts(storeId);
    return _DashboardStats(
      newOrders: orderCounts.$1,
      totalOrders: orderCounts.$2,
      todaySales: salesSummary.$1,
      monthSales: salesSummary.$2,
      allTimeSales: salesSummary.$3,
      bestSelling: bestSelling,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แดชบอร์ด'),
        actions: [_buildNotificationButton(context)],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            _load();
            await _statsFuture;
          },
          child: FutureBuilder<_DashboardStats>(
            future: _statsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                // Silent-fail -- one bad query shouldn't crash the whole
                // Dashboard. Mirrors the error-tolerance pattern ZOKY
                // screens already use (see
                // .wyn/docs/design/seller-001-foundation.md, States).
                return ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('โหลดไม่สำเร็จ')),
                  ],
                );
              }

              final stats = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.all(WynSpacing.space4),
                children: [
                  Text(
                    widget.store.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: WynSpacing.space4),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'คำสั่งซื้อใหม่',
                          value: '${stats.newOrders}',
                        ),
                      ),
                      const SizedBox(width: WynSpacing.space3),
                      Expanded(
                        child: _StatCard(
                          label: 'คำสั่งซื้อทั้งหมด',
                          value: '${stats.totalOrders}',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: WynSpacing.space3),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(WynSpacing.space4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'ยอดขาย',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: WynSpacing.space2),
                          _summaryRow('วันนี้', thaiBahtLabel(stats.todaySales)),
                          _summaryRow(
                              'เดือนนี้', thaiBahtLabel(stats.monthSales)),
                          _summaryRow(
                              'รวมทั้งหมด', thaiBahtLabel(stats.allTimeSales)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: WynSpacing.space3),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(WynSpacing.space4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'สินค้าขายดี',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: WynSpacing.space2),
                          if (stats.bestSelling.isEmpty)
                            const Text('ยังไม่มีข้อมูลการขาย')
                          else
                            for (final entry in stats.bestSelling)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: WynSpacing.space1),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(entry.$1)),
                                    Text('ขายแล้ว ${entry.$2}'),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: WynSpacing.space3),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(WynSpacing.space4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'ยอดคงเหลือ / รอโอน',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: WynSpacing.space2),
                          // Intentionally not a fake "฿0" -- there's no
                          // Payout system yet at all (Product spec:
                          // "ห้ามแสดงเลข 0 ที่ทำให้เข้าใจผิดว่าคำนวณแล้ว
                          // จริง").
                          const Text('เร็ว ๆ นี้'),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WynSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: WynSpacing.space1),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../../../core/text_utils.dart';
import '../../order/presentation/seller_order_detail_screen.dart';
import '../../store/data/seller_repository.dart';
import '../data/seller_notification.dart';
import '../data/seller_notification_repository.dart';

/// Seller's notification list -- mirrors `app/`'s
/// `NotificationListScreen` (WYN-012/WYN-015) row/pagination/mark-as-
/// read structure exactly, scoped to the 2 order types a seller can
/// receive (ZOKY-005 R1). See .wyn/tasks/backlog/ZOKY-005-customer-
/// seller-backend-integration.md, Acceptance Criteria.
class SellerNotificationListScreen extends StatefulWidget {
  const SellerNotificationListScreen({
    super.key,
    required this.notificationRepository,
    required this.sellerRepository,
  });

  final SellerNotificationRepository notificationRepository;
  final SellerRepository sellerRepository;

  @override
  State<SellerNotificationListScreen> createState() => _SellerNotificationListScreenState();
}

class _SellerNotificationListScreenState extends State<SellerNotificationListScreen> {
  final _scrollController = ScrollController();
  final List<SellerNotification> _notifications = [];

  // Same "snapshot the unread set at fetch time" reasoning as `app/`'s
  // NotificationListScreen -- see that screen's identical field.
  final Set<String> _unreadSnapshot = {};

  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

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

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final notifications = await widget.notificationRepository.fetchNotifications(page: 0);
      setState(() {
        _notifications
          ..clear()
          ..addAll(notifications);
        _unreadSnapshot
          ..clear()
          ..addAll(notifications.where((n) => !n.isRead).map((n) => n.id));
        _page = 0;
        _hasMore = notifications.length == SellerNotificationRepository.pageSize;
      });
      unawaited(widget.notificationRepository.markAllAsRead());
    } catch (_) {
      setState(() => _error = 'โหลดการแจ้งเตือนไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final notifications =
          await widget.notificationRepository.fetchNotifications(page: nextPage);
      setState(() {
        _notifications.addAll(notifications);
        _unreadSnapshot.addAll(notifications.where((n) => !n.isRead).map((n) => n.id));
        _page = nextPage;
        _hasMore = notifications.length == SellerNotificationRepository.pageSize;
      });
    } catch (_) {
      // Silent, same as `app/`'s equivalent -- scrolling again retries it.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _openNotification(SellerNotification notification) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SellerOrderDetailScreen(
          sellerRepository: widget.sellerRepository,
          orderId: notification.orderId,
        ),
      ),
    );
  }

  String _messageFor(SellerNotification notification) {
    final name = displayNameOrUsername(
      displayName: notification.buyerDisplayName,
      username: notification.buyerUsername,
    );
    switch (notification.type) {
      case SellerNotificationType.newOrder:
        return '$name สั่งซื้อสินค้าจากร้านของคุณ';
      case SellerNotificationType.orderCancelled:
        return '$name ยกเลิกคำสั่งซื้อที่ร้านของคุณ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือน')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingInitial) {
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

    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: WynSpacing.space4),
              const Text('ยังไม่มีการแจ้งเตือน', textAlign: TextAlign.center),
              const SizedBox(height: WynSpacing.space2),
              Text(
                'เมื่อมีคำสั่งซื้อใหม่หรือมีการยกเลิกคำสั่งซื้อ จะเห็นที่นี่',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _notifications.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _notifications.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final notification = _notifications[index];
          final isUnread = _unreadSnapshot.contains(notification.id);
          final message = _messageFor(notification);
          final time = relativeTimeLabel(notification.createdAt, now: DateTime.now());

          return Container(
            color: isUnread
                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35)
                : null,
            child: Semantics(
              label: '$message $time${isUnread ? ' ยังไม่ได้อ่าน' : ''}',
              button: true,
              excludeSemantics: true,
              child: InkWell(
                onTap: () => _openNotification(notification),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        child: Icon(
                          notification.type == SellerNotificationType.newOrder
                              ? Icons.receipt_long
                              : Icons.cancel_outlined,
                        ),
                      ),
                      const SizedBox(width: WynSpacing.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(message, style: Theme.of(context).textTheme.bodyMedium),
                            Text(
                              time,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.outline,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

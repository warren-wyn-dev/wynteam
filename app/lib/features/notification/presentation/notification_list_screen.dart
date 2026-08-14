import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/text_utils.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_detail_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../home/presentation/pop_single_clip_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../../saved/data/saved_repository.dart';
import '../data/notification.dart';
import '../data/notification_repository.dart';

/// Screen 2 — Notification list (WYN-012). Row structure mirrors
/// FollowListScreen (WYN-008/013) exactly. See
/// .wyn/docs/design/wyn-012-notification.md.
class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({
    super.key,
    required this.notificationRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.savedRepository,
  });

  final NotificationRepository notificationRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final _scrollController = ScrollController();
  final List<WynNotification> _notifications = [];

  // Which notification ids were unread *at the moment this screen first
  // fetched them* -- used to render the unread highlight for the rest of
  // this screen's lifetime, deliberately not re-derived from
  // WynNotification.isRead after markAllAsRead() flips the DB rows.
  // Re-deriving it would make every highlight vanish the instant
  // mark-as-read succeeds, before the user has had a chance to see which
  // rows were actually new. See .wyn/docs/design/wyn-012-notification.md,
  // Screen 2 ("Mark-as-read timing").
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
        _hasMore = notifications.length == NotificationRepository.pageSize;
      });
      // Fire-and-forget: the badge on Home reads fresh from the DB next
      // time it's built, and this screen's own highlight intentionally
      // keeps using _unreadSnapshot regardless of this call's outcome.
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
        _hasMore = notifications.length == NotificationRepository.pageSize;
      });
    } catch (_) {
      // Silent: an infinite-scroll load-more failure doesn't need a
      // blocking error state -- scrolling again just retries it.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openNotification(WynNotification notification) async {
    switch (notification.type) {
      case NotificationType.likeDrop:
      case NotificationType.commentDrop:
        await _openDrop(notification.dropId!);
      case NotificationType.likePop:
      case NotificationType.commentPop:
        await _openPop(notification.popId!);
      case NotificationType.follow:
        _openProfile(notification.actorId);
    }
  }

  Future<void> _openDrop(String dropId) async {
    final drop = await widget.dropRepository.fetchById(dropId);
    if (!mounted) return;
    if (drop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Drop นี้ถูกลบไปแล้ว')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          dropRepository: widget.dropRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          drop: drop,
        ),
      ),
    );
  }

  Future<void> _openPop(String popId) async {
    final pop = await widget.popRepository.fetchById(popId);
    if (!mounted) return;
    if (pop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pop นี้ถูกลบไปแล้ว')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PopSingleClipScreen(
          pop: pop,
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          dropRepository: widget.dropRepository,
          savedRepository: widget.savedRepository,
        ),
      ),
    );
  }

  void _openProfile(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: userId,
        ),
      ),
    );
  }

  String _messageFor(WynNotification notification) {
    final name = notification.actorNameOrUsername;
    switch (notification.type) {
      case NotificationType.likeDrop:
        return '$name ถูกใจ Drop ของคุณ';
      case NotificationType.likePop:
        return '$name ถูกใจ Pop ของคุณ';
      case NotificationType.commentDrop:
        return '$name แสดงความคิดเห็นใน Drop ของคุณ';
      case NotificationType.commentPop:
        return '$name แสดงความคิดเห็นใน Pop ของคุณ';
      case NotificationType.follow:
        return '$name เริ่มติดตามคุณ';
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
            const SizedBox(height: 12),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none,
                size: 56,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              const Text('ยังไม่มีการแจ้งเตือน', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'เมื่อมีคนถูกใจ แสดงความคิดเห็น หรือติดตามคุณ จะเห็นที่นี่',
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
              padding: EdgeInsets.all(16),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      AvatarCircle(
                        imageUrl: notification.actorAvatarUrl,
                        fallbackText: notification.actorUsername,
                        radius: 20,
                      ),
                      const SizedBox(width: 12),
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

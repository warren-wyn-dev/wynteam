import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/conversation_screen.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../club/presentation/club_page.dart';
import '../../club/presentation/club_post_detail_screen.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_detail_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../follow/data/follow_request_repository.dart';
import '../../follow/presentation/follow_request_list_screen.dart';
import '../../home/presentation/pop_single_clip_screen.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../moderation/presentation/my_moderation_action_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../../saved/data/saved_repository.dart';
import '../../root/presentation/side_menu.dart';
import '../../search/presentation/search_screen.dart';
import '../../zoky/data/zoky_repository.dart';
import '../../zoky/presentation/zoky_order_detail_screen.dart';
import '../data/notification.dart';
import '../data/notification_repository.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/widgets/empty_state_block.dart';

/// Screen 2 — Notification list (WYN-012, extended by WYN-015 with 4
/// Club types). Row structure mirrors FollowListScreen (WYN-008/013)
/// exactly. See .wyn/docs/design/wyn-012-notification.md and
/// .wyn/docs/design/wyn-015-club-discovery-integration.md (Screen 3).
class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({
    super.key,
    required this.notificationRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.savedRepository,
    required this.clubRepository,
    required this.clubPostRepository,
    required this.zokyRepository,
    required this.appealRepository,
    required this.chatRepository,
    this.followRequestRepository,
  });

  final NotificationRepository notificationRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;
  final ZokyRepository zokyRepository;

  /// WYN-030: all 4 moderation-related notification types now open
  /// MyModerationActionScreen, which needs this to load the action +
  /// appeal status.
  final AppealRepository appealRepository;

  /// WYN-032: messageRequest opens ConversationScreen directly.
  final ChatRepository chatRepository;

  /// Optional/defaulted to Supabase.instance.client when omitted (see
  /// ViewProfileScreen's own comment on the pattern) -- WYN-039's
  /// followRequest opens FollowRequestListScreen directly.
  final FollowRequestRepository? followRequestRepository;

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  late final FollowRequestRepository _followRequestRepository =
      widget.followRequestRepository ??
          FollowRequestRepository(Supabase.instance.client);

  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
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

  // 02-notifications.tsx's "ทั้งหมด"/"การกล่าวถึง" tabs -- client-side
  // filter over the same [_notifications]/pagination state, same
  // "one shared list, tabs just filter/re-fetch it" pattern
  // home_feed_screen.dart's own feed-mode toggle uses. Never persisted --
  // resets to "ทั้งหมด" every time this screen is (re)built fresh, same
  // posture as Home's _feedMode.
  _NotificationTab _tab = _NotificationTab.all;

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
      final notifications =
          await widget.notificationRepository.fetchNotifications(page: 0);
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
      final notifications = await widget.notificationRepository
          .fetchNotifications(page: nextPage);
      setState(() {
        _notifications.addAll(notifications);
        _unreadSnapshot
            .addAll(notifications.where((n) => !n.isRead).map((n) => n.id));
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
        // Follow always has a real actor (notify_follow() always
        // supplies new.follower_id) -- actorId is only ever null for the
        // 2 moderation types (WYN-029 fix), neither of which reaches
        // this case.
        _openProfile(notification.actorId!);
      case NotificationType.clubJoinRequest:
        // Opens straight to the Members tab so the pending request is
        // immediately visible, not just the Club's Posts tab.
        _openClub(notification.clubId!, initialTabIndex: 1);
      case NotificationType.clubJoinApproved:
        _openClub(notification.clubId!, initialTabIndex: 0);
      case NotificationType.clubPostLike:
      case NotificationType.clubPostComment:
        await _openClubPost(notification.clubPostId!);
      case NotificationType.newOrder:
      case NotificationType.orderShipped:
      case NotificationType.orderCancelled:
      case NotificationType.orderRefunded:
        _openOrder(notification.orderId!);
      case NotificationType.mentionDrop:
        await _openDrop(notification.dropId!);
      case NotificationType.mentionClubPost:
        await _openClubPost(notification.clubPostId!);
      case NotificationType.redrop:
        // WYN-034/043: same destination as likeDrop/mentionDrop -- the
        // original Drop, using the same drop_id field they already use.
        await _openDrop(notification.dropId!);
      case NotificationType.moderationWarning:
      case NotificationType.moderationContentRemoved:
      case NotificationType.appealApproved:
      case NotificationType.appealRejected:
        // WYN-030: all 4 moderation-related types now open the same
        // destination (design doc's scope decision #2) -- but a
        // notification created before this migration has no
        // moderation_action_id at all, in which case this stays a
        // no-op (WYN-029, Screen 5's original behavior), same posture
        // as every other backward-compat case in this app.
        final actionId = notification.moderationActionId;
        if (actionId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MyModerationActionScreen(
              appealRepository: widget.appealRepository,
              actionId: actionId,
            ),
          ),
        );
      case NotificationType.messageRequest:
        // WYN-032: goes straight to ConversationScreen, not
        // MessageRequestListScreen -- the recipient already knows which
        // request this notification is about. A notification created
        // before this migration has no conversation_id, in which case
        // this stays a no-op, same backward-compat posture as the
        // moderation types above.
        final conversationId = notification.conversationId;
        final actorId = notification.actorId;
        if (conversationId == null || actorId == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ConversationScreen(
              chatRepository: widget.chatRepository,
              conversationId: conversationId,
              otherUserId: actorId,
              otherUsername: notification.actorUsername ?? '',
              otherDisplayName: notification.actorDisplayName,
              otherAvatarUrl: notification.actorAvatarUrl,
            ),
          ),
        );
      case NotificationType.followRequest:
        // WYN-039: goes straight to FollowRequestListScreen -- mirrors
        // messageRequest's own "the recipient already knows which
        // request this is about" reasoning, but unlike that type there
        // is no per-request destination to jump to directly (Accept/
        // Reject both live on the list screen itself, not a per-user
        // detail screen), so every followRequest notification opens the
        // same list.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FollowRequestListScreen(
              followRequestRepository: _followRequestRepository,
            ),
          ),
        );
      case NotificationType.followRequestAccepted:
        // The requester's own request was accepted -- opens the
        // accepter's profile, same destination `follow`'s own case
        // above uses.
        final actorId = notification.actorId;
        if (actorId == null) return;
        _openProfile(actorId);
      case NotificationType.system:
        // WYN-043: the announcement's full text is already shown in the
        // list itself (_messageFor reads `reason` in full) -- there's no
        // detail screen to jump to in this task's scope.
        return;
    }
  }

  void _openOrder(String orderId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZokyOrderDetailScreen(
          zokyRepository: widget.zokyRepository,
          orderId: orderId,
        ),
      ),
    );
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

  // 02-notifications.tsx's header search icon -- Search already has its
  // own bottom-nav tab (root_shell.dart), so this pushes the same
  // `SearchScreen` ViewProfileScreen/the ZOKY screens already reuse this
  // way, rather than inventing a second route to the same destination.
  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
        ),
      ),
    );
  }

  void _openClub(String clubId, {required int initialTabIndex}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPage(
          clubRepository: widget.clubRepository,
          clubPostRepository: widget.clubPostRepository,
          clubId: clubId,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  Future<void> _openClubPost(String clubPostId) async {
    final post = await widget.clubPostRepository.fetchById(clubPostId);
    if (!mounted) return;
    if (post == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โพสต์นี้ถูกลบไปแล้ว')),
      );
      return;
    }
    // myRole is unknown here without an extra lookup -- passing null
    // (no staff pin/delete rights shown) is safe since the notification
    // recipient is always the post's own author, who already gets the
    // "own post" delete option regardless of role. See ClubPostCard.
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubPostDetailScreen(
          clubPostRepository: widget.clubPostRepository,
          post: post,
          myRole: null,
        ),
      ),
    );
  }

  String _messageFor(WynNotification notification) {
    final name = notification.actorNameOrUsername;
    final club = notification.clubName ?? 'Club';
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
      case NotificationType.clubJoinRequest:
        return '$name ขอเข้าร่วม $club ของคุณ';
      case NotificationType.clubJoinApproved:
        return '$name อนุมัติคำขอเข้าร่วม $club ของคุณแล้ว';
      case NotificationType.clubPostLike:
        return '$name ถูกใจโพสต์ของคุณใน $club';
      case NotificationType.clubPostComment:
        return '$name แสดงความคิดเห็นในโพสต์ของคุณใน $club';
      case NotificationType.newOrder:
        final store = notification.orderStoreName ?? 'ร้านของคุณ';
        return '$name สั่งซื้อสินค้าจาก $store';
      case NotificationType.orderShipped:
        return 'คำสั่งซื้อของคุณจาก ${notification.orderStoreName ?? 'ร้านค้า'} ถูกจัดส่งแล้ว';
      case NotificationType.orderCancelled:
        // Bidirectional (see notify_order_cancelled in supabase/schema.sql
        // -- either the buyer or the seller can be the recipient here),
        // so this is deliberately worded to read correctly from either
        // side, unlike orderShipped/orderRefunded above which are always
        // buyer-recipient.
        return 'คำสั่งซื้อจากร้าน ${notification.orderStoreName ?? 'ร้านค้า'} ถูกยกเลิก';
      case NotificationType.orderRefunded:
        return 'คำสั่งซื้อของคุณจาก ${notification.orderStoreName ?? 'ร้านค้า'} ถูกคืนเงินแล้ว';
      case NotificationType.mentionDrop:
        return '$name กล่าวถึงคุณใน Drop';
      case NotificationType.mentionClubPost:
        return '$name กล่าวถึงคุณในโพสต์ที่ $club';
      case NotificationType.redrop:
        return '$name ReDrop โพสต์ของคุณ';
      case NotificationType.moderationWarning:
        return 'คุณได้รับคำเตือนจากทีมงาน WYN: ${notification.reason ?? ''}';
      case NotificationType.moderationContentRemoved:
        return 'เนื้อหาของคุณถูกลบเนื่องจากละเมิดกฎการใช้งาน WYN -- '
            'เหตุผล: ${notification.reason ?? ''}';
      case NotificationType.appealApproved:
        // WYN-030 Design, Screen 7 -- wording differs per action type,
        // and Remove Content's in particular is worded exactly as the
        // Product spec's Handoff requires: no word here may imply the
        // content itself came back, since it never can (hard-deleted,
        // no snapshot kept -- see supabase/schema.sql's
        // apply_moderation_action()).
        final actionType = notification.moderationActionType;
        return switch (actionType) {
          'warning' =>
            'อุทธรณ์ของคุณได้รับการอนุมัติแล้ว คำเตือนนี้ถูกลบออกจากประวัติบัญชีของคุณแล้ว',
          'restrict' =>
            'อุทธรณ์ของคุณได้รับการอนุมัติแล้ว สิทธิ์การโพสต์ของคุณกลับมาใช้งานได้ตามปกติแล้ว',
          'suspend' =>
            'อุทธรณ์ของคุณได้รับการอนุมัติแล้ว บัญชีของคุณกลับมาใช้งานได้ตามปกติแล้ว',
          'ban' =>
            'อุทธรณ์ของคุณได้รับการอนุมัติแล้ว บัญชีของคุณกลับมาใช้งานได้ตามปกติแล้ว คุณสามารถเข้าสู่ระบบได้ทันที',
          'remove_content' =>
            'อุทธรณ์ของคุณได้รับการอนุมัติแล้ว การละเมิดนี้ถูกลบออกจากประวัติบัญชีของคุณแล้ว',
          _ => 'อุทธรณ์ของคุณได้รับการอนุมัติแล้ว',
        };
      case NotificationType.appealRejected:
        // Reject has no action-type-specific outcome to describe (see
        // the design doc's Screen 7) -- same wording regardless of
        // what was appealed.
        return 'อุทธรณ์ของคุณถูกปฏิเสธ -- เหตุผล: ${notification.reason ?? ''}';
      case NotificationType.messageRequest:
        return '$name ส่งคำขอข้อความถึงคุณ';
      case NotificationType.followRequest:
        return '$name ขอติดตามคุณ';
      case NotificationType.followRequestAccepted:
        return '$name ยอมรับคำขอติดตามของคุณแล้ว';
      case NotificationType.system:
        // WYN-043: the admin's own message text, shown as-is -- unlike
        // moderationWarning/moderationContentRemoved above, there's no
        // fixed prefix here (the admin already writes the full message
        // themselves via send_system_notification()'s p_message).
        return notification.reason ?? 'มีประกาศจากระบบ WYN';
    }
  }

  /// WYN-029, Screen 5 (extended by WYN-030) -- the reviewer's real
  /// identity (`actor_id`) must never surface for any of these 4
  /// moderation-related types, same protection direction as WYN-026
  /// hiding a reporter's identity from everyone, including the person
  /// reported. Deliberately does NOT reuse [_messageFor]'s
  /// `actorNameOrUsername` for these types (see there).
  bool _hidesActorIdentity(NotificationType type) =>
      type == NotificationType.moderationWarning ||
      type == NotificationType.moderationContentRemoved ||
      type == NotificationType.appealApproved ||
      type == NotificationType.appealRejected ||
      // WYN-043: system notifications also have a null actor_id (an
      // admin action, not another user's) -- same no-avatar posture,
      // but a distinct icon (see _noActorIconFor) so users can tell
      // "moderation action on your account" apart from "a general
      // announcement" at a glance.
      type == NotificationType.system;

  /// The icon shown in place of an avatar for any type
  /// [_hidesActorIdentity] flags -- distinct per type rather than one
  /// icon for the whole bucket, so the 4 moderation/appeal types (an
  /// action taken on the recipient's own account) read differently
  /// from a WYN-043 system announcement (no action taken, just a
  /// message).
  IconData _noActorIconFor(NotificationType type) =>
      type == NotificationType.system
          ? Icons.campaign_outlined
          : Icons.shield_outlined;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: WynColors.paper,
      drawer: SideMenu(
        profileRepository: widget.profileRepository,
        followRepository: widget.followRepository,
        dropRepository: widget.dropRepository,
        popRepository: widget.popRepository,
        savedRepository: widget.savedRepository,
        clubRepository: widget.clubRepository,
        clubPostRepository: widget.clubPostRepository,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabs(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // 02-notifications.tsx header: hamburger (left) -- title (center) --
  // search (right). Custom Row instead of an AppBar, same reasoning
  // home_feed_screen.dart's own build() doc comment gives for its floating
  // chat icon: an AppBar claims fixed Column height no matter how compact,
  // and this screen (like Home) no longer has a use for one now that
  // Search/Notifications are their own Bottom Nav destinations.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(WynSpacing.space2,
          WynSpacing.space1, WynSpacing.space2, WynSpacing.space1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 10-side-menu.tsx's ☰ opens a real drawer (see SideMenu) now
          // that it's built.
          IconButton(
            icon: const Icon(Icons.menu, size: 20, color: WynColors.ink),
            tooltip: 'เมนู',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Text(
            'การแจ้งเตือน',
            style: WynTypography.screenTitle(
              fontSize: 24,
              color: WynColors.ink,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 19, color: WynColors.ink),
            tooltip: 'ค้นหา',
            onPressed: _openSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: WynColors.hairline)),
      ),
      child: Row(
        children: [
          _buildTab(_NotificationTab.all, 'ทั้งหมด'),
          const SizedBox(width: WynSpacing.space6),
          _buildTab(_NotificationTab.mentions, 'การกล่าวถึง'),
        ],
      ),
    );
  }

  Widget _buildTab(_NotificationTab tab, String label) {
    final active = _tab == tab;
    return InkWell(
      onTap: () => setState(() => _tab = tab),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: WynSpacing.space3),
              child: Text(
                label,
                style: _textStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? WynColors.ink : WynColors.mutedNeutral,
                ),
              ),
            ),
            Container(
              height: 2,
              color: active ? WynColors.sapphire : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  bool _isMentionType(WynNotification n) =>
      n.type == NotificationType.mentionDrop ||
      n.type == NotificationType.mentionClubPost;

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

    // "การกล่าวถึง" filters the same already-fetched [_notifications] list
    // rather than issuing a separate fetch -- same "one shared list, tab
    // just filters/re-fetches it" pattern home_feed_screen.dart's own
    // feed-mode toggle uses for its non-"จาก Club ของคุณ" modes.
    if (_tab == _NotificationTab.mentions) {
      final mentions = _notifications.where(_isMentionType).toList();
      if (mentions.isEmpty) {
        return _buildEmptyState(
          headline: 'ยังไม่มีใครกล่าวถึงคุณ',
          subtext: 'เวลามีคนพูดถึงคุณในโพสต์ จะขึ้นตรงนี้',
        );
      }
      // Not [_hasMore]-paginated on its own -- it's a filtered view over
      // whatever pages "ทั้งหมด" has already loaded, so neither a
      // load-more spinner nor the "no more" footer would be accurate here.
      return _buildList(mentions, paginated: false);
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState(
        headline: 'ยังไม่มีการแจ้งเตือน',
        subtext:
            'เมื่อมีคนถูกใจ แสดงความคิดเห็น ติดตามคุณ หรือมีความเคลื่อนไหวใน Club จะเห็นที่นี่',
      );
    }

    return _buildList(_notifications, paginated: true);
  }

  // 22-empty-states.tsx: icon-in-tint-circle + title-style headline +
  // supportive line, same shared shape the Chat Inbox's own empty state
  // uses.
  Widget _buildEmptyState({required String headline, required String subtext}) {
    return Center(
      child: EmptyStateBlock(
        icon: Icons.notifications_outlined,
        title: headline,
        subtitle: subtext,
      ),
    );
  }

  // Groups [items] by day (วันนี้/เมื่อวานนี้/เก่ากว่านี้), then within each
  // day collapses same-type-same-target rows into one [_NotificationGroup]
  // (Founder-approved client-side behavior, 2026-08-29 -- see
  // .wyn/company/DECISIONS.md). Returns a flat list mixing `String` section
  // labels and [_NotificationGroup]s, in display order, so [_buildList]
  // can render it with one `ListView.builder` instead of a nested one.
  List<Object> _buildSections(List<WynNotification> items) {
    final now = DateTime.now();
    final byBucket = <_DayBucket, List<WynNotification>>{};
    for (final n in items) {
      byBucket.putIfAbsent(_bucketFor(n.createdAt, now), () => []).add(n);
    }

    final sections = <Object>[];
    for (final bucket in _DayBucket.values) {
      final bucketItems = byBucket[bucket];
      if (bucketItems == null || bucketItems.isEmpty) continue;
      sections.add(_bucketLabel(bucket));
      sections.addAll(_groupWithinDay(bucketItems));
    }
    return sections;
  }

  Widget _buildList(List<WynNotification> items, {required bool paginated}) {
    final sections = _buildSections(items);
    final showSpinner = paginated && _hasMore;
    final showFooter = paginated && !_hasMore;
    final trailingCount = (showSpinner || showFooter) ? 1 : 0;

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: sections.length + trailingCount,
        itemBuilder: (context, index) {
          if (index < sections.length) {
            final section = sections[index];
            return section is String
                ? _GroupLabel(label: section)
                : _buildGroupRow(section as _NotificationGroup);
          }
          if (showSpinner) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          // 02-notifications.tsx's static end-of-list footer -- shown only
          // once pagination is truly exhausted, never mid-load.
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: WynSpacing.space4, vertical: WynSpacing.space8),
            child: Center(
              child: Text(
                'ไม่มีการแจ้งเตือนเพิ่มเติมแล้ว',
                style: _textStyle(fontSize: 13, color: WynColors.faint),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupRow(_NotificationGroup group) {
    final n = group.head;
    final isUnread = group.items.any((item) => _unreadSnapshot.contains(item.id));
    final time = relativeTimeLabel(n.createdAt, now: DateTime.now());
    final message = _messageFor(n);

    return Semantics(
      label: '$message $time${isUnread ? ' ยังไม่ได้อ่าน' : ''}',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _openNotification(n),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(n),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMessage(n, message, group.extraActorCount),
                    if (n.contentPreview != null &&
                        n.contentPreview!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '“${n.contentPreview}”',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _textStyle(fontSize: 13, color: WynColors.graphite),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: _textStyle(fontSize: 13, color: WynColors.faint),
                    ),
                  ],
                ),
              ),
              if (isUnread)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: WynSpacing.space2),
                  child: _UnreadDot(key: Key('notification_unread_dot')),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Avatar (with SPEC.md's sapphire ring) plus a small type-icon badge
  // anchored on it (02-notifications.tsx's TypeBadge) -- types outside
  // [_badgeFor]'s mapping (orders, club, moderation, mentions, message/
  // follow requests) get no badge, same as the reference's own scope.
  Widget _buildAvatar(WynNotification n) {
    final avatar = _hidesActorIdentity(n.type)
        ? CircleAvatar(
            radius: 20,
            backgroundColor: WynColors.hairline,
            child: Icon(_noActorIconFor(n.type), color: WynColors.graphite),
          )
        : AvatarCircle(
            imageUrl: n.actorAvatarUrl,
            // actorUsername is only ever null for the 2 hidden-identity
            // moderation types, which never reach this branch -- the ''
            // fallback is just to satisfy the now-nullable type (WYN-029
            // fix).
            fallbackText: n.actorUsername ?? '',
            radius: 20,
            ring: true,
          );

    final badge = _badgeFor(n.type);
    if (badge == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          bottom: -2,
          right: -2,
          child: Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: badge.color,
              border: const Border.fromBorderSide(
                BorderSide(color: WynColors.paper, width: 1.5),
              ),
            ),
            child: Icon(badge.icon, size: 10, color: WynColors.paper),
          ),
        ),
      ],
    );
  }

  // Bolds the actor name inside [message] (every [_messageFor] string that
  // has a real actor starts with `actorNameOrUsername`, e.g. "$name ถูกใจ
  // ... ของคุณ") and appends "และอีก N คน" when [group]'s row collapsed
  // more than one distinct actor -- 02-notifications.tsx's own pattern.
  Widget _buildMessage(WynNotification n, String message, int extraActorCount) {
    final name = n.actorNameOrUsername;
    final baseStyle = _textStyle(fontSize: 15, color: _kMessageBodyColor);
    final nameStyle =
        _textStyle(fontSize: 15, fontWeight: FontWeight.w600, color: WynColors.ink);
    final extraStyle = _textStyle(fontSize: 15, color: WynColors.graphite);

    final spans = <InlineSpan>[];
    if (name.isNotEmpty && message.startsWith(name)) {
      spans.add(TextSpan(text: name, style: nameStyle));
      spans.add(TextSpan(text: message.substring(name.length), style: baseStyle));
    } else {
      spans.add(TextSpan(text: message, style: baseStyle));
    }
    if (extraActorCount > 0) {
      spans.add(TextSpan(text: ' และอีก $extraActorCount คน', style: extraStyle));
    }
    return Text.rich(TextSpan(children: spans));
  }
}

// 02-notifications.tsx's two-tab split (All / Mentions).
enum _NotificationTab { all, mentions }

// 02-notifications.tsx groups notifications by recency instead of one
// unbroken list -- "เก่ากว่านี้" is this app's own addition (the reference
// mock only ever has data for today/yesterday) so real accounts with older
// history still get a bucket instead of items falling off the labeled
// list entirely.
enum _DayBucket { today, yesterday, older }

_DayBucket _bucketFor(DateTime createdAt, DateTime now) {
  final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return _DayBucket.today;
  if (diff == 1) return _DayBucket.yesterday;
  return _DayBucket.older;
}

String _bucketLabel(_DayBucket bucket) => switch (bucket) {
      _DayBucket.today => 'วันนี้',
      _DayBucket.yesterday => 'เมื่อวานนี้',
      _DayBucket.older => 'เก่ากว่านี้',
    };

// Types 02-notifications.tsx's "รวมแจ้งเตือนประเภทเดียวกัน จากคนละคน บน
// เป้าหมายเดียวกัน เป็นแถวเดียว" behavior applies to -- the "social,
// multi-actor-capable" types the reference's own like/comment/repost/
// follow examples cover. Order/club/moderation/mention/message-request/
// follow-request/system notifications keep one row per event: grouping
// them either has no natural "and N others" reading (a moderation action,
// a system announcement) or would hide information a single recipient
// needs to act on individually (an order, a club join request).
const _groupableTypes = {
  NotificationType.likeDrop,
  NotificationType.likePop,
  NotificationType.commentDrop,
  NotificationType.commentPop,
  NotificationType.redrop,
  NotificationType.follow,
};

/// Null for a type [_groupableTypes] excludes. For a groupable type, the
/// key is type + target (dropId/popId, empty for `follow` which has none)
/// -- multiple different actors on the same key within the same day
/// collapse into one [_NotificationGroup].
String? _groupKeyFor(WynNotification n) {
  if (!_groupableTypes.contains(n.type)) return null;
  final target = n.dropId ?? n.popId ?? '';
  return '${n.type}:$target';
}

List<_NotificationGroup> _groupWithinDay(List<WynNotification> items) {
  final groups = <_NotificationGroup>[];
  final indexByKey = <String, int>{};
  for (final n in items) {
    final key = _groupKeyFor(n);
    if (key == null) {
      groups.add(_NotificationGroup([n]));
      continue;
    }
    final existingIndex = indexByKey[key];
    if (existingIndex == null) {
      indexByKey[key] = groups.length;
      groups.add(_NotificationGroup([n]));
    } else {
      groups[existingIndex].items.add(n);
    }
  }
  return groups;
}

/// One or more [WynNotification]s collapsed into a single displayed row.
/// [items] stays newest-first, same order [head] and [extraActorCount]
/// rely on.
class _NotificationGroup {
  _NotificationGroup(List<WynNotification> initial) : items = List.of(initial);

  final List<WynNotification> items;

  WynNotification get head => items.first;

  /// Distinct actors among the collapsed rows *other than* [head]'s --
  /// deliberately de-duplicated by actorId so the same person appearing
  /// twice (e.g. unliked then re-liked) never inflates the "และอีก N คน"
  /// count.
  int get extraActorCount => items
      .skip(1)
      .map((n) => n.actorId)
      .whereType<String>()
      .toSet()
      .length;
}

class _TypeBadge {
  const _TypeBadge(this.icon, this.color);
  final IconData icon;
  final Color color;
}

// 02-notifications.tsx's TYPE_META -- like/follow use sapphire (the app's
// one real accent), comment/repost use the 2 Founder-approved exception
// colors scoped to this 18px badge only (see WynColors.notificationBadge*
// and .wyn/company/DECISIONS.md, 2026-08-29).
_TypeBadge? _badgeFor(NotificationType type) {
  switch (type) {
    case NotificationType.likeDrop:
    case NotificationType.likePop:
    case NotificationType.clubPostLike:
      // Matches the red heart every like button elsewhere in the app
      // uses (home_drop_card.dart etc.) -- was sapphire (the same
      // accent color as the follow badge below), inconsistent with the
      // rest of the app's own "like = red" convention. Founder request,
      // 2026-08-30.
      return const _TypeBadge(Icons.favorite, Colors.red);
    case NotificationType.commentDrop:
    case NotificationType.commentPop:
    case NotificationType.clubPostComment:
      return const _TypeBadge(
          Icons.chat_bubble, WynColors.notificationBadgeComment);
    case NotificationType.redrop:
      return const _TypeBadge(
          Icons.repeat, WynColors.notificationBadgeRepost);
    case NotificationType.follow:
    case NotificationType.followRequestAccepted:
      return const _TypeBadge(Icons.person_add, WynColors.sapphire);
    default:
      return null;
  }
}

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
}) =>
    TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);

// 02-notifications.tsx's message-body tone -- ink/faint-adjacent, not one
// of SPEC.md's Section 1 tokens, same "quieter than the nearest named
// token" pattern SPEC.md's own Section 4.10 sanctions for Home's reply-
// preview text (`#5A5850`, "deliberately not full graphite and not full
// ink"). Kept as a literal, file-scoped constant rather than promoted to
// WynColors -- a one-off in-between tone specific to this row, not a
// reusable system token (unlike WynColors.mutedNeutral, `#B7B4AC`, which
// this file's tab/GroupLabel styling below uses -- that one repeats
// identically across multiple reference screens, see its own doc
// comment).
const Color _kMessageBodyColor = Color(0xFF2B2A26);

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(WynSpacing.space4,
          WynSpacing.space5, WynSpacing.space4, WynSpacing.space1),
      child: Text(
        label,
        style: _textStyle(fontSize: 13, fontWeight: FontWeight.w600, color: WynColors.mutedNeutral)
            .copyWith(letterSpacing: 13 * 0.12),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: WynColors.sapphire,
        shape: BoxShape.circle,
      ),
    );
  }
}

import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/interaction/wyn_feedback.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../drop/data/drop_repository.dart';
import '../../follow/data/follow_repository.dart';
import '../../follow/data/follow_request_repository.dart';
import '../../follow/presentation/follow_list_screen.dart';
import '../../follow/presentation/follow_request_list_screen.dart';
import '../../home/data/home_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../../saved/presentation/bookmarks_screen.dart';
import '../data/profile.dart';
import '../data/profile_repository.dart';
import 'edit_profile_screen.dart';
import 'widgets/wynos_founder_profile_header.dart';
import 'widgets/profile_drop_grid_tab.dart';
// Pop is hidden from Profile for WYNOS V1.0.0 Beta (Product spec
// requirement 3) -- the Pop system itself (ProfilePopGridTab,
// PopRepository, the pop_* DB tables) is untouched and stays in the
// codebase, just no longer wired up on this screen. See
// .wyn/company/DECISIONS.md, 2026-08-14/2026-08-22 (Pop already
// unmounted from RootShell's Bottom Nav the same way, for V3).
// ProfileRepliesTab (Replies tab) is similarly untouched but no longer
// wired up here -- 05-profile.tsx cuts it down to 3 tabs, see the
// TabBar/TabBarView below.
import 'widgets/profile_likes_tab.dart';
import 'widgets/profile_recommendation_section.dart';
import 'widgets/profile_redrops_tab.dart';
import 'widgets/profile_refresh_coordinator.dart';
import 'widgets/suggested_follow_sheet.dart';
import 'widgets/privacy_notice_banner.dart';
import 'widgets/profile_skeleton.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wynos_founder_metrics.dart';
import '../../../core/widgets/action_sheet_row.dart';
import '../../account_switcher/presentation/account_switcher_sheet.dart';
import '../../auth/presentation/widgets/guest_gate.dart';
import '../../block/data/block_relationship.dart';
import '../../block/data/block_repository.dart';
import '../../block/presentation/block_dialogs.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/shared_content_type.dart';
import '../../chat/presentation/conversation_screen.dart';
import '../../chat/presentation/share_sheet.dart';
import '../../mute/data/mute_repository.dart';
import '../../report/data/report_repository.dart';
import '../../report/data/report_target_type.dart';
import '../../report/presentation/report_sheet.dart';
import '../../root/presentation/root_navigation_controller.dart';
import '../../root/presentation/widgets/wynos_founder_bottom_navigation.dart';
import '../../search/data/discovery_repository.dart';
import '../../search/presentation/search_screen.dart';
import '../../settings/presentation/settings_screen.dart';

/// WYN-114 (Tier 1, done + deployed 2026-09-06): real wynos.online
/// domain + a Vercel SPA rewrite so this path no longer 404s at the
/// hosting layer -- see .wyn/tasks/completed/WYN-114-share-link-real-domain.md.
/// WYN-119 (Tier 2, partial): DeepLinkService (app/lib/core/navigation/)
/// now opens this destination directly, but only once RootShell has
/// already mounted -- a guest who has never signed in still lands on
/// Welcome first, not this content. WYN-119's own guest-preview
/// requirement is not met yet; see that task's Known Follow-up.
String profileShareLink(String username) => 'https://wynos.online/@$username';

/// Beta4 §1: "Profile Stats -- แสดงเฉพาะ Following / Followers.
/// ไม่เพิ่ม: จำนวนโพสต์". `dropCount` is gone from this record, and with
/// it the `countByAuthor` round trip [_load] used to make -- the post
/// count was a third stat squeezed into a row that now has room to
/// breathe, and it duplicated what the "โพสต์" tab below already shows
/// by simply being full or empty. [DropRepository.countByAuthor] itself
/// is untouched and still used elsewhere.
typedef _ProfileWithCounts = ({
  Profile profile,
  int followerCount,
  int followingCount,
});

/// Screen 1 — View Profile. Doubles as both personas WYN-013 needs (the
/// current user's own profile, or someone else's) rather than being two
/// separate screens -- only the header actions/tab count differ. See
/// .wyn/docs/design/wyn-003-user-profile.md, wyn-008-follow.md (Screen 4),
/// wyn-013-profile-v2.md (Screen 1-2).
class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({
    super.key,
    required this.profileRepository,
    required this.followRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.savedRepository,
    required this.userId,
    this.clubRepository,
    this.clubPostRepository,
    this.reportRepository,
    this.blockRepository,
    this.muteRepository,
    this.chatRepository,
    this.homeRepository,
    this.followRequestRepository,
    this.onRootBack,
  });

  final ProfileRepository profileRepository;
  final FollowRepository followRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final String userId;

  // Optional (unlike every other repository here): 05-profile.tsx
  // removed the "Club ของฉัน" shelf this screen used to render (still
  // reachable via Home's "From Your Clubs" feed) -- kept only so
  // _openSearch can still hand a real ClubRepository/ClubPostRepository
  // to the screen it pushes, rather than every call site of *this*
  // screen needing to supply one just for that.
  final ClubRepository? clubRepository;
  final ClubPostRepository? clubPostRepository;

  // Optional and defaulted to Supabase.instance.client when omitted
  // (see the State's _reportRepository/_blockRepository/_muteRepository
  // getters below) -- these three used to be hardcoded directly in the
  // State, unlike every repository above, which meant the More menu's
  // "รายงาน"/"บล็อก"/"ปิดเสียง" items (and the Blocked persona banner)
  // had no way to be exercised by a widget test: WYN-027 QA found this
  // gap and flagged it as a fast-follow (see .wyn/company/DECISIONS.md,
  // WYN-027 QA round 1). Fixed here while adding WYN-028's own
  // muteRepository to the same three-repository hardcoding, rather than
  // compounding the same gap a third time.
  final ReportRepository? reportRepository;
  final BlockRepository? blockRepository;
  final MuteRepository? muteRepository;

  // Same optional/defaulted shape as the 3 above -- WYN-031's
  // "ส่งข้อความ" entry point.
  final ChatRepository? chatRepository;

  // Same optional/defaulted shape again -- WYN-034's "ReDrops" tab
  // (Screen 4), the only place on this screen that reads `home_feed`
  // rather than `drops` directly.
  final HomeRepository? homeRepository;

  // Same optional/defaulted shape again -- WYN-039's Follow Request flow
  // (Locked persona's button + own-profile badge into
  // FollowRequestListScreen).
  final FollowRequestRepository? followRequestRepository;

  /// RootShell supplies this so the Founder-approved back affordance on
  /// the own-profile root returns to Home instead of becoming a dead icon.
  final VoidCallback? onRootBack;

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  late Future<_ProfileWithCounts> _loadFuture;
  final ProfileRefreshCoordinator _refreshCoordinator =
      ProfileRefreshCoordinator();
  bool _isProfileRefreshInFlight = false;

  // Whether the *current viewer* follows this profile's owner -- null
  // until the real status has loaded. Only relevant (and only loaded)
  // when this isn't the viewer's own profile. See
  // DropDetailScreen._isFollowing (WYN-008) for why this stays hidden
  // rather than defaulting to false.
  bool? _isFollowing;

  // Null until loaded (only for other people's profiles, same as
  // _isFollowing) -- WYN-027's Blocked persona (Design Screen 3) reads
  // this to decide whether to show the Follow button/counts at all or
  // replace them with a banner, and the More menu (Screen 1) reads it
  // to decide whether "บล็อก" belongs in the list.
  BlockRelationship? _blockRelationship;

  // Null until loaded (only for other people's profiles) -- WYN-028's
  // More menu toggle (Design Screen 1) reads this to decide whether to
  // show "ปิดเสียง" or "เปิดเสียง", and stays hidden while null so the
  // label can never show the wrong action, same posture as
  // _blockRelationship above.
  bool? _isMuted;

  late final ReportRepository _reportRepository =
      widget.reportRepository ?? ReportRepository(Supabase.instance.client);
  late final BlockRepository _blockRepository =
      widget.blockRepository ?? BlockRepository(Supabase.instance.client);
  late final MuteRepository _muteRepository =
      widget.muteRepository ?? MuteRepository(Supabase.instance.client);
  late final ChatRepository _chatRepository =
      widget.chatRepository ?? ChatRepository(Supabase.instance.client);
  late final HomeRepository _homeRepository =
      widget.homeRepository ?? HomeRepository(Supabase.instance.client);
  late final FollowRequestRepository _followRequestRepository =
      widget.followRequestRepository ??
          FollowRequestRepository(Supabase.instance.client);

  // WYN-071 Screen 5 -- same optional/defaulted shape as every other
  // repository above. Built fresh (not threaded through the
  // constructor) since only this screen's Recommendation Section uses
  // it here.
  late final DiscoveryRepository _discoveryRepository = DiscoveryRepository(
    Supabase.instance.client,
    homeRepository: _homeRepository,
    profileRepository: widget.profileRepository,
  );

  // Null until loaded (only for other people's profiles, same posture as
  // _isFollowing) -- true only while the *current viewer* has an
  // outstanding, undecided Follow Request against this Private profile.
  // Drives the Follow button's 3rd state ("ขอติดตามแล้ว").
  bool? _hasPendingRequest;
  bool _isFollowActionInFlight = false;

  // Only meaningful for the viewer's own profile -- how many people are
  // waiting on a Follow Request decision. Drives the badge entry point
  // into FollowRequestListScreen (Design Screen 3). 0 renders no badge
  // at all.
  int _pendingRequestCount = 0;

  bool _isStartingChat = false;

  bool get _isOwnProfile =>
      widget.userId == Supabase.instance.client.auth.currentUser!.id;

  /// WYNOS Unified Home Feed Algorithm V1.0 -- best-effort "Profile
  /// Visit" User Signal, only for someone else's profile (the guard at
  /// this method's own call site already ensures that; there's no
  /// further self-visit check needed here, unlike record_drop_view()'s
  /// server-side one -- see HomeRepository.recordProfileVisit's own
  /// doc comment for why). Silent on failure, same posture as every
  /// other best-effort background fetch on this screen (e.g.
  /// _loadFollowStatus) -- a missed personalization signal is never
  /// worth a blocking error for a screen the user is just browsing.
  Future<void> _recordProfileVisit() async {
    try {
      await _homeRepository.recordProfileVisit(widget.userId);
    } catch (_) {
      // Silent -- see doc comment above.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
    if (!_isOwnProfile) {
      _loadFollowStatus();
      _loadBlockRelationship();
      _loadMuteStatus();
      _loadPendingRequestStatus();
      _recordProfileVisit();
    } else {
      _loadPendingRequestCount();
    }
  }

  // Profile and Follower/Following counts are loaded together as one
  // future so there's a single loading state, not counts appearing in a
  // separate flicker after the profile itself. See
  // .wyn/docs/design/wyn-008-follow.md, Screen 4.
  // Issued together, not one after another: none of the four depends on
  // another's result, so awaiting them in sequence just multiplied the
  // screen's time-to-first-paint by four round-trips (~800ms instead of
  // ~200ms on a 200ms-RTT mobile connection). Future.wait still fails
  // the whole future if any one call throws, so the single combined
  // loading/error state this screen is built around is unchanged.
  Future<_ProfileWithCounts> _load() async {
    final results = await Future.wait([
      widget.profileRepository.fetchProfile(widget.userId),
      widget.followRepository.countFollowers(userId: widget.userId),
      widget.followRepository.countFollowing(userId: widget.userId),
    ]);
    return (
      profile: results[0] as Profile,
      followerCount: results[1] as int,
      followingCount: results[2] as int,
    );
  }

  void _reload() {
    // Block body, not `() => _loadFuture = _load()` -- an assignment
    // expression evaluates to the assigned value, so an arrow body here
    // would make this closure literally return the Future, which trips
    // setState()'s own "did you accidentally do async work in here?"
    // debug assertion the instant this runs inside one (found via
    // WYN-081, which made this method reachable from a RefreshIndicator
    // pull for the first time -- see the 3 profile tabs'
    // onRefreshHeader).
    setState(() {
      _loadFuture = _load();
    });
  }

  /// One pull gesture refreshes Profile as one surface: header, counts,
  /// relationship state and every mounted profile-tab data source. The tab
  /// widgets suppress their own RefreshIndicator while coordinated here, so
  /// the user sees exactly one spinner and one completion point.
  Future<void> _refreshWholeProfile() async {
    if (_isProfileRefreshInFlight) return;
    _isProfileRefreshInFlight = true;

    try {
      // Keep the current Profile visible while refreshing. Swapping the
      // FutureBuilder back to a loading Future would flash the skeleton and
      // make one pull gesture look like two independent refresh operations.
      final freshDataFuture = _load();
      final secondaryRefreshes = <Future<void>>[
        _refreshCoordinator.refreshAll(),
      ];
      if (_isOwnProfile) {
        secondaryRefreshes.add(_loadPendingRequestCount());
      } else {
        secondaryRefreshes.addAll([
          _loadFollowStatus(),
          _loadBlockRelationship(),
          _loadMuteStatus(),
          _loadPendingRequestStatus(),
        ]);
      }

      final freshData = await freshDataFuture;
      await Future.wait(secondaryRefreshes);
      if (!mounted) return;
      setState(() => _loadFuture = Future.value(freshData));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: BrowserSystemText('รีเฟรชโปรไฟล์ไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      _isProfileRefreshInFlight = false;
    }
  }

  Future<void> _loadFollowStatus() async {
    try {
      final isFollowing = await widget.followRepository.isFollowing(
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() => _isFollowing = isFollowing);
    } catch (_) {
      // Leave _isFollowing null -- the button stays hidden rather than
      // showing a possibly-wrong state.
    }
  }

  Future<void> _toggleFollow() async {
    final previous = _isFollowing;
    if (previous == null) return;
    setState(() => _isFollowing = !previous);
    WynFeedback.follow();
    try {
      await widget.followRepository.toggleFollow(
        userId: widget.userId,
        currentlyFollowing: previous,
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFollowing = previous);
    }
  }

  // WYN-039 Design, Screen 2 -- the Follow button's 3 states. Only
  // reached once _isFollowing is non-null (the caller above already
  // guards that), so this never has to represent a 4th "still loading"
  // state itself.
  String _followButtonLabel(Profile profile) {
    if (_isFollowing!) return 'กำลังติดตาม';
    if (profile.isPrivate && (_hasPendingRequest ?? false)) {
      return 'ขอติดตามแล้ว';
    }
    return 'ติดตาม';
  }

  Future<void> _onFollowButtonPressed(Profile profile) async {
    // WYN-072 Guest Browsing: viewing a shared profile is allowed, but
    // Follow/Follow Request requires a permanent account. Gate before
    // any optimistic UI state change or write occurs.
    if (!await requireRealAccount(context) || !mounted) return;

    if (_isFollowing!) {
      _toggleFollow();
    } else if (profile.isPrivate && (_hasPendingRequest ?? false)) {
      _cancelFollowRequest(profile);
    } else if (profile.isPrivate) {
      _sendFollowRequest();
    } else {
      _toggleFollow();
    }
  }

  Future<void> _loadPendingRequestStatus() async {
    try {
      final hasPending = await _followRequestRepository.hasPendingRequest(
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() => _hasPendingRequest = hasPending);
    } catch (_) {
      // Leave it null -- same posture as _loadFollowStatus.
    }
  }

  Future<void> _loadPendingRequestCount() async {
    try {
      final count = await _followRequestRepository.countPendingRequests();
      if (!mounted) return;
      setState(() => _pendingRequestCount = count);
    } catch (_) {
      // Leave it at 0 -- the badge just stays hidden, same posture as
      // every other best-effort count on this screen.
    }
  }

  // WYN-039 Design, Screen 2 -- sends a Follow Request instead of an
  // instant follow when the target is Private and not yet followed.
  // Optimistic, no confirm dialog (mirrors _toggleFollow's own posture
  // for the same reason: fully reversible, one tap to undo via
  // _cancelFollowRequest below).
  Future<void> _sendFollowRequest() async {
    if (_isFollowActionInFlight) return;
    setState(() {
      _isFollowActionInFlight = true;
      _hasPendingRequest = true;
    });
    try {
      await _followRequestRepository.sendRequest(userId: widget.userId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasPendingRequest = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: BrowserSystemText('ส่งคำขอติดตามไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isFollowActionInFlight = false);
    }
  }

  // Confirm before canceling (unlike sending) -- the Design doc calls
  // this out explicitly since it's the one Follow-adjacent action on
  // this screen with a confirm dialog, mirroring _blockUser's posture
  // rather than _toggleFollow's: undoing a decision already communicated
  // to the other party is worth one extra tap to avoid an accidental
  // cancel.
  Future<void> _cancelFollowRequest(Profile profile) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: BrowserSystemText('ยกเลิกคำขอติดตาม ${profile.nameOrUsername}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const BrowserSystemText('ไม่ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const BrowserSystemText('ยกเลิกคำขอ'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || _isFollowActionInFlight) return;

    setState(() {
      _isFollowActionInFlight = true;
      _hasPendingRequest = false;
    });
    try {
      await _followRequestRepository.cancelRequest(userId: widget.userId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasPendingRequest = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: BrowserSystemText('ยกเลิกคำขอไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isFollowActionInFlight = false);
    }
  }

  // WYN-071 Design, Screen 8 -- built fresh here rather than threaded
  // through this screen's constructor, same optional/defaulted pattern
  // already used above for _reportRepository/_blockRepository/etc. --
  // every call site of ViewProfileScreen would otherwise need to grow
  // these params just to support a shortcut icon two people out of many
  // call sites will ever use.
  //
  // WYN-085 (Wynos V1.0.0 Beta2, item 23): this used to have a sibling
  // _openNotifications() pushing NotificationListScreen next to this
  // one, with its own AppBar-less bell IconButton in actions[] below.
  // NotificationListScreen (02-notifications.tsx) has no back button of
  // its own -- it was designed only as a Bottom Nav root destination,
  // with a hamburger-drawer header instead of an AppBar, relying on the
  // Bottom Nav for onward navigation. This screen (when viewing someone
  // else's profile, i.e. exactly where that bell IconButton lived) is
  // itself pushed on top of another stack and hides the Bottom Nav, so
  // pushing NotificationListScreen from here stranded the viewer on a
  // screen with no way back out -- Founder: "หน้าโปรไฟล์คนอื่น มีปุ่ม
  // แจ้งเตือนได้ไง กดแล้ว ออกไปหน้าอื่นก็ไม่ได้". Removed entirely
  // rather than given a back button, since a bell shortcut pointing at
  // *your own* notifications never belonged on someone else's profile
  // in the first place.

  Future<void> _openSuggestedFollowers() async {
    await showSuggestedFollowSheet(
      context,
      discoveryRepository: _discoveryRepository,
      followRepository: widget.followRepository,
      followRequestRepository: _followRequestRepository,
      excludeUserId: widget.userId,
      onShowAll: _openSearch,
    );

    // A Follow action in the sheet can change this profile's Following count.
    // Resync via the same whole-page refresh path instead of independently
    // mutating only that number.
    if (mounted) await _refreshWholeProfile();
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          clubRepository:
              widget.clubRepository ?? ClubRepository(Supabase.instance.client),
          clubPostRepository: widget.clubPostRepository ??
              ClubPostRepository(Supabase.instance.client),
          autofocus: true,
        ),
      ),
    );
  }

  /// Beta4 §2: the account switcher, opened from the "ชื่อที่แสดง ⌄"
  /// control on your own profile.
  ///
  /// The switcher sheet itself is unchanged (WYN's existing
  /// [showAccountSwitcherSheet] -- add/switch/remove, up to 5 accounts
  /// per device, Keychain-backed refresh tokens). What changes is where
  /// it is reachable from: until now its only entry point was Settings
  /// → บัญชี → สลับบัญชี, three taps deep in a screen about
  /// preferences, when the thing being switched is the identity written
  /// across the top of this very screen. The chevron sits on the name
  /// because the name is what changes.
  ///
  /// Own profile only. [_isOwnProfile] gates the call site, so a pushed
  /// view of someone else's profile can never reach this -- offering
  /// "switch account" under *their* name would read as an action on
  /// them.
  void _openSaved() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookmarksScreen(
          savedRepository: widget.savedRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
        ),
      ),
    );
  }

  Future<void> _shareProfile(Profile profile) {
    return showShareSheet(
      context,
      chatRepository: _chatRepository,
      profileRepository: widget.profileRepository,
      sharedContentType: SharedContentType.profile,
      sharedContentId: widget.userId,
      previewLabel: 'แชร์โปรไฟล์ @${profile.username}',
      nativeShareText: profileShareLink(profile.username),
      nativeShareTitle: profile.displayName ?? '@${profile.username}',
    );
  }

  Future<void> _openSettings(Profile profile) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          platformRole: profile.platformRole,
          isPrivate: profile.isPrivate,
          dmPermission: profile.dmPermission,
          mentionPermission: profile.mentionPermission,
          commentPermission: profile.commentPermission,
          likesVisibility: profile.likesVisibility,
        ),
      ),
    );
    if (mounted) _reload();
  }

  void _goBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      widget.onRootBack?.call();
    }
  }

  Future<void> _openRootDestination(int navIndex) async {
    if (!RootNavigationController.isAttached) return;

    // A pushed profile sits above RootShell on the app's single Navigator.
    // Switching a bottom destination should leave that pushed stack entirely,
    // reveal the existing RootShell (preserving its IndexedStack state), then
    // let RootShell perform the real destination action/guest gate.
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    await Future<void>.delayed(Duration.zero);
    await RootNavigationController.selectDestination(navIndex);
  }

  Widget _buildPushedProfileBottomNavigation() {
    return WynosFounderBottomNavigation(
      selectedIndex: 4,
      onDestinationSelected: (navIndex) {
        _openRootDestination(navIndex);
      },
      createAction: Container(
        width: WynosFounderMetrics.createActionDiameter,
        height: WynosFounderMetrics.createActionDiameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: WynColors.ink,
          boxShadow: [
            BoxShadow(
              color: WynColors.ink.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 33,
          color: WynColors.paper,
        ),
      ),
      notificationIcon: const Icon(Icons.notifications_outlined),
      selectedNotificationIcon: const Icon(Icons.notifications),
    );
  }

  Widget _buildProfileCoverBar(Profile profile, bool isOwnProfile) {
    // The cover and the identity header must live in the same sliver.
    // The avatar intentionally paints 46px upward into this cover; keeping
    // the cover in a separate SliverAppBar clips that overflow at the sliver
    // boundary on real iOS/Web renderers even when the inner Stack uses
    // Clip.none. This fixed-height cover bar preserves the exact visual
    // height/controls while allowing the parent SliverToBoxAdapter to own
    // both paint regions.
    final topInset = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: topInset + WynosFounderMetrics.profileCoverExpandedHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          WynosProfileCover(imageUrl: profile.coverUrl),
          Positioned(
            top: topInset,
            left: 4,
            right: 0,
            height: kToolbarHeight,
            child: Row(
              children: [
                BrowserSystemTooltip(message: 'ย้อนกลับ', child: IconButton(
                  tooltip: null,
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    size: 32,
                    color: WynColors.paper,
                  ),
                  onPressed: _goBack,
                )),
                const BrowserSystemText(
                  'โปรไฟล์',
                  style: TextStyle(
                    color: WynColors.paper,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (isOwnProfile) ...[
                  BrowserSystemTooltip(message: 'แชร์โปรไฟล์', child: IconButton(
                    tooltip: null,
                    icon: const Icon(
                      Icons.ios_share_outlined,
                      size: 24,
                      color: WynColors.paper,
                    ),
                    onPressed: () => _shareProfile(profile),
                  )),
                  BrowserSystemTooltip(message: 'ตั้งค่า', child: IconButton(
                    tooltip: null,
                    icon: const Icon(
                      Icons.settings_outlined,
                      size: 27,
                      color: WynColors.paper,
                    ),
                    onPressed: () => _openSettings(profile),
                  )),
                ] else ...[
                  BrowserSystemTooltip(message: 'ค้นหา', child: IconButton(
                    tooltip: null,
                    icon: const Icon(
                      Icons.search_rounded,
                      size: 25,
                      color: WynColors.paper,
                    ),
                    onPressed: _openSearch,
                  )),
                  BrowserSystemTooltip(message: 'เพิ่มเติม', child: IconButton(
                    tooltip: null,
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      size: 24,
                      color: WynColors.paper,
                    ),
                    onPressed: _openMoreMenu,
                  )),
                ],
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileActions({
    required Profile profile,
    required bool isOwnProfile,
    required bool isBlockedEitherWay,
  }) {
    if (isBlockedEitherWay) return _buildBlockedBanner();

    if (isOwnProfile) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: WynosFounderMetrics.profileActionHeight,
              child: FilledButton.icon(
                onPressed: () => _openEdit(profile),
                icon: const Icon(Icons.edit_outlined, size: 20),
                label: const BrowserSystemText('แก้ไขโปรไฟล์'),
                style: FilledButton.styleFrom(
                  backgroundColor: WynColors.ink,
                  foregroundColor: WynColors.paper,
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          WynosProfileIconAction(
            icon: Icons.person_add_alt_1_outlined,
            tooltip: 'แนะนำสำหรับคุณ',
            onPressed: _openSuggestedFollowers,
          ),
          const SizedBox(width: 10),
          WynosProfileIconAction(
            icon: Icons.bookmark_border_rounded,
            tooltip: 'บันทึกไว้',
            onPressed: _openSaved,
          ),
        ],
      );
    }

    if (_isFollowing == null) {
      return const SizedBox(
        height: WynosFounderMetrics.profileActionHeight,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: WynosFounderMetrics.profileActionHeight,
            child: FilledButton(
              onPressed: _isFollowActionInFlight
                  ? null
                  : () => _onFollowButtonPressed(profile),
              style: FilledButton.styleFrom(
                backgroundColor:
                    _isFollowing! ? WynColors.surfaceTint : WynColors.ink,
                foregroundColor:
                    _isFollowing! ? WynColors.ink : WynColors.paper,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: BrowserSystemText(_followButtonLabel(profile)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: WynosFounderMetrics.profileActionHeight,
            child: OutlinedButton.icon(
              onPressed: _isStartingChat ? null : () => _openChat(profile),
              icon: _isStartingChat
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined, size: 18),
              label: const BrowserSystemText('ส่งข้อความ'),
              style: OutlinedButton.styleFrom(
                foregroundColor: WynColors.ink,
                side: const BorderSide(color: WynColors.hairline),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildProfileFooter(Profile profile, bool isOwnProfile) {
    if (!isOwnProfile || !profile.isPrivate || _pendingRequestCount <= 0) {
      return null;
    }
    return InkWell(
      onTap: _openFollowRequests,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person_add_alt, size: 18),
            const SizedBox(width: 6),
            BrowserSystemText('คำขอติดตาม ($_pendingRequestCount)'),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _openAccountSwitcher() async {
    await showAccountSwitcherSheet(context);
    // Switching accounts never returns here: AuthGate tears this whole
    // route down and rebuilds for the new account (see
    // AccountSwitcherSheet._switchTo, and RootShell's own per-account
    // key). This runs on the ordinary dismiss-without-switching path,
    // and on the add-account path when the user backed out -- reload in
    // case a display name/avatar changed in the meantime, which is
    // cheap and keeps the header honest.
    if (mounted) _reload();
  }

  // Beta4 §4/§5: `_openSaved` and `_openDrafts` are gone from this
  // screen along with the two icon buttons that called them.
  //
  // Saved: unchanged system, unchanged destination ([BookmarksScreen])
  // -- it is simply reached from Home's ☰ menu now ("บันทึกไว้", which
  // SideMenu has offered since WYN-100), a labelled row in a menu
  // instead of a bookmark glyph beside "แก้ไขโปรไฟล์". Profile is where
  // you show what you published; Saved is what you kept from other
  // people, which is nobody's business but yours and was never
  // profile-shaped.
  //
  // Draft: unchanged system too, moved to where a draft is written and
  // resumed -- the composer's own header (see [DraftsScreen] and
  // [CreateDropScreen._openDrafts]).
  //
  // `ProfileSavedTab` (the grid, distinct from BookmarksScreen's row
  // list) is left in the codebase untouched and unreferenced rather
  // than deleted -- same posture as ProfilePopGridTab/ProfileRepliesTab
  // above, which are also unmounted-not-removed.

  void _openFollowRequests() {
    Navigator.of(context)
        .push<void>(
      MaterialPageRoute(
        builder: (_) => FollowRequestListScreen(
          followRequestRepository: _followRequestRepository,
        ),
      ),
    )
        .then((_) {
      // The list screen may have Accepted/Rejected requests -- refresh
      // both the badge count and this profile's own Followers count.
      if (!mounted) return;
      _loadPendingRequestCount();
      _reload();
    });
  }

  // WYN-031, Screen 4. get_or_create_conversation() itself rejects a
  // blocked pair server-side, but this button is already hidden in
  // that state (see the Blocked persona branch in build()), so the
  // only realistic failure here is a transient network error.
  Future<void> _openChat(Profile profile) async {
    if (_isStartingChat) return;
    setState(() => _isStartingChat = true);
    try {
      final conversationId = await _chatRepository.getOrCreateConversation(
        widget.userId,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            chatRepository: _chatRepository,
            conversationId: conversationId,
            otherUserId: widget.userId,
            otherUsername: profile.username,
            otherDisplayName: profile.displayName,
            otherAvatarUrl: profile.avatarUrl,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // WYN-122: get_or_create_conversation() raises this exact message
      // when chat lockdown rejects the pair -- surfaced as its own
      // SnackBar (not the generic failure below) so a locked-out user
      // understands this is a temporary platform state, not a glitch to
      // retry. This button itself stays visible/tappable either way
      // (Founder's explicit requirement) -- only the outcome differs.
      final message = e is PostgrestException &&
              e.message.contains('temporarily closed for testing')
          ? 'ระบบแชทปิดปรับปรุงชั่วคราว'
          : 'เริ่มบทสนทนาไม่สำเร็จ ลองใหม่อีกครั้ง';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: BrowserSystemText(message)));
    } finally {
      if (mounted) setState(() => _isStartingChat = false);
    }
  }

  Future<void> _loadBlockRelationship() async {
    try {
      final relationship = await _blockRepository.blockRelationship(
        widget.userId,
      );
      if (!mounted) return;
      setState(() => _blockRelationship = relationship);
    } catch (_) {
      // Leave it null -- the Follow button/banner both stay hidden
      // rather than guessing, same posture as _loadFollowStatus.
    }
  }

  Future<void> _blockUser(Profile profile) async {
    final confirmed = await confirmBlock(context, username: profile.username);
    if (!confirmed) return;

    try {
      await _blockRepository.blockUser(widget.userId);
      if (!mounted) return;
      setState(() => _blockRelationship = BlockRelationship.blockedByMe);
      // Blocking may have just torn down an existing Follow relationship
      // (either direction) and always changes the follower/following
      // counts -- reload both rather than leaving stale numbers/state.
      _isFollowing = null;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: BrowserSystemText('บล็อก @${profile.username} แล้ว')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: BrowserSystemText('บล็อกไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _loadMuteStatus() async {
    try {
      final isMuted = await _muteRepository.isMuted(widget.userId);
      if (!mounted) return;
      setState(() => _isMuted = isMuted);
    } catch (_) {
      // Leave it null -- the More menu item stays hidden rather than
      // guessing, same posture as _loadBlockRelationship.
    }
  }

  // Optimistic toggle, no confirm dialog -- unlike _blockUser above,
  // mute has no side effect visible to anyone but the current user and
  // is fully reversible, so the extra friction of a dialog isn't
  // warranted (WYN-028 Design, Screen 1 -- mirrors _toggleFollow's
  // shape exactly, not _blockUser's).
  Future<void> _toggleMute(Profile profile) async {
    final previous = _isMuted;
    if (previous == null) return;
    setState(() => _isMuted = !previous);
    try {
      if (previous) {
        await _muteRepository.unmuteUser(widget.userId);
      } else {
        await _muteRepository.muteUser(widget.userId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: BrowserSystemText(
            previous
                ? 'เปิดเสียง @${profile.username} แล้ว'
                : 'ปิดเสียง @${profile.username} แล้ว',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isMuted = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: BrowserSystemText('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _openEdit(Profile profile) async {
    await Navigator.of(context).push<Profile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profileRepository: widget.profileRepository,
          profile: profile,
        ),
      ),
    );
    _reload();
  }

  Future<void> _reportUser() {
    return showReportSheet(
      context,
      reportRepository: _reportRepository,
      targetType: ReportTargetType.user,
      targetId: widget.userId,
      targetLabel: 'รายงานผู้ใช้นี้',
      associatedUserId: widget.userId,
    );
  }

  // Extensible on purpose -- WYN-026 already left room for WYN-027/028
  // to add items here without restructuring it. "บล็อก" only shows once
  // _blockRelationship has loaded and confirms there isn't one already
  // (Design Screen 1) -- once blocked, this menu shows just "รายงาน"
  // (no "เลิกบล็อก" shortcut here per Product spec, Design Screen 3).
  // "ปิดเสียง"/"เปิดเสียง" (WYN-028) sits between รายงาน/บล็อก by
  // severity (Design Screen 1) and, like บล็อก, only shows once its own
  // status has loaded -- and never at all when a block relationship
  // already exists, since Block's Blocked persona menu reduces to just
  // "รายงาน" regardless (mute would be redundant under a much stronger
  // restriction).
  Future<void> _openMoreMenu() async {
    // WYN-033: needs the username for both the native-share text and
    // the Share-to-Chat preview label -- _loadFuture is already
    // in-flight/resolved by the time this button is reachable (set in
    // initState), so this just awaits the same cached Future the body
    // itself uses, never a second query.
    final data = await _loadFuture;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(
        rows: [
          ActionSheetRow(
            icon: Icons.share_outlined,
            label: 'แชร์โปรไฟล์',
            onTap: () {
              Navigator.of(sheetContext).pop();
              showShareSheet(
                context,
                chatRepository: _chatRepository,
                profileRepository: widget.profileRepository,
                sharedContentType: SharedContentType.profile,
                sharedContentId: widget.userId,
                previewLabel: 'แชร์โปรไฟล์ @${data.profile.username}',
                nativeShareText: profileShareLink(data.profile.username),
                nativeShareTitle:
                    data.profile.displayName ?? '@${data.profile.username}',
              );
            },
          ),
          ActionSheetRow(
            icon: Icons.flag_outlined,
            label: 'รายงาน',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _reportUser();
            },
          ),
          if (_isMuted != null && _blockRelationship == BlockRelationship.none)
            ActionSheetRow(
              icon: _isMuted! ? Icons.volume_up : Icons.volume_off,
              label: _isMuted! ? 'เปิดเสียง' : 'ปิดเสียง',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _onMuteTapped();
              },
            ),
          if (_blockRelationship == BlockRelationship.none)
            ActionSheetRow(
              icon: Icons.block,
              label: 'บล็อก',
              onTap: () {
                Navigator.of(sheetContext).pop();
                _onBlockTapped();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _onBlockTapped() async {
    try {
      final data = await _loadFuture;
      if (!mounted) return;
      await _blockUser(data.profile);
    } catch (_) {
      // The profile itself failed to load -- nothing sensible to block
      // by username; the screen's own error state already covers this.
    }
  }

  Future<void> _onMuteTapped() async {
    try {
      final data = await _loadFuture;
      if (!mounted) return;
      await _toggleMute(data.profile);
    } catch (_) {
      // The profile itself failed to load -- nothing sensible to mute
      // by username; the screen's own error state already covers this.
    }
  }

  // WYN-039 Design, Screen 2 -- the follower/following *count* stays
  // visible on a Locked profile (see follower_count()/following_count()
  // in schema.sql), but the drill-down list itself doesn't open for
  // anyone who isn't the owner or an accepted follower -- `follows`' own
  // RLS would just return an empty list anyway, but a SnackBar is a
  // clearer outcome than silently opening to nothing.
  Future<void> _openFollowList(
    FollowListMode mode, {
    required bool isLockedPrivate,
  }) async {
    if (isLockedPrivate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: BrowserSystemText('ต้องติดตามก่อนถึงจะดูรายชื่อได้')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: widget.userId,
          mode: mode,
        ),
      ),
    );
  }

  /// WYN-027 Design, Screen 3 -- when blocked (either direction), the
  /// Drop/Pop grid's empty state must say the content is *hidden*, not
  /// reuse the ordinary "ยังไม่มี ... เลย" copy that would wrongly imply
  /// this person has no content at all.
  String _gridEmptyText({
    required bool isOwnProfile,
    required bool isBlockedEitherWay,
    required bool isLockedPrivate,
    required String contentLabel,
    required Profile profile,
  }) {
    if (isBlockedEitherWay) {
      return (_blockRelationship?.iBlockedThem ?? false)
          ? 'คุณบล็อกผู้ใช้นี้อยู่ จึงไม่เห็นเนื้อหาของเขา'
          : 'ไม่สามารถดูเนื้อหาของผู้ใช้นี้ได้';
    }
    // WYN-039 Design, Screen 2 -- the grid genuinely has no rows for a
    // locked viewer (RLS on `drops` hides them), so this is the same
    // "must say hidden, not implausibly-empty" reasoning WYN-027 already
    // established above, not a new pattern.
    if (isLockedPrivate) {
      return 'บัญชีนี้เป็นส่วนตัว — ติดตามเพื่อดู ${profile.nameOrUsername}';
    }
    return isOwnProfile
        ? 'ยังไม่มี $contentLabel เลย'
        : '${profile.nameOrUsername} ยังไม่มี $contentLabel เลย';
  }

  /// WYN-027 Design, Screen 3 -- two honest variants depending on who
  /// blocked whom, never a generic "you can't see this" that would
  /// misrepresent a relationship the viewer didn't actually choose.
  Widget _buildBlockedBanner() {
    final iBlockedThem = _blockRelationship?.iBlockedThem ?? false;
    final message = iBlockedThem
        ? 'คุณบล็อกผู้ใช้นี้อยู่'
        : 'ไม่สามารถดูเนื้อหาของผู้ใช้นี้ได้';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: WynSpacing.space4,
        vertical: WynSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: WynSpacing.space2),
          Flexible(
            child: BrowserSystemText(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = _isOwnProfile;

    return DefaultTabController(
      // 05-profile.tsx cuts Replies/Media -- 3 tabs (Posts/ReDrops/Likes)
      // for every viewer now. See the TabBar/TabBarView below.
      length: 3,
      child: Scaffold(
        backgroundColor: WynColors.paper,
        bottomNavigationBar:
            !isOwnProfile && RootNavigationController.isAttached
                ? _buildPushedProfileBottomNavigation()
                : null,
        body: FutureBuilder<_ProfileWithCounts>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrowserSystemText('โหลดโปรไฟล์ไม่สำเร็จ'),
                    const SizedBox(height: WynSpacing.space3),
                    TextButton(
                      onPressed: _reload,
                      child: const BrowserSystemText('ลองใหม่'),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const ProfileSkeleton();
            }

            final data = snapshot.data!;
            final profile = data.profile;
            final isBlockedEitherWay = !isOwnProfile &&
                (_blockRelationship?.isBlockedEitherWay ?? false);
            // WYN-039 Design, Screen 2 -- Block always takes precedence
            // over Private (a blocked pair sees the Blocked banner, never
            // the Locked one, regardless of the target's account type).
            // While _isFollowing is still loading (null), this
            // conservatively treats the viewer as not-yet-a-follower --
            // the same brief-flicker tradeoff _blockRelationship's own
            // `?? false` default already accepts elsewhere on this
            // screen, not a new one introduced here.
            final isLockedPrivate = !isOwnProfile &&
                !isBlockedEitherWay &&
                profile.isPrivate &&
                (_isFollowing ?? false) == false;

            // WYN-110: NestedScrollView instead of a plain Column -- the
            // header (avatar/name/bio/stats/button) used to sit outside
            // any scrollable at all, so it stayed on screen permanently
            // no matter how far the reader scrolled through posts,
            // leaving barely half the viewport for actual content. This
            // lets the header scroll away like an ordinary sliver while
            // the TabBar pins to the top once it gets there -- the same
            // SliverToBoxAdapter/SliverPersistentHeader(pinned) split
            // home_feed_screen.dart already uses for its own explainer
            // banner and feed-mode toggle. Each tab body below
            // (ProfileDropGridTab/ProfileRedropsTab/ProfileLikesTab) is
            // this NestedScrollView's inner scrollable -- see their own
            // SliverOverlapInjector for the other half of that contract.
            return RefreshIndicator(
              onRefresh: _refreshWholeProfile,
              notificationPredicate: (notification) =>
                  notification.metrics.axis == Axis.vertical,
              child: NestedScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  // Keep cover + identity in one render box so the avatar's
                  // intentional negative overlap is inside this sliver's paint bounds.
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildProfileCoverBar(profile, isOwnProfile),
                        WynosFounderProfileHeader(
                          profile: profile,
                          followingCount: data.followingCount,
                          followerCount: data.followerCount,
                          isOwnProfile: isOwnProfile,
                          showStats: !isBlockedEitherWay,
                          showOnline: isOwnProfile,
                          onDisplayNameTap:
                              isOwnProfile ? _openAccountSwitcher : null,
                          onFollowingTap: () => _openFollowList(
                            FollowListMode.following,
                            isLockedPrivate: isLockedPrivate,
                          ),
                          onFollowersTap: () => _openFollowList(
                            FollowListMode.followers,
                            isLockedPrivate: isLockedPrivate,
                          ),
                          actions: _buildProfileActions(
                            profile: profile,
                            isOwnProfile: isOwnProfile,
                            isBlockedEitherWay: isBlockedEitherWay,
                          ),
                          footer: _buildProfileFooter(profile, isOwnProfile),
                        ),
                      ],
                    ),
                  ),
                  if (!isOwnProfile)
                    SliverToBoxAdapter(
                      child: ProfileRecommendationSection(
                        discoveryRepository: _discoveryRepository,
                        followRepository: widget.followRepository,
                        followRequestRepository: _followRequestRepository,
                        profileRepository: widget.profileRepository,
                      ),
                    ),
                  // 05-profile.tsx cuts Replies/Media -- 3 tabs
                  // (Posts/ReDrops/Likes) for every viewer now, same
                  // public set regardless of who's looking. Saved/Draft
                  // (own-only, private) stay on the icon row above, not
                  // tabs here -- see _openSaved/_openDrafts.
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _ProfileTabBarDelegate(
                      tabBar: TabBar(
                        indicatorColor: WynColors.ink,
                        indicatorSize: TabBarIndicatorSize.label,
                        indicatorWeight: 2,
                        labelColor: WynColors.ink,
                        unselectedLabelColor: WynColors.mutedNeutral,
                        labelStyle: _textStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: _textStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                        tabs: const [
                          Tab(
                            height: WynosFounderMetrics.profileTabHeight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.image_outlined, size: 20),
                                  SizedBox(width: 7),
                                  BrowserSystemText('สื่อ'),
                                ],
                              ),
                            ),
                          ),
                          Tab(
                            height: WynosFounderMetrics.profileTabHeight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.repeat_rounded, size: 20),
                                  SizedBox(width: 7),
                                  BrowserSystemText('รีโพสต์'),
                                ],
                              ),
                            ),
                          ),
                          Tab(
                            height: WynosFounderMetrics.profileTabHeight,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.favorite_border_rounded, size: 20),
                                  SizedBox(width: 7),
                                  BrowserSystemText('ถูกใจ'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                body: TabBarView(
                  children: [
                    ProfileDropGridTab(
                      dropRepository: widget.dropRepository,
                      followRepository: widget.followRepository,
                      profileRepository: widget.profileRepository,
                      popRepository: widget.popRepository,
                      savedRepository: widget.savedRepository,
                      authorId: widget.userId,
                      refreshCoordinator: _refreshCoordinator,
                      emptyText: _gridEmptyText(
                        isOwnProfile: isOwnProfile,
                        isBlockedEitherWay: isBlockedEitherWay,
                        isLockedPrivate: isLockedPrivate,
                        contentLabel: 'Post',
                        profile: profile,
                      ),
                    ),
                    ProfileRedropsTab(
                      homeRepository: _homeRepository,
                      dropRepository: widget.dropRepository,
                      followRepository: widget.followRepository,
                      profileRepository: widget.profileRepository,
                      popRepository: widget.popRepository,
                      savedRepository: widget.savedRepository,
                      authorId: widget.userId,
                      refreshCoordinator: _refreshCoordinator,
                      emptyText: _gridEmptyText(
                        isOwnProfile: isOwnProfile,
                        isBlockedEitherWay: isBlockedEitherWay,
                        isLockedPrivate: isLockedPrivate,
                        contentLabel: 'รีโพสต์',
                        profile: profile,
                      ),
                    ),
                    Column(
                      children: [
                        if (isOwnProfile)
                          PrivacyNoticeBanner(
                            prefsKey: 'seen_likes_privacy_notice',
                            // WYN-099: tracks the owner's own current
                            // likes_visibility setting -- must never
                            // claim "everyone sees this" once they've
                            // narrowed it, or the banner contradicts
                            // the tab's real behavior.
                            message: switch (profile.likesVisibility) {
                              LikesVisibility.everyone =>
                                'คนอื่นเห็นสิ่งที่คุณกด Like ได้เหมือนกัน',
                              LikesVisibility.friends =>
                                'เฉพาะเพื่อนของคุณเท่านั้นที่เห็นแท็บนี้ได้',
                              LikesVisibility.onlyMe =>
                                'เฉพาะคุณเท่านั้นที่เห็นแท็บนี้',
                            },
                          ),
                        Expanded(
                          child: ProfileLikesTab(
                            dropRepository: widget.dropRepository,
                            followRepository: widget.followRepository,
                            profileRepository: widget.profileRepository,
                            popRepository: widget.popRepository,
                            savedRepository: widget.savedRepository,
                            authorId: widget.userId,
                            refreshCoordinator: _refreshCoordinator,
                            emptyText: _gridEmptyText(
                              isOwnProfile: isOwnProfile,
                              isBlockedEitherWay: isBlockedEitherWay,
                              isLockedPrivate: isLockedPrivate,
                              contentLabel: 'สิ่งที่ถูกใจ',
                              profile: profile,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? height,
}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );

/// WYN-110: pins the profile's TabBar (โพสต์/รีโพสต์/ถูกใจ) to the top of
/// the screen once the header above it has scrolled away, the same
/// "pinned SliverPersistentHeader" shape home_feed_screen.dart's own
/// _FeedModeToggleHeaderDelegate already uses for the feed-mode toggle --
/// see that class's doc comment for why a pinned sliver needs an exact
/// extent rather than a guessed one. [TabBar] is a [PreferredSizeWidget]
/// already, so its own [TabBar.preferredSize] supplies that exact extent
/// with nothing to measure or hardcode by hand.
class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _ProfileTabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Opaque, same reasoning as _FeedModeToggleHeaderDelegate: once
    // pinned above scrolled-past post cards, this needs its own surface
    // so they don't show through underneath it.
    return Material(color: WynColors.paper, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _ProfileTabBarDelegate oldDelegate) =>
      tabBar != oldDelegate.tabBar;
}

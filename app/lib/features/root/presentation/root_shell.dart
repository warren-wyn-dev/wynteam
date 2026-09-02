import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../analytics/data/analytics_repository.dart';
import '../../auth/presentation/widgets/guest_gate.dart';
import '../../chat/data/chat_repository.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/create_drop_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../home/data/home_repository.dart';
import '../../home/presentation/home_feed_screen.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../notification/data/notification_repository.dart';
import '../../notification/presentation/notification_list_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../saved/data/saved_repository.dart';
import '../../search/presentation/search_screen.dart';
import '../../push/data/push_token_repository.dart';
import '../../push/presentation/push_notification_service.dart';
import '../../zoky/data/zoky_repository.dart';
import '../../../core/design/wyn_spacing.dart';

/// The Bottom Navigation shell -- 5 destinations per the WYNOS V1.0.0
/// Master Spec (Section 34): Home / Search / Drop ("+", a create action,
/// not a page) / Notifications / Profile. Replaces the WYN V0.1-era
/// Home/Drop/Pop/Profile[/ZOKY] shell (see .wyn/company/DECISIONS.md,
/// 2026-08-14 and 2026-08-22). Renders as AuthGate's signed-in +
/// onboarded state.
///
/// Pop and ZOKY are unmounted here, not deleted -- their screens/data/DB
/// tables are untouched, just no longer reachable from normal UI, per
/// the V1.0.0 roadmap (Pop -> V3, WYN Shop/Marketplace -> V2). The old
/// Drop tab's own social feed (WYN-019-022: For You/Following/Latest +
/// hashtag/mention/reply) is different: it's fully absorbed into Home's
/// feed-mode selector (see HomeFeedScreen), so DropFeedScreen itself is
/// deleted, not just unmounted. See
/// .wyn/docs/design/wyn-024-bottom-nav-v1-restructure.md.
class RootShell extends StatefulWidget {
  const RootShell({
    super.key,
    DropRepository? dropRepository,
    PopRepository? popRepository,
    FollowRepository? followRepository,
    ProfileRepository? profileRepository,
    SavedRepository? savedRepository,
    NotificationRepository? notificationRepository,
    ClubRepository? clubRepository,
    ClubPostRepository? clubPostRepository,
    ZokyRepository? zokyRepository,
    HomeRepository? homeRepository,
    AppealRepository? appealRepository,
    ChatRepository? chatRepository,
  })  : _dropRepository = dropRepository,
        _popRepository = popRepository,
        _followRepository = followRepository,
        _profileRepository = profileRepository,
        _savedRepository = savedRepository,
        _notificationRepository = notificationRepository,
        _clubRepository = clubRepository,
        _clubPostRepository = clubPostRepository,
        _zokyRepository = zokyRepository,
        _homeRepository = homeRepository,
        _appealRepository = appealRepository,
        _chatRepository = chatRepository;

  // All optional -- default to real Supabase-backed instances built in
  // _RootShellState.initState (see .wyn/learning/PATTERNS.md's "optional
  // repository param, real default" convention -- same shape
  // CreateDropScreen's ProfileRepository? already uses). Tests inject
  // Recording* fakes here instead of touching Supabase.instance.
  final DropRepository? _dropRepository;
  final PopRepository? _popRepository;
  final FollowRepository? _followRepository;
  final ProfileRepository? _profileRepository;
  final SavedRepository? _savedRepository;
  final NotificationRepository? _notificationRepository;
  final ClubRepository? _clubRepository;
  final ClubPostRepository? _clubPostRepository;
  final ZokyRepository? _zokyRepository;
  final HomeRepository? _homeRepository;
  final AppealRepository? _appealRepository;
  final ChatRepository? _chatRepository;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  // The 5 NavigationBar destinations, in display order. Index 2 (Drop) is
  // a create action, not a page -- it never becomes _tabIndex and is
  // never the "selected" destination.
  static const _homeDestinationIndex = 0;
  static const _searchDestinationIndex = 1;
  static const _dropDestinationIndex = 2;
  static const _notificationsDestinationIndex = 3;
  static const _profileDestinationIndex = 4;

  // The 4 real tabs held in IndexedStack, in build order below. (Search,
  // tab index 1, has no key-bump/badge logic of its own so it never needs
  // to be referenced by name here -- only Home/Notifications/Profile do.)
  static const _homeTab = 0;
  static const _notificationsTab = 2;
  static const _profileTab = 3;

  static const _navIndexForTab = [
    _homeDestinationIndex,
    _searchDestinationIndex,
    _notificationsDestinationIndex,
    _profileDestinationIndex,
  ];

  int _tabIndex = _homeTab;

  // Bumped whenever the corresponding tab is (re)visited, forcing that
  // tab's widget to remount (fresh fetch) -- same "bump a key to force
  // reload" approach for both, matching the pattern this shell already
  // used for Profile pre-WYN-024. See .wyn/docs/design/wyn-008-follow.md,
  // Screen 4. Notifications needs this too now that it's a permanent tab
  // rather than something pushed fresh each time: NotificationListScreen
  // marks everything read in its own initState, which otherwise would
  // only ever run once per app session under IndexedStack.
  int _profileVisitKey = 0;
  int _notificationsVisitKey = 0;

  // Bumped after a Drop is created from the "+" button so Home remounts
  // and refetches -- the freshly created Drop appears at the top of
  // whichever feed mode is active, same visible effect the old
  // DropFeedScreen's own _feedVersion bump had, without needing to thread
  // a GlobalKey/callback down into HomeFeedScreen's private State.
  int _homeVersion = 0;

  int _unreadNotificationCount = 0;

  // WYN-064 (Tap Home Tab to Scroll to Top & Refresh): bumped whenever
  // the Home destination is tapped while already on the Home tab --
  // HomeFeedScreen listens and scrolls to top (if scrolled) or triggers
  // pull-to-refresh (if already at top). See HomeFeedScreen's own doc
  // comment on homeTabReselectSignal for why this is a ValueNotifier
  // rather than a GlobalKey<State>.
  final _homeTabReselectSignal = ValueNotifier<int>(0);

  late final DropRepository _dropRepository;
  late final PopRepository _popRepository;
  late final FollowRepository _followRepository;
  late final ProfileRepository _profileRepository;
  late final SavedRepository _savedRepository;
  late final NotificationRepository _notificationRepository;
  late final ClubRepository _clubRepository;
  late final ClubPostRepository _clubPostRepository;
  late final ZokyRepository _zokyRepository;
  late final HomeRepository _homeRepository;
  late final AppealRepository _appealRepository;
  late final ChatRepository _chatRepository;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _dropRepository = widget._dropRepository ?? DropRepository(client);
    _popRepository = widget._popRepository ?? PopRepository(client);
    _followRepository = widget._followRepository ?? FollowRepository(client);
    _profileRepository = widget._profileRepository ?? ProfileRepository(client);
    _savedRepository = widget._savedRepository ?? SavedRepository(client);
    _notificationRepository =
        widget._notificationRepository ?? NotificationRepository(client);
    _clubRepository = widget._clubRepository ?? ClubRepository(client);
    _clubPostRepository = widget._clubPostRepository ?? ClubPostRepository(client);
    _zokyRepository = widget._zokyRepository ?? ZokyRepository(client);
    _homeRepository = widget._homeRepository ?? HomeRepository(client);
    _appealRepository = widget._appealRepository ?? AppealRepository(client);
    _chatRepository = widget._chatRepository ?? ChatRepository(client);

    // WYN-016 (Push Notification): request permission + register this
    // device's token once, the first time RootShell renders (i.e. right
    // after onboarding, not from the Welcome screen where the user
    // doesn't know the app yet). Safe to call unconditionally even
    // before Firebase is configured -- PushNotificationService.initialize
    // checks Firebase.apps itself and no-ops if empty.
    PushNotificationService(PushTokenRepository(client)).initialize();

    // WYN-077: fire-once-per-session proxy for "a real user is actively
    // using the app" -- same shape as the push-notification call above
    // (bare, unawaited call in initState; RootShell's State survives
    // AuthGate's rebuilds via const-widget identity, see AuthGate's own
    // doc comment, so this genuinely runs once per sign-in rather than
    // once per rebuild). Guests (Anonymous Sign-In, WYN-072) are
    // excluded -- there is no "signup" to attribute a guest's session to.
    final currentUser = client.auth.currentUser;
    if (currentUser != null && !currentUser.isAnonymous) {
      AnalyticsRepository(client).logSessionStart();
    }

    _loadUnreadNotificationCount();
  }

  @override
  void dispose() {
    _homeTabReselectSignal.dispose();
    super.dispose();
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final count = await _notificationRepository.countUnread();
      if (!mounted) return;
      setState(() => _unreadNotificationCount = count);
    } catch (_) {
      // Silent: a failed badge-count fetch just leaves the badge showing
      // its last known value (or none) -- not worth a blocking error UI
      // for a number in the corner of an icon.
    }
  }

  // WYN-072 (Guest Browsing): Drop ("+")/Notifications/Profile all need a
  // real identity -- gated the same way regardless of which of the 3 it
  // is, via the one shared requireRealAccount() dialog. Home and Search
  // are deliberately not in this set -- a guest can browse both freely,
  // per Founder's own "ดูโพสต์ได้" (see the design doc's Design Rules).
  Future<void> _onDestinationSelected(int navIndex) async {
    final needsRealAccount = navIndex == _dropDestinationIndex ||
        navIndex == _notificationsDestinationIndex ||
        navIndex == _profileDestinationIndex;
    if (needsRealAccount && !await requireRealAccount(context)) return;
    if (!mounted) return;

    if (navIndex == _dropDestinationIndex) {
      _openCreateDrop();
      return;
    }

    // WYN-064: tapping Home while already on Home doesn't change tabs --
    // it tells HomeFeedScreen to scroll to top or refresh instead (see
    // its _onHomeTabReselected). No setState here: _tabIndex is
    // unchanged, so nothing else on this screen needs to rebuild.
    if (navIndex == _homeDestinationIndex && _tabIndex == _homeTab) {
      _homeTabReselectSignal.value++;
      return;
    }

    final tabIndex = _navIndexForTab.indexOf(navIndex);
    setState(() {
      if (tabIndex == _profileTab && _tabIndex != _profileTab) {
        _profileVisitKey++;
      }
      if (tabIndex == _notificationsTab && _tabIndex != _notificationsTab) {
        _notificationsVisitKey++;
        // NotificationListScreen marks everything read as soon as it
        // (re)mounts -- reflect that on the badge immediately rather than
        // waiting on a fetch round-trip back from a screen that isn't
        // pushed/popped anymore.
        _unreadNotificationCount = 0;
      }
      _tabIndex = tabIndex;
    });
  }

  Future<void> _openCreateDrop() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateDropScreen(dropRepository: _dropRepository),
      ),
    );
    if (created == true) setState(() => _homeVersion++);
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    final tabs = [
      HomeFeedScreen(
        key: ValueKey('home_$_homeVersion'),
        homeRepository: _homeRepository,
        dropRepository: _dropRepository,
        popRepository: _popRepository,
        followRepository: _followRepository,
        profileRepository: _profileRepository,
        savedRepository: _savedRepository,
        clubRepository: _clubRepository,
        clubPostRepository: _clubPostRepository,
        chatRepository: _chatRepository,
        homeTabReselectSignal: _homeTabReselectSignal,
      ),
      SearchScreen(
        profileRepository: _profileRepository,
        followRepository: _followRepository,
        dropRepository: _dropRepository,
        popRepository: _popRepository,
        savedRepository: _savedRepository,
        clubRepository: _clubRepository,
        clubPostRepository: _clubPostRepository,
      ),
      NotificationListScreen(
        key: ValueKey('notifications_$_notificationsVisitKey'),
        notificationRepository: _notificationRepository,
        dropRepository: _dropRepository,
        popRepository: _popRepository,
        followRepository: _followRepository,
        profileRepository: _profileRepository,
        savedRepository: _savedRepository,
        clubRepository: _clubRepository,
        clubPostRepository: _clubPostRepository,
        zokyRepository: _zokyRepository,
        appealRepository: _appealRepository,
        chatRepository: _chatRepository,
      ),
      ViewProfileScreen(
        key: ValueKey('profile_$_profileVisitKey'),
        profileRepository: _profileRepository,
        followRepository: _followRepository,
        dropRepository: _dropRepository,
        popRepository: _popRepository,
        savedRepository: _savedRepository,
        userId: userId,
        clubRepository: _clubRepository,
        clubPostRepository: _clubPostRepository,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _tabIndex, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndexForTab[_tabIndex],
        onDestinationSelected: (navIndex) => _onDestinationSelected(navIndex),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: _buildDropAction(),
            selectedIcon: _buildDropAction(),
            label: 'Drop',
          ),
          NavigationDestination(
            icon: _buildNotificationsIcon(context, selected: false),
            selectedIcon: _buildNotificationsIcon(context, selected: true),
            label: 'Notifications',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // Never actually renders "selected" (selectedIndex skips this
  // position), so icon/selectedIcon are identical -- this destination is
  // an action, not a tab. Semantics says so explicitly rather than
  // letting NavigationBar announce it the same way as the 4 real tabs.
  //
  // Rendered as a filled cyan circle (not a bare icon) with a soft
  // colored-shadow glow -- WYN-056's visual refresh, matching the
  // Founder's WYNOS mockup's prominent Drop button. The glow is a plain
  // BoxShadow (opaque circle + shadow), never a blur/translucent
  // surface, so it doesn't touch the "no Liquid Glass" rule. Always
  // shown this way, not just on press, since this destination has no
  // selected state to distinguish. See
  // .wyn/docs/design/wyn-056-club-discovery-visual-refresh.md, Screen 6.
  Widget _buildDropAction() {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'สร้าง Drop ใหม่',
      button: true,
      child: ExcludeSemantics(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primary,
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.35),
                blurRadius: 16,
              ),
            ],
          ),
          child: Icon(Icons.add, color: scheme.onPrimary),
        ),
      ),
    );
  }

  Widget _buildNotificationsIcon(BuildContext context, {required bool selected}) {
    final icon = Icon(selected ? Icons.notifications : Icons.notifications_outlined);
    final count = _unreadNotificationCount;
    if (count <= 0) return icon;

    final badgeText = count > 9 ? '9+' : '$count';
    return Semantics(
      label: 'การแจ้งเตือน มี $count รายการที่ยังไม่อ่าน',
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            right: -6,
            top: -4,
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
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

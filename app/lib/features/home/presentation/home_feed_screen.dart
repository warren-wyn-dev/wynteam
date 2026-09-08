import 'package:flutter/material.dart';

import '../../auth/presentation/widgets/guest_gate.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/chat_inbox_screen.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../drop/data/drop_repository.dart';
import '../../follow/data/follow_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../root/presentation/side_menu.dart';
import '../../saved/data/saved_repository.dart';
import '../data/home_repository.dart';
import 'widgets/from_your_clubs_feed.dart';
import 'widgets/mode_feed_page.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/interaction/wyn_motion.dart';

enum _HomeFeedMode { forYou, following, fromYourClubs }

// WYN-140: display/swipe/page order for the 3 modes -- shared by
// _buildFeedModeToggle (tap), the PageView's own drag-to-swipe, and
// _onHomeTabReselected/_selectFeedMode so every input method (tap,
// swipe, tab-reselect) agrees about what index each mode lives at.
const List<_HomeFeedMode> _feedModeOrder = [
  _HomeFeedMode.forYou,
  _HomeFeedMode.following,
  _HomeFeedMode.fromYourClubs,
];

/// Screen 1 — Home tab (Bottom Nav, index 0). A feed mixing Drop and Pop
/// content, with the CLUB section (WYN-014) directly above the feed.
/// Default mode is "สำหรับคุณ" (ranked, WYN-018); "ติดตาม" (WYN-024)
/// absorbs the WYN-019 Drop tab's own Following capability now that Drop
/// no longer has a separate tab; "ล่าสุด" is the original WYN-007
/// chronological ordering. Search and Notifications moved out to their
/// own Bottom Nav tabs as part of WYN-024; this screen's own top row is
/// the hamburger (opens SideMenu, WYN-100) + WYNOS wordmark + Chat entry
/// point (see _buildHeader), not a full AppBar. See
/// .wyn/docs/design/wyn-007-home.md,
/// .wyn/docs/design/wyn-014-club-core.md (Screen 1),
/// .wyn/docs/design/wyn-018-home-feed-ranking.md, and
/// .wyn/docs/design/wyn-024-bottom-nav-v1-restructure.md (Screen 2).
///
/// WYN-140 (2026-09-08, "อยากให้ Swipe หลายๆหน้า เหมือนแพตฟอมใหญ่ๆ"):
/// this screen used to hold all 3 modes' feed logic itself, sharing one
/// `_items`/`_page` between "สำหรับคุณ"/"ติดตาม" and swapping what it
/// showed. Founder asked for the swipe between tabs to genuinely show
/// the destination tab's own content sliding in as you drag, the way
/// Threads/IG/X do it -- that needs each mode's content alive and
/// independently scrollable at once, not one shared list. This screen
/// is now just the shell (header, drawer, chat icon, the toggle row) --
/// each mode's actual feed lives in its own widget (ModeFeedPage for
/// สำหรับคุณ/ติดตาม, FromYourClubsFeed for Club, which already had this
/// shape before this change), hosted as 3 pages of a real PageView.
class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({
    super.key,
    required this.homeRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.savedRepository,
    required this.clubRepository,
    required this.clubPostRepository,
    required this.chatRepository,
    required this.homeTabReselectSignal,
    required this.homeTabActivatedSignal,
  });

  final HomeRepository homeRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final SavedRepository savedRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  // WYN-064 (Tap Home Tab to Scroll to Top & Refresh): RootShell bumps
  // this notifier's value every time the user taps the Home destination
  // while already on the Home tab. A ValueNotifier rather than a
  // GlobalKey<State> -- RootShell lives in a different file and this
  // screen's State is intentionally private, same reasoning as every
  // other cross-widget signal in this codebase (e.g. the visit-key
  // remount pattern) preferring an explicit, testable channel over
  // reaching into private State from outside.
  final ValueNotifier<int> homeTabReselectSignal;

  // Bumped by RootShell whenever the Home tab becomes active *from a
  // different tab* (IndexedStack tab switches raise no lifecycle/route
  // event of their own -- see RootShell's own doc comment on this
  // field). Unlike [homeTabReselectSignal] this never scrolls or
  // reloads the feed -- it only re-reads the unread-chat-message badge,
  // the one piece of this screen that can go stale while a *different*
  // tab (Notifications, or a pushed ConversationScreen reached from a
  // push notification) marks a conversation read on the server.
  final ValueNotifier<int> homeTabActivatedSignal;

  // WYN-031 -- Chat's entry point icon lives in this screen's header
  // (see _buildHeader): Master Spec section 18 requires Chat to be
  // reachable via "a separate icon", never a 6th Bottom Nav tab, and
  // this is the most natural home-screen-adjacent place for it now
  // that Search/Notifications moved out.
  final ChatRepository chatRepository;

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> with WidgetsBindingObserver {
  // WYN-100: opens the SideMenu drawer (mirrors
  // notification_list_screen.dart's own _scaffoldKey exactly).
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  // WYN-140: each ranked-feed page now keeps its own scroll/pagination
  // state (see ModeFeedPageState) -- these keys are how
  // _onHomeTabReselected forwards the scroll-to-top/refresh gesture to
  // whichever page is currently active, since this screen no longer
  // holds a scroll position of its own.
  final _forYouKey = GlobalKey<ModeFeedPageState>();
  final _followingKey = GlobalKey<ModeFeedPageState>();

  late final PageController _feedPageController =
      PageController(initialPage: _feedModeOrder.indexOf(_feedMode));

  // Resets to "สำหรับคุณ" every time Home is (re)built fresh -- not
  // persisted across app sessions, per the Design spec's "ค่าเริ่มต้น...
  // เสมอทุกครั้งที่เปิดแอป" simplification.
  _HomeFeedMode _feedMode = _HomeFeedMode.forYou;

  int _unreadChatCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadChatCount();
    WidgetsBinding.instance.addObserver(this);
    widget.homeTabReselectSignal.addListener(_onHomeTabReselected);
    widget.homeTabActivatedSignal.addListener(_loadUnreadChatCount);
  }

  // Same "refresh on resume" fix RootShell._loadUnreadNotificationCount
  // already has for the Notifications bell (Beta4 §11.4) -- this badge
  // never got it, so it stayed stuck at whatever it read in initState
  // whenever a conversation was read from anywhere other than this
  // screen's own _openChatInbox (a push notification tap, Notifications,
  // Profile, and Message Requests all push ConversationScreen directly,
  // none of them tell Home to refresh).
  //
  // Not sufficient on its own, though: on the Flutter Web build this
  // app also ships as, switching bottom-nav tabs (Notifications ->
  // Home) never backgrounds/foregrounds the browser tab, so this
  // callback can go a whole session without firing even once -- that's
  // what widget.homeTabActivatedSignal's own listener (registered in
  // initState, right above the subscribeToNewPosts call) covers
  // instead. Kept anyway: it is the only trigger that fires for a
  // genuine background/foreground cycle (backgrounding the app on
  // mobile, or the OS/browser focusing an already-open tab from a push
  // notification), which the activated-signal path does not cover.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadUnreadChatCount();
    }
  }

  // WYN-032: the badge is "anything needing my attention" -- unread
  // messages in conversations I've already accepted, plus Message
  // Requests I haven't decided on yet. Fetched as 2 separate calls
  // (not summed server-side) since they come from 2 different
  // RPCs/views for unrelated reasons -- see chat_repository.dart.
  Future<void> _loadUnreadChatCount() async {
    try {
      final results = await Future.wait([
        widget.chatRepository.countUnreadConversations(),
        widget.chatRepository.countPendingMessageRequests(),
      ]);
      if (mounted) setState(() => _unreadChatCount = results[0] + results[1]);
    } catch (_) {
      // Silent -- same posture as RootShell's identical notification
      // badge fetch: a failed count just leaves the badge as-is, not
      // worth a blocking error for a number in an AppBar icon.
    }
  }

  // WYN-072 (Guest Browsing): Chat is a conversation with another real
  // person -- gated the same as Profile/Drop/Notifications in RootShell.
  Future<void> _openChatInbox() async {
    if (!await requireRealAccount(context)) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatInboxScreen(chatRepository: widget.chatRepository),
      ),
    );
    if (mounted) _loadUnreadChatCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.homeTabReselectSignal.removeListener(_onHomeTabReselected);
    widget.homeTabActivatedSignal.removeListener(_loadUnreadChatCount);
    _feedPageController.dispose();
    super.dispose();
  }

  // WYN-064 (Tap Home Tab to Scroll to Top & Refresh): RootShell calls
  // this by bumping homeTabReselectSignal whenever the user taps the
  // Home destination while already on the Home tab. Forwards to
  // whichever ModeFeedPage is currently the active PageView page --
  // Club (FromYourClubsFeed) has no such hook and, same as before this
  // screen held per-mode state, a reselect while already on Club is a
  // no-op.
  void _onHomeTabReselected() {
    switch (_feedMode) {
      case _HomeFeedMode.forYou:
        _forYouKey.currentState?.scrollToTopAndRefresh();
        break;
      case _HomeFeedMode.following:
        _followingKey.currentState?.scrollToTopAndRefresh();
        break;
      case _HomeFeedMode.fromYourClubs:
        break;
    }
  }

  // WYN-140: the one place _feedMode actually changes from a tap --
  // animates the PageView to the matching page; onPageChanged (see
  // build()) is what actually updates _feedMode once the page arrives,
  // the same single source of truth a swipe already updates it through,
  // so tap and swipe can never drift into disagreeing about which mode
  // is active.
  void _selectFeedMode(_HomeFeedMode mode) {
    if (mode == _feedMode) return;
    _feedPageController.animateToPage(
      _feedModeOrder.indexOf(mode),
      duration: WynMotion.duration(context, WynMotion.standard),
      curve: WynMotion.enter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(
        profileRepository: widget.profileRepository,
        followRepository: widget.followRepository,
        dropRepository: widget.dropRepository,
        popRepository: widget.popRepository,
        savedRepository: widget.savedRepository,
        clubRepository: widget.clubRepository,
        clubPostRepository: widget.clubPostRepository,
      ),
      // A real header row (wordmark + chat entry point), matching
      // design-reference/01-home.tsx's header -- not the floating
      // Positioned-over-content overlay this screen used to render the
      // chat icon as (see WYN-031's original "deviation from AppBar"
      // note, since superseded). See .wyn/docs/design/wyn-031-chat-1to1.md,
      // Screen 1.
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // WYN-140: the toggle is a plain fixed row now, not a
            // pinned SliverPersistentHeader inside a shared
            // CustomScrollView -- there is no longer one shared
            // scrollable for it to pin within, and a fixed widget above
            // the PageView is visually identical to "pinned" (always
            // visible, feed content scrolls beneath it) without needing
            // a hand-measured height constant the way the old
            // _FeedModeToggleHeaderDelegate did.
            _buildFeedModeToggle(),
            Expanded(
              child: PageView.builder(
                key: const Key('home_feed_page_view'),
                controller: _feedPageController,
                itemCount: _feedModeOrder.length,
                onPageChanged: (index) {
                  setState(() => _feedMode = _feedModeOrder[index]);
                },
                itemBuilder: (context, index) {
                  switch (_feedModeOrder[index]) {
                    case _HomeFeedMode.forYou:
                      return ModeFeedPage(
                        key: _forYouKey,
                        mode: HomeFeedRankMode.forYou,
                        homeRepository: widget.homeRepository,
                        dropRepository: widget.dropRepository,
                        popRepository: widget.popRepository,
                        followRepository: widget.followRepository,
                        profileRepository: widget.profileRepository,
                        savedRepository: widget.savedRepository,
                      );
                    case _HomeFeedMode.following:
                      return ModeFeedPage(
                        key: _followingKey,
                        mode: HomeFeedRankMode.following,
                        homeRepository: widget.homeRepository,
                        dropRepository: widget.dropRepository,
                        popRepository: widget.popRepository,
                        followRepository: widget.followRepository,
                        profileRepository: widget.profileRepository,
                        savedRepository: widget.savedRepository,
                      );
                    case _HomeFeedMode.fromYourClubs:
                      return FromYourClubsFeed(
                        key: const Key('from_your_clubs_feed'),
                        clubRepository: widget.clubRepository,
                        clubPostRepository: widget.clubPostRepository,
                      );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WYNOS wordmark + hamburger + chat entry point, matching design-
  // reference/01-home.tsx's header row. WYN-100: the hamburger now opens
  // the real SideMenu drawer above (Club shortcuts live there --
  // "สร้าง Club"/"Club ของฉัน" -- previously only reachable from
  // Notifications). Icon/size/color/tooltip match
  // notification_list_screen.dart's own hamburger exactly (see
  // .wyn/docs/design/wyn-100-club-menu-create-club.md, Screen 1). The
  // reference's search icon becomes chat, matching what this icon
  // already opens everywhere else in the app (WYN-031).
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          WynSpacing.space2, WynSpacing.space1, WynSpacing.space2, WynSpacing.space1),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, size: 20, color: WynColors.ink),
            tooltip: 'เมนู',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/wynos_logo_mark.png',
                    height: 20,
                  ),
                  const SizedBox(width: WynSpacing.space2),
                  Text(
                    'WYNOS',
                    style: WynTypography.screenTitle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildChatAction(),
        ],
      ),
    );
  }

  // Badge shape mirrors RootShell._buildNotificationsIcon exactly (cap
  // "9+", same Container/Positioned/color tokens) -- this is an
  // IconButton rather than a plain Icon since (unlike the Bottom Nav
  // destination it mirrors) this is the tap target itself, not wrapped
  // by something else that handles the tap.
  Widget _buildChatAction() {
    const icon = Icon(Icons.chat_bubble_outline);
    final count = _unreadChatCount;
    final badge = count <= 0
        ? icon
        : Stack(
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
                    // Unread badges read as red (colorScheme.error), not
                    // brand sapphire (colorScheme.primary) -- Founder:
                    // "เปลี่ยนเป็นสีแดง จะได้ชัด". Matches
                    // RootShell._buildNotificationsIcon's own badge,
                    // updated alongside this one for the same reason.
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onError,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          );

    return IconButton(
      icon: badge,
      tooltip: count > 0 ? 'ข้อความ, $count บทสนทนายังไม่อ่าน' : 'ข้อความ',
      onPressed: _openChatInbox,
    );
  }

  // WYN-073: replaces the bordered/filled SegmentedButton (see the
  // superseded history this comment used to carry, .wyn/docs/design/
  // wyn-073-home-layout-tabs-restyle.md) with plain text tabs + a thin
  // underline indicator, matching design-reference/01-home.tsx's tab
  // style -- but keeping DS-009's approved rainbow-gradient indicator
  // color rather than reverting to the reference's plain sapphire,
  // since that color choice is a separate, still-current Founder
  // decision this task doesn't touch.
  //
  // Still wrapped in `SingleChildScrollView(horizontal)` for the same
  // reason WYN-024 needed it: "จาก Club ของคุณ" doesn't fit next to the
  // other 3 labels on a narrow phone. Unlike the old SegmentedButton,
  // a plain `Row` never forces equal-width segments in the first place
  // (that clamping was `SegmentedButton`-specific), so there's no
  // `IntrinsicWidth` workaround needed here -- each tab just sizes to
  // its own label.
  Widget _buildFeedModeToggle() {
    // WYN-140: shortened from "จาก Club ของคุณ" -- Founder asked for a more
    // compact label. _HomeFeedMode.fromYourClubs itself is unchanged (an
    // internal id, not user-facing text).
    const labels = {
      _HomeFeedMode.forYou: 'สำหรับคุณ',
      _HomeFeedMode.following: 'ติดตาม',
      _HomeFeedMode.fromYourClubs: 'Club',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in _feedModeOrder)
              Padding(
                padding: const EdgeInsets.only(right: WynSpacing.space6),
                child: _buildFeedModeTab(mode, labels[mode]!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedModeTab(_HomeFeedMode mode, String label) {
    final selected = mode == _feedMode;
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = (Theme.of(context).textTheme.bodyMedium ??
            const TextStyle())
        .copyWith(
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
    );

    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => _selectFeedMode(mode),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textStyle,
                ),
                const SizedBox(height: WynSpacing.space1),
                // Reserves the same 2px of height whether selected or
                // not (opacity-only animation), so switching tabs never
                // shifts the row's height -- same approach the old
                // strip indicator used.
                //
                // WYN-140: duration/curve on the shared DS-010 motion
                // tokens (220ms, respects reduced-motion). This toggle
                // row has been through 4 rounds of overflow/wrapping
                // fixes (see WYN-024's history in this file and in
                // home_feed_screen_test.dart); a literal
                // position-tracking sliding indicator remains a
                // follow-up, not this fade -- see PageView's own drag
                // now for the "does it feel like it's really sliding"
                // part of that ask.
                AnimatedOpacity(
                  duration: WynMotion.duration(context, WynMotion.standard),
                  curve: WynMotion.enter,
                  opacity: selected ? 1 : 0,
                  child: Container(
                    key: selected ? const Key('active_segment_accent') : null,
                    height: 2,
                    decoration: const BoxDecoration(
                      gradient: WynColors.rainbowAccent,
                      borderRadius: BorderRadius.all(
                          Radius.circular(WynSpacing.radiusFull)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

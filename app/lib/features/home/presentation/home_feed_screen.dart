import 'package:flutter/material.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/interaction/wyn_motion.dart';
import '../../../core/widgets/wynos_social_chrome.dart';
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

enum _HomeFeedMode { forYou, following, fromYourClubs }

const List<_HomeFeedMode> _feedModeOrder = [
  _HomeFeedMode.forYou,
  _HomeFeedMode.following,
  _HomeFeedMode.fromYourClubs,
];

/// Home stays behaviorally identical to WYN-140 (three independently alive,
/// swipeable feed pages) while its chrome follows the Founder-approved
/// Profile language through shared WYNOS social primitives.
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
  final ChatRepository chatRepository;
  final ValueNotifier<int> homeTabReselectSignal;
  final ValueNotifier<int> homeTabActivatedSignal;

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _forYouKey = GlobalKey<ModeFeedPageState>();
  final _followingKey = GlobalKey<ModeFeedPageState>();

  late final PageController _feedPageController =
      PageController(initialPage: _feedModeOrder.indexOf(_feedMode));

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _loadUnreadChatCount();
    }
  }

  Future<void> _loadUnreadChatCount() async {
    try {
      final results = await Future.wait([
        widget.chatRepository.countUnreadConversations(),
        widget.chatRepository.countPendingMessageRequests(),
      ]);
      if (mounted) setState(() => _unreadChatCount = results[0] + results[1]);
    } catch (_) {
      // A badge refresh failure must never block the Home feed.
    }
  }

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
        child: WynosContentRail(
          child: Column(
            children: [
              _buildHeader(),
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
      ),
    );
  }

  Widget _buildHeader() {
    return WynosSocialHeader(
      title: 'WYNOS',
      leading: IconButton(
        icon: const Icon(Icons.menu, size: 22, color: WynColors.ink),
        tooltip: 'เมนู',
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      titleWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/wynos_logo_mark.png', height: 19),
          const SizedBox(width: WynSpacing.space2),
          Text(
            'WYNOS',
            style: WynTypography.screenTitle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: WynColors.ink,
            ),
          ),
        ],
      ),
      trailing: _buildChatAction(),
    );
  }

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: WynSpacing.space1,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  decoration: BoxDecoration(
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

  Widget _buildFeedModeToggle() {
    return WynosSocialTabs<_HomeFeedMode>(
      selected: _feedMode,
      onSelected: _selectFeedMode,
      scrollable: true,
      items: const [
        WynosSocialTabItem(
          value: _HomeFeedMode.forYou,
          label: 'สำหรับคุณ',
        ),
        WynosSocialTabItem(
          value: _HomeFeedMode.following,
          label: 'ติดตาม',
        ),
        WynosSocialTabItem(
          value: _HomeFeedMode.fromYourClubs,
          label: 'Club',
        ),
      ],
    );
  }
}

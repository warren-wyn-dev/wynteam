import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/developer_access/developer_access_service.dart';
import '../data/club.dart';
import '../data/club_badge_repository.dart';
import '../data/club_channel_chat_repository.dart';
import '../data/club_member.dart';
import '../data/club_post_repository.dart';
import '../data/club_repository.dart';
import '../data/club_event_repository.dart';
import 'edit_club_info_screen.dart';
import 'widgets/club_about_tab.dart';
import 'widgets/club_events_tab.dart';
import 'widgets/club_insights_tab.dart';
import 'widgets/club_members_tab.dart';
import 'widgets/club_posts_tab.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/widgets/action_sheet_row.dart';
import 'club_invite_links_screen.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/shared_content_type.dart';
import '../../chat/presentation/share_sheet.dart';
import '../../follow/data/follow_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../report/data/report_repository.dart';
import '../../report/data/report_target_type.dart';
import '../../report/presentation/report_sheet.dart';
import '../../../core/widgets/network_thumbnail.dart';
import 'widgets/club_avatar.dart';

/// WYN-114 (Tier 1, done + deployed 2026-09-06): real wynos.online
/// domain + a Vercel SPA rewrite so this path no longer 404s at the
/// hosting layer -- see .wyn/tasks/completed/WYN-114-share-link-real-domain.md.
/// WYN-119 (Tier 2, partial): DeepLinkService (app/lib/core/navigation/)
/// now opens this destination directly, but only once RootShell has
/// already mounted -- a guest who has never signed in still lands on
/// Welcome first, not this content. WYN-119's own guest-preview
/// requirement is not met yet; see that task's Known Follow-up.
String clubShareLink(String clubId) => 'https://wynos.online/club/$clubId';

typedef _ClubPageData = ({Club club, ClubMember? membership, bool isMuted});

/// Screen 3-4 — Club Page (header + Posts/Members/About tabs).
/// See .wyn/docs/design/wyn-014-club-core.md, Screens 3-4.
class ClubPage extends StatefulWidget {
  const ClubPage({
    super.key,
    required this.clubRepository,
    required this.clubPostRepository,
    required this.clubId,
    this.initialTabIndex = 0,
    ClubEventRepository? clubEventRepository,
    ClubBadgeRepository? clubBadgeRepository,
    ClubChannelChatRepository? clubChannelChatRepository,
    DeveloperAccessService? developerAccessService,
  })  : _clubEventRepository = clubEventRepository,
        _clubBadgeRepository = clubBadgeRepository,
        _clubChannelChatRepository = clubChannelChatRepository,
        _developerAccessService = developerAccessService;

  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;
  final String clubId;

  // Optional -- same reasoning as CreateClubPostScreen's identical
  // shape (its _profileRepository field): defaults to a real Supabase-
  // backed instance so existing call sites don't need to thread one
  // through, but a test can inject a RecordingClubEventRepository.
  final ClubEventRepository? _clubEventRepository;

  // Same optional shape again -- WYN-129/WYN-128. A widget test that
  // builds ClubPage's Posts tab (all TabBarView children are built
  // eagerly, not lazily, regardless of which tab is selected) must be
  // able to inject a Recording double for both, or ClubPostsTab falls
  // back to a real Supabase-backed repository whose realtime
  // subscribe() attempts a genuine WebSocket connection.
  final ClubBadgeRepository? _clubBadgeRepository;
  final ClubChannelChatRepository? _clubChannelChatRepository;

  /// Staged-rollout gate (`.wyn/company/WORKFLOW.md`'s "Staged Rollout
  /// เป็นค่าเริ่มต้นสำหรับฟีเจอร์ใหม่ทุกตัว") -- threaded down to both
  /// ClubPostsTab (channel switcher/chat toggle) and ClubMembersTab
  /// (badge pill/management), so both tabs agree on the same result
  /// from one shared instance rather than each constructing (and
  /// separately RPC-calling) its own. See
  /// .wyn/tasks/bugs/WYN-127-128-129-missing-staged-rollout-gate.md.
  final DeveloperAccessService? _developerAccessService;

  /// Which tab (Posts=0/Members=1/About=2) opens first -- defaults to
  /// Posts, but WYN-015's club_join_request notification opens straight
  /// to Members (index 1) so the pending request is immediately visible.
  final int initialTabIndex;

  @override
  State<ClubPage> createState() => _ClubPageState();
}

class _ClubPageState extends State<ClubPage> with SingleTickerProviderStateMixin {
  // A plain TabController (not DefaultTabController) because the More
  // menu's "จัดการสิทธิ์สมาชิก" action needs to jump to the Members tab
  // from outside the tab bar itself, and DefaultTabController.of(context)
  // is unreachable from this State's own context (it sits *above* the
  // DefaultTabController this build() would otherwise create, not below).
  //
  // WYN-117: nullable/lazily-(re)created, not `late final` -- whether
  // the 4th (Insights) tab exists depends on `myRole`, which isn't
  // known until `_loadFuture` resolves inside `build()`'s
  // `FutureBuilder`, so the correct `length` can't be picked at
  // `initState()` time the way the old fixed `length: 3` could.
  // [_tabControllerFor] recreates the controller only when the tab
  // count actually changes (carrying the current index over), so a
  // `_reload()` triggered by an unrelated child (e.g. leaving/pinning a
  // post) doesn't reset whichever tab the viewer is looking at. Posts/
  // Members/About stay at indices 0/1/2 regardless -- Insights is only
  // ever appended at the end -- so the More menu's `animateTo(1)` for
  // Members needs no change.
  TabController? _tabController;

  TabController _tabControllerFor(int length) {
    final existing = _tabController;
    if (existing != null && existing.length == length) return existing;
    final initialIndex =
        (existing?.index ?? widget.initialTabIndex).clamp(0, length - 1);
    existing?.dispose();
    final controller =
        TabController(length: length, vsync: this, initialIndex: initialIndex);
    _tabController = controller;
    return controller;
  }

  late Future<_ClubPageData> _loadFuture;
  bool _isJoinActionInFlight = false;
  final _reportRepository = ReportRepository(Supabase.instance.client);
  final _chatRepository = ChatRepository(Supabase.instance.client);
  final _profileRepository = ProfileRepository(Supabase.instance.client);
  final _followRepository = FollowRepository(Supabase.instance.client);
  late final ClubEventRepository _clubEventRepository =
      widget._clubEventRepository ?? ClubEventRepository(Supabase.instance.client);
  late final ClubBadgeRepository _clubBadgeRepository =
      widget._clubBadgeRepository ?? ClubBadgeRepository(Supabase.instance.client);
  late final ClubChannelChatRepository _clubChannelChatRepository =
      widget._clubChannelChatRepository ?? ClubChannelChatRepository(Supabase.instance.client);
  late final DeveloperAccessService _developerAccessService =
      widget._developerAccessService ?? DeveloperAccessService();

  // WYN-130/WYN-125: Staged Rollout gate for the "ลิงก์เชิญ" More-menu
  // row -- same "resolve once, await it wherever gating is needed"
  // shape as ClubPostsTab's own _isDeveloperFuture.
  late final Future<bool> _isDeveloperFuture = _developerAccessService.isDeveloperAccount();

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<_ClubPageData> _load() async {
    final club = await widget.clubRepository.fetchClub(widget.clubId);
    if (club == null) throw StateError('Club not found');
    final membership = await widget.clubRepository.fetchMyMembership(widget.clubId);
    // WYN-116: mute status only matters for an approved member (the More
    // menu's mute row only ever shows for one) -- skip the extra query
    // otherwise rather than asking about a mute that couldn't exist yet
    // (RLS would just return no row anyway, but there's no reason to ask).
    final isMuted = membership?.status == ClubMemberStatus.approved
        ? await widget.clubRepository.isClubMuted(widget.clubId)
        : false;
    return (club: club, membership: membership, isMuted: isMuted);
  }

  // Block body, not `() => _loadFuture = _load()` -- see
  // ViewProfileScreen._reload's identical fix/comment (WYN-081) for why
  // an arrow body here trips setState()'s "returned a Future" assertion.
  void _reload() => setState(() {
        _loadFuture = _load();
      });

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจาก Club?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ออกจาก Club'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _toggleJoin(Club club, ClubMember? membership) async {
    if (_isJoinActionInFlight) return;

    if (membership?.status == ClubMemberStatus.approved) {
      final confirmed = await _confirmLeave();
      if (!confirmed) return;
      await _runJoinAction(
        () => widget.clubRepository.leaveClub(club.id),
        errorMessage: 'ออกจาก Club ไม่สำเร็จ ลองใหม่อีกครั้ง',
      );
      return;
    }

    if (membership?.status == ClubMemberStatus.pending) return;

    await _runJoinAction(
      () => widget.clubRepository.joinClub(club),
      errorMessage: 'เข้าร่วม Club ไม่สำเร็จ ลองใหม่อีกครั้ง',
    );
  }

  Future<void> _cancelRequest(String clubId) async {
    await _runJoinAction(
      () => widget.clubRepository.leaveClub(clubId),
      errorMessage: 'ยกเลิกคำขอไม่สำเร็จ ลองใหม่อีกครั้ง',
    );
  }

  Future<void> _runJoinAction(
    Future<void> Function() action, {
    required String errorMessage,
  }) async {
    setState(() => _isJoinActionInFlight = true);
    try {
      await action();
      _reload();
    } catch (_) {
      if (!mounted) return;
      _showMessage(errorMessage);
    } finally {
      if (mounted) setState(() => _isJoinActionInFlight = false);
    }
  }

  Future<void> _changePrivacy(Club club) async {
    final target =
        club.privacy == ClubPrivacy.public ? ClubPrivacy.private : ClubPrivacy.public;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          target == ClubPrivacy.private
              ? 'เปลี่ยนเป็น Club ส่วนตัว?'
              : 'เปลี่ยนเป็น Club สาธารณะ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('เปลี่ยน'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.clubRepository.updatePrivacy(clubId: club.id, privacy: target);
      _reload();
    } catch (_) {
      if (!mounted) return;
      _showMessage('เปลี่ยนความเป็นส่วนตัวไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  Future<void> _openEditInfo(Club club) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditClubInfoScreen(
          clubRepository: widget.clubRepository,
          club: club,
        ),
      ),
    );
    _reload();
  }

  Future<void> _openShareSheet(Club club) async {
    await showShareSheet(
      context,
      chatRepository: _chatRepository,
      profileRepository: _profileRepository,
      sharedContentType: SharedContentType.club,
      sharedContentId: club.id,
      previewLabel: 'แชร์ Club ${club.name}',
      nativeShareText: clubShareLink(club.id),
      nativeShareTitle: club.name,
      followRepository: _followRepository,
      clubRepository: widget.clubRepository,
      clubName: club.name,
    );
  }

  Future<void> _reportClub(Club club) {
    return showReportSheet(
      context,
      reportRepository: _reportRepository,
      targetType: ReportTargetType.club,
      targetId: club.id,
      targetLabel: 'รายงาน Club "${club.name}"',
    );
  }

  // WYN-116: toggles club_notification_mutes for the current user/Club --
  // scoped to just club_post_new/club_post_pinned, see ClubRepository's
  // own doc comment. Simple reload-after-write (no optimistic flip):
  // this is a "..." menu action, not a feed toggle a user taps rapidly
  // and expects instant visual feedback from.
  Future<void> _toggleMute(String clubId, bool currentlyMuted) async {
    try {
      if (currentlyMuted) {
        await widget.clubRepository.unmuteClubNotifications(clubId);
      } else {
        await widget.clubRepository.muteClubNotifications(clubId);
      }
      _reload();
    } catch (_) {
      if (!mounted) return;
      _showMessage(currentlyMuted
          ? 'เปิดการแจ้งเตือนไม่สำเร็จ ลองใหม่อีกครั้ง'
          : 'ปิดการแจ้งเตือนไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  Future<void> _openMoreMenu(Club club, ClubMember? membership, bool isMuted) async {
    final role = membership?.status == ClubMemberStatus.approved ? membership!.role : null;
    final isApproved = membership?.status == ClubMemberStatus.approved;
    final isPending = membership?.status == ClubMemberStatus.pending;
    // WYN-130/WYN-125 (Staged Rollout): a non-developer account's More
    // menu is byte-for-byte the pre-WYN-130 sheet.
    final isDeveloper = await _isDeveloperFuture;
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        // WYN-116: available to every approved member regardless of
        // role (unlike the role-gated rows below) -- always first when
        // shown, since it's the one row every approved member can act
        // on the same way.
        if (isApproved)
          ActionSheetRow(
            icon: isMuted ? Icons.notifications_outlined : Icons.notifications_off_outlined,
            label: isMuted ? 'เปิดการแจ้งเตือน Club นี้' : 'ปิดการแจ้งเตือน Club นี้',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _toggleMute(club.id, isMuted);
            },
          ),
        if (role != null && role.canManageClub) ...[
          ActionSheetRow(
            icon: Icons.edit_outlined,
            label: 'แก้ไขข้อมูล Club',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _openEditInfo(club);
            },
          ),
          ActionSheetRow(
            icon: Icons.lock_outline,
            label: 'เปลี่ยนความเป็นส่วนตัว',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _changePrivacy(club);
            },
          ),
          ActionSheetRow(
            icon: Icons.people_outline,
            label: 'จัดการสิทธิ์สมาชิก',
            onTap: () {
              Navigator.of(sheetContext).pop();
              // Non-null: this menu is only reachable from build()'s
              // loaded-data branch below, which always calls
              // _tabControllerFor(...) before the More button exists.
              _tabController!.animateTo(1);
            },
          ),
          if (isDeveloper)
            ActionSheetRow(
              icon: Icons.link,
              label: 'ลิงก์เชิญ',
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ClubInviteLinksScreen(
                      club: club,
                      clubRepository: widget.clubRepository,
                    ),
                  ),
                );
              },
            ),
        ] else if (isApproved) ...[
          ActionSheetRow(
            icon: Icons.logout,
            label: 'ออกจาก Club',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _toggleJoin(club, membership);
            },
          ),
          ActionSheetRow(
            icon: Icons.flag_outlined,
            label: 'รายงาน Club',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _reportClub(club);
            },
          ),
        ] else if (isPending) ...[
          ActionSheetRow(
            icon: Icons.close,
            label: 'ยกเลิกคำขอ',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _cancelRequest(club.id);
            },
          ),
          ActionSheetRow(
            icon: Icons.flag_outlined,
            label: 'รายงาน Club',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _reportClub(club);
            },
          ),
        ] else
          ActionSheetRow(
            icon: Icons.flag_outlined,
            label: 'รายงาน Club',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _reportClub(club);
            },
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_ClubPageData>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('โหลด Club ไม่สำเร็จ'),
                        const SizedBox(height: WynSpacing.space3),
                        TextButton(onPressed: _reload, child: const Text('ลองใหม่')),
                      ],
                    ),
                  ),
                  _buildBackButton(),
                ],
              );
            }

            if (!snapshot.hasData) {
              return Stack(
                children: [
                  const Center(child: CircularProgressIndicator()),
                  _buildBackButton(),
                ],
              );
            }

            final data = snapshot.data!;
            final myRole = data.membership?.status == ClubMemberStatus.approved
                ? data.membership!.role
                : null;
            // WYN-118: Events is any-approved-member (same trust model
            // as Posts/Members/About) -- a non-member never sees the
            // tab exists. WYN-117: Insights is owner/admin-only -- a
            // Moderator/Member never even sees the tab exists, same
            // "hide the whole entry point, not just disable it" pattern
            // settings_screen.dart already uses for its own admin-only
            // section. `canManageClub` always implies approved
            // membership, so showInsights can never be true while
            // showEvents is false -- Events (index 3) and Insights
            // (index 4) never swap places.
            final showEvents = myRole != null;
            final showInsights = myRole?.canManageClub ?? false;
            final tabController = _tabControllerFor(
              3 + (showEvents ? 1 : 0) + (showInsights ? 1 : 0),
            );

            return Column(
              children: [
                Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBanner(data.club),
                        _buildHeader(data.club, data.membership, data.isMuted),
                      ],
                    ),
                    _buildBackButton(),
                  ],
                ),
                TabBar(
                  controller: tabController,
                  indicatorColor: WynColors.sapphire,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 2,
                  labelColor: WynColors.ink,
                  unselectedLabelColor: WynColors.mutedNeutral,
                  labelStyle:
                      _textStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle:
                      _textStyle(fontSize: 13, fontWeight: FontWeight.w400),
                  tabs: [
                    const Tab(icon: Icon(Icons.article_outlined, size: 16), text: 'โพสต์'),
                    const Tab(icon: Icon(Icons.people_outline, size: 16), text: 'สมาชิก'),
                    const Tab(icon: Icon(Icons.info_outline, size: 16), text: 'เกี่ยวกับ'),
                    if (showEvents)
                      const Tab(icon: Icon(Icons.event_outlined, size: 16), text: 'กิจกรรม'),
                    if (showInsights)
                      const Tab(icon: Icon(Icons.insights_outlined, size: 16), text: 'Insights'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: tabController,
                    children: [
                      ClubPostsTab(
                        clubPostRepository: widget.clubPostRepository,
                        clubRepository: widget.clubRepository,
                        clubBadgeRepository: _clubBadgeRepository,
                        clubChannelChatRepository: _clubChannelChatRepository,
                        developerAccessService: _developerAccessService,
                        club: data.club,
                        myRole: myRole,
                        onJoinTapped: () => _toggleJoin(data.club, data.membership),
                        onBanned: _reload,
                      ),
                      ClubMembersTab(
                        clubRepository: widget.clubRepository,
                        clubBadgeRepository: _clubBadgeRepository,
                        developerAccessService: _developerAccessService,
                        club: data.club,
                        myRole: myRole,
                        onChanged: _reload,
                        onInvite: () => _openShareSheet(data.club),
                      ),
                      ClubAboutTab(
                        clubRepository: widget.clubRepository,
                        club: data.club,
                        myRole: myRole,
                        onChanged: _reload,
                      ),
                      if (showEvents)
                        ClubEventsTab(
                          clubEventRepository: _clubEventRepository,
                          clubId: data.club.id,
                          canManage: myRole.canModeratePosts,
                        ),
                      if (showInsights)
                        ClubInsightsTab(
                          clubRepository: widget.clubRepository,
                          club: data.club,
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 08-club.tsx's floating back-chevron over the banner (semi-
  /// transparent paper circle) -- shown in every load state (error/
  /// loading/loaded) so the screen never strands the viewer without a
  /// way back, unlike the reference's own single always-loaded mock.
  Widget _buildBackButton() {
    return Positioned(
      left: WynSpacing.space2,
      top: WynSpacing.space2,
      child: Material(
        color: WynColors.paper.withValues(alpha: 0.8),
        shape: const CircleBorder(),
        child: IconButton(
          icon: const Icon(Icons.chevron_left, color: WynColors.ink),
          tooltip: 'ย้อนกลับ',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// The Club's banner -- Beta4 §8.3, "Club Identity Image".
  ///
  /// ## What changed, and why it is not a revert
  ///
  /// Beta3 (Founder, 2026-09-03) removed the uploaded image from this
  /// strip and left only a generated ink+sapphire background. The
  /// reason it was removed is on the record and was a good one: the
  /// banner *swapped* between two unrelated designs depending on
  /// whether the owner happened to have picked a photo, **and the
  /// Club's own name disappeared from the banner in the case where
  /// they had** -- the name was drawn only on the generated variant.
  ///
  /// Beta4 §8.3 asks for the identity image back on this page. So it is
  /// back, with the actual defect fixed rather than reintroduced: the
  /// image is a *background layer* under the same "CLUB" eyebrow and
  /// Club name that the generated variant draws, over a scrim heavy
  /// enough to keep them legible on any photograph. There is now one
  /// banner design, not two: same height, same type, same position, in
  /// both cases. The photo changes what is behind the name; it never
  /// replaces it.
  ///
  /// The generated ink+sapphire gradient stays as the no-image case --
  /// it is what a Club without a picture still looks like, and it is
  /// also what shows underneath while a photo is loading, so the strip
  /// never flashes empty.
  Widget _buildBanner(Club club) {
    final imageUrl = club.identityImageUrl;
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          // Layer 1 -- the generated background. Always painted, so it
          // is both the no-image design and the placeholder behind a
          // loading photo.
          Container(
            color: WynColors.ink,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -80,
                  top: -100,
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [WynColors.sapphire, Colors.transparent],
                        stops: [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Layer 2 -- the identity image, when there is one.
          // NetworkThumbnail bounds the decode to the strip's real size
          // (Beta4 §7): the source is a 1600px upload and this box is
          // 140px tall, and it also carries the neutral placeholder and
          // broken-image fallback a bare Image.network has none of.
          if (imageUrl != null)
            NetworkThumbnail(imageUrl: imageUrl, key: const Key('club_banner_image')),
          // Layer 3 -- the scrim, only where there is a photo to darken.
          // A left-to-right gradient rather than a flat wash: the text
          // is left-aligned, so the right side of the photo stays as
          // close to unobscured as legibility allows.
          if (imageUrl != null)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [WynColors.imageScrimStrong, WynColors.imageScrim],
                ),
              ),
            ),
          // Layer 4 -- the Club's identity in words. Drawn in both
          // cases, which is the whole point (see the doc comment).
          Positioned(
            left: WynSpacing.space6,
            right: WynSpacing.space6,
            top: 0,
            bottom: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CLUB',
                    style: _textStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: WynColors.mutedNeutral,
                      letterSpacing: 13 * 0.14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    club.name,
                    // Two lines, then ellipsis: a 50-character Club name
                    // (the column's own limit) does not fit on one line
                    // at 22px on a small phone, and the old single-line
                    // Text had nothing to stop it overflowing the strip.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: WynTypography.screenTitle(fontSize: 22, color: WynColors.paper),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 14, color: WynColors.ink),
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          side: const BorderSide(color: WynColors.hairline),
          shape: const CircleBorder(),
        ),
      ),
    );
  }

  Widget _buildHeader(Club club, ClubMember? membership, bool isMuted) {
    final status = membership?.status;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space6, WynSpacing.space4, WynSpacing.space6, WynSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Beta4 §7/§22: the shared [ClubAvatar], the same widget
              // every other Club surface uses -- see its doc comment
              // for the three defects the five hand-rolled copies
              // shared.
              ClubAvatar(club: club, radius: 18, ring: true),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: WynSpacing.space1),
                  child: Text(
                    club.name,
                    style: _textStyle(fontSize: 16, fontWeight: FontWeight.w700, color: WynColors.ink),
                  ),
                ),
              ),
              const SizedBox(width: WynSpacing.space2),
              _buildCircleIconButton(
                icon: Icons.share_outlined,
                tooltip: 'แชร์',
                onPressed: () => _openShareSheet(club),
              ),
              const SizedBox(width: WynSpacing.space2),
              _buildCircleIconButton(
                icon: Icons.more_vert,
                tooltip: 'เพิ่มเติม',
                onPressed: () => _openMoreMenu(club, membership, isMuted),
              ),
            ],
          ),
          const SizedBox(height: WynSpacing.space2),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: WynSpacing.space2,
            runSpacing: WynSpacing.space1,
            children: [
              Text(
                '${club.memberCount} สมาชิก',
                style: _textStyle(fontSize: 13, color: WynColors.graphite),
              ),
              if (club.category != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2, vertical: 2),
                  decoration: BoxDecoration(
                    color: WynColors.hairline,
                    borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                  ),
                  child: Text(
                    club.category!,
                    style: _textStyle(fontSize: 13, color: WynColors.graphite),
                  ),
                ),
              if (status != null) _buildJoinButton(club, membership),
            ],
          ),
          if (club.description != null && club.description!.isNotEmpty) ...[
            const SizedBox(height: WynSpacing.space3),
            Text(
              club.description!,
              style: _textStyle(fontSize: 15, color: WynColors.ink, height: 1.45),
            ),
          ],
          if (status == null) ...[
            const SizedBox(height: WynSpacing.space4),
            SizedBox(width: double.infinity, child: _buildJoinButton(club, membership)),
          ],
        ],
      ),
    );
  }

  Widget _buildJoinButton(Club club, ClubMember? membership) {
    final status = membership?.status;

    String label;
    String semanticsLabel;
    VoidCallback? onPressed;

    if (status == ClubMemberStatus.approved) {
      label = 'เข้าร่วมแล้ว';
      semanticsLabel = 'เข้าร่วมแล้ว กดเพื่อออกจาก Club';
      onPressed = _isJoinActionInFlight ? null : () => _toggleJoin(club, membership);
    } else if (status == ClubMemberStatus.pending) {
      label = 'รออนุมัติ';
      semanticsLabel = 'ส่งคำขอเข้าร่วมแล้ว รอการอนุมัติ';
      onPressed = null;
    } else {
      label = 'เข้าร่วม';
      semanticsLabel = 'กดเพื่อเข้าร่วม';
      onPressed = _isJoinActionInFlight ? null : () => _toggleJoin(club, membership);
    }

    // "เข้าร่วม" (not a member yet) is the page's single most important
    // action -- elevated to a filled sapphire pill button (08-club.tsx's
    // own full-width "เข้าร่วม" CTA) instead of the same OutlinedButton
    // style as every other secondary action. "เข้าร่วมแล้ว"/"รออนุมัติ"
    // stay OutlinedButton, restyled as a small pill chip (08-club.tsx's
    // own "เข้าร่วมแล้ว" chip inline with the member count) -- they're
    // not actions worth drawing the eye to anymore. See
    // .wyn/docs/design/wyn-057-058-club-create-and-page-visual-polish.md,
    // Screen 2.
    final isPrimaryAction = status == null;
    final button = isPrimaryAction
        ? FilledButton(
            key: const Key('club-header-join-button'),
            style: FilledButton.styleFrom(
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),
              backgroundColor: WynColors.sapphire,
              foregroundColor: WynColors.paper,
              textStyle: _textStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            onPressed: onPressed,
            child: Text(label),
          )
        : OutlinedButton(
            key: const Key('club-header-join-button'),
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: 2),
              foregroundColor: Theme.of(context).colorScheme.outline,
              side: BorderSide(color: Theme.of(context).colorScheme.outline),
              textStyle: _textStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            child: status == ClubMemberStatus.approved
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check, size: 11),
                      const SizedBox(width: 4),
                      Text(label),
                    ],
                  )
                : Text(label),
          );

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: button,
    );
  }
}

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? height,
  double? letterSpacing,
}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

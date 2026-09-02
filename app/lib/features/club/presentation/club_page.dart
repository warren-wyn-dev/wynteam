import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/club.dart';
import '../data/club_member.dart';
import '../data/club_post_repository.dart';
import '../data/club_repository.dart';
import 'edit_club_info_screen.dart';
import 'widgets/club_about_tab.dart';
import 'widgets/club_members_tab.dart';
import 'widgets/club_posts_tab.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/widgets/action_sheet_row.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/shared_content_type.dart';
import '../../chat/presentation/share_sheet.dart';
import '../../profile/data/profile_repository.dart';
import '../../report/data/report_repository.dart';
import '../../report/data/report_target_type.dart';
import '../../report/presentation/report_sheet.dart';

/// Placeholder share link -- same "no real hosting/domain yet" caveat as
/// dropShareLink/popShareLink (WYN-005/006).
String clubShareLink(String clubId) => 'https://wyn.app/club/$clubId';

typedef _ClubPageData = ({Club club, ClubMember? membership});

/// Screen 3-4 — Club Page (header + Posts/Members/About tabs).
/// See .wyn/docs/design/wyn-014-club-core.md, Screens 3-4.
class ClubPage extends StatefulWidget {
  const ClubPage({
    super.key,
    required this.clubRepository,
    required this.clubPostRepository,
    required this.clubId,
    this.initialTabIndex = 0,
  });

  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;
  final String clubId;

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
  late final _tabController = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.initialTabIndex,
  );

  late Future<_ClubPageData> _loadFuture;
  bool _isJoinActionInFlight = false;
  final _reportRepository = ReportRepository(Supabase.instance.client);
  final _chatRepository = ChatRepository(Supabase.instance.client);
  final _profileRepository = ProfileRepository(Supabase.instance.client);

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<_ClubPageData> _load() async {
    final club = await widget.clubRepository.fetchClub(widget.clubId);
    if (club == null) throw StateError('Club not found');
    final membership = await widget.clubRepository.fetchMyMembership(widget.clubId);
    return (club: club, membership: membership);
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

  Future<void> _openMoreMenu(Club club, ClubMember? membership) async {
    final role = membership?.status == ClubMemberStatus.approved ? membership!.role : null;
    final isApproved = membership?.status == ClubMemberStatus.approved;
    final isPending = membership?.status == ClubMemberStatus.pending;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
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
              _tabController.animateTo(1);
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

            return Column(
              children: [
                Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBanner(data.club),
                        _buildHeader(data.club, data.membership),
                      ],
                    ),
                    _buildBackButton(),
                  ],
                ),
                TabBar(
                  controller: _tabController,
                  indicatorColor: WynColors.sapphire,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 2,
                  labelColor: WynColors.ink,
                  unselectedLabelColor: WynColors.mutedNeutral,
                  labelStyle:
                      _textStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle:
                      _textStyle(fontSize: 13, fontWeight: FontWeight.w400),
                  tabs: const [
                    Tab(icon: Icon(Icons.article_outlined, size: 16), text: 'โพสต์'),
                    Tab(icon: Icon(Icons.people_outline, size: 16), text: 'สมาชิก'),
                    Tab(icon: Icon(Icons.info_outline, size: 16), text: 'เกี่ยวกับ'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ClubPostsTab(
                        clubPostRepository: widget.clubPostRepository,
                        club: data.club,
                        myRole: myRole,
                        onJoinTapped: () => _toggleJoin(data.club, data.membership),
                      ),
                      ClubMembersTab(
                        clubRepository: widget.clubRepository,
                        club: data.club,
                        myRole: myRole,
                        onChanged: _reload,
                      ),
                      ClubAboutTab(
                        clubRepository: widget.clubRepository,
                        club: data.club,
                        myRole: myRole,
                        onChanged: _reload,
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

  /// 08-club.tsx: "The reference banner is a composited marketing
  /// screenshot ... not something to recreate pixel-for-pixel. Replaced
  /// with an original ink+sapphire abstract banner carrying just the
  /// Club name in the title style." A real uploaded [Club.coverUrl] still
  /// shows as-is when present -- the reference's own reasoning is about
  /// replacing a placeholder marketing asset, not hiding a real photo
  /// the Club's owner actually uploaded via CreateClubScreen's cover
  /// picker.
  Widget _buildBanner(Club club) {
    if (club.coverUrl != null) {
      return SizedBox(
        height: 140,
        width: double.infinity,
        child: Image.network(club.coverUrl!, fit: BoxFit.cover),
      );
    }

    return Container(
      height: 140,
      width: double.infinity,
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
          Positioned(
            left: WynSpacing.space6,
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

  Widget _buildHeader(Club club, ClubMember? membership) {
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
              AvatarCircle(
                imageUrl: club.iconUrl,
                fallbackText: club.name,
                radius: 18,
                ring: true,
              ),
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
                onPressed: () => _openMoreMenu(club, membership),
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

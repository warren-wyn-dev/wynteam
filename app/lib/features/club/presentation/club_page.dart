import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/club.dart';
import '../data/club_member.dart';
import '../data/club_post_repository.dart';
import '../data/club_repository.dart';
import 'edit_club_info_screen.dart';
import 'widgets/club_about_tab.dart';
import 'widgets/club_members_tab.dart';
import 'widgets/club_posts_tab.dart';
import '../../../core/design/wyn_spacing.dart';

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

  void _reload() => setState(() => _loadFuture = _load());

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

  Future<void> _share(Club club) async {
    await SharePlus.instance.share(
      ShareParams(text: clubShareLink(club.id), title: club.name),
    );
  }

  Future<void> _openMoreMenu(Club club, ClubMember? membership) async {
    final role = membership?.status == ClubMemberStatus.approved ? membership!.role : null;
    final isApproved = membership?.status == ClubMemberStatus.approved;
    final isPending = membership?.status == ClubMemberStatus.pending;

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            if (role != null && role.canManageClub) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('แก้ไขข้อมูล Club'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openEditInfo(club);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('เปลี่ยนความเป็นส่วนตัว'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _changePrivacy(club);
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('จัดการสิทธิ์สมาชิก'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _tabController.animateTo(1);
                },
              ),
            ] else if (isApproved) ...[
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('ออกจาก Club'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _toggleJoin(club, membership);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('รายงาน Club'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showMessage('ฟีเจอร์นี้จะมาเร็ว ๆ นี้');
                },
              ),
            ] else if (isPending) ...[
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('ยกเลิกคำขอ'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _cancelRequest(club.id);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('รายงาน Club'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showMessage('ฟีเจอร์นี้จะมาเร็ว ๆ นี้');
                },
              ),
            ] else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('รายงาน Club'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showMessage('ฟีเจอร์นี้จะมาเร็ว ๆ นี้');
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Club')),
      body: FutureBuilder<_ClubPageData>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('โหลด Club ไม่สำเร็จ'),
                  const SizedBox(height: WynSpacing.space3),
                  TextButton(onPressed: _reload, child: const Text('ลองใหม่')),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final myRole = data.membership?.status == ClubMemberStatus.approved
              ? data.membership!.role
              : null;

          return Column(
            children: [
              _buildHeader(data.club, data.membership),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.article_outlined), text: 'โพสต์'),
                  Tab(icon: Icon(Icons.people_outline), text: 'สมาชิก'),
                  Tab(icon: Icon(Icons.info_outline), text: 'เกี่ยวกับ'),
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
    );
  }

  Widget _buildHeader(Club club, ClubMember? membership) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // A fixed height cap (not AspectRatio at full device width)
              // per the Design spec -- "cover เป็นการ์ดมุมมนความสูงจำกัด
              // ... ไม่ใช่เต็มความกว้างจอทะลุขอบแบบ FB" (a limited-height
              // rounded card, not an FB-style edge-to-edge hero that
              // scales with screen width).
              ClipRRect(
                borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: club.coverUrl != null
                      ? Image.network(club.coverUrl!, fit: BoxFit.cover)
                      : Container(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: -24,
                child: CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage:
                        club.iconUrl != null ? NetworkImage(club.iconUrl!) : null,
                    child: club.iconUrl == null
                        ? Text(
                            club.name.isNotEmpty ? club.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: WynSpacing.space8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(club.name, style: Theme.of(context).textTheme.headlineSmall),
              ),
              if (club.category != null) ...[
                const SizedBox(width: WynSpacing.space2),
                Chip(
                  label: Text(club.category!),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          if (club.description != null && club.description!.isNotEmpty) ...[
            const SizedBox(height: WynSpacing.space1),
            Text(club.description!, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: WynSpacing.space2),
          Text(
            '${club.memberCount} สมาชิก',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: WynSpacing.space3),
          Row(
            children: [
              _buildJoinButton(club, membership),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'แชร์',
                onPressed: () => _share(club),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                tooltip: 'เพิ่มเติม',
                onPressed: () => _openMoreMenu(club, membership),
              ),
            ],
          ),
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

    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: OutlinedButton(
        key: const Key('club-header-join-button'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: status == ClubMemberStatus.approved
              ? Theme.of(context).colorScheme.outline
              : Theme.of(context).colorScheme.primary,
          side: BorderSide(
            color: status == ClubMemberStatus.approved
                ? Theme.of(context).colorScheme.outline
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

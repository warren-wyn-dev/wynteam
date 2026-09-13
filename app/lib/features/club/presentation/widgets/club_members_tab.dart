import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/club.dart';
import '../../data/club_badge_repository.dart';
import '../../data/club_member.dart';
import '../../data/club_member_badge.dart';
import '../../data/club_repository.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/action_sheet_row.dart';
import 'club_badge_pill.dart';

/// Screen 6 — Members tab. Reuses FollowListScreen's row shape (WYN-008/
/// 013) plus a role badge and, for Owner/Admin, a pending-requests
/// section and a role-gated overflow menu per row.
/// See .wyn/docs/design/wyn-014-club-core.md, Screen 6.
class ClubMembersTab extends StatefulWidget {
  const ClubMembersTab({
    super.key,
    required this.clubRepository,
    required this.club,
    required this.myRole,
    required this.onChanged,
    required this.onInvite,
    ClubBadgeRepository? clubBadgeRepository,
  }) : _clubBadgeRepository = clubBadgeRepository;

  final ClubRepository clubRepository;
  final Club club;
  final ClubMemberRole? myRole;
  final VoidCallback onChanged;

  /// WYN-129: optional, same defaulted-to-a-real-instance shape as every
  /// other optional repository field in this app -- see
  /// ClubBadgeRepository's own doc comment for why this is a repository
  /// of its own rather than a method group on [clubRepository].
  final ClubBadgeRepository? _clubBadgeRepository;

  /// Opens the same share-to-chat flow ClubPage's own "แชร์" header
  /// button already uses (ShareToChatScreen, SharedContentType.club) --
  /// inviting someone to a Club and sending them its shareable card are
  /// the same real action, so this reuses that flow rather than a
  /// separate one. Founder request: a Club should have "ปุ่มเชิญคนอื่น
  /// เข้ากลุ่ม" (an invite-others button).
  final VoidCallback onInvite;

  @override
  State<ClubMembersTab> createState() => _ClubMembersTabState();
}

class _ClubMembersTabState extends State<ClubMembersTab> {
  late final ClubBadgeRepository _clubBadgeRepository =
      widget._clubBadgeRepository ??
          ClubBadgeRepository(Supabase.instance.client);

  List<ClubMember>? _approved;
  List<ClubMember>? _pending;

  /// WYN-129: every badge in this Club, keyed by user id -- fetched
  /// alongside the member lists (below) and re-fetched on set/remove so
  /// the pill appears/disappears immediately without a full reload.
  Map<String, ClubMemberBadge> _badges = {};

  /// Member-list pagination -- see ClubRepository.fetchApprovedMembers.
  /// A full page back means there may be more behind it.
  int _memberPage = 0;
  bool _hasMoreMembers = false;
  bool _isLoadingMoreMembers = false;
  bool _errored = false;

  bool get _canManage => widget.myRole?.canManageClub ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _approved = null;
      _pending = null;
      _errored = false;
      _memberPage = 0;
      _hasMoreMembers = false;
    });
    try {
      // Issued together (not Future.wait -- badgesFuture's type differs
      // from the member-list futures, and mixing them into one
      // heterogeneous list loses static typing for no benefit): neither
      // depends on another, and awaiting them in sequence just tripled
      // the tab's time to first paint.
      final approvedFuture =
          widget.clubRepository.fetchApprovedMembers(widget.club.id);
      final pendingFuture = _canManage
          ? widget.clubRepository.fetchPendingMembers(widget.club.id)
          : Future.value(<ClubMember>[]);
      // Fails open to an empty map -- a badge-fetch hiccup shouldn't hide
      // the entire Members list behind this tab's error state; it just
      // means no pill shows until the next reload.
      final badgesFuture = _clubBadgeRepository
          .fetchBadges(widget.club.id)
          .catchError((_) => <String, ClubMemberBadge>{});
      final approved = await approvedFuture;
      final pending = await pendingFuture;
      final badges = await badgesFuture;
      if (!mounted) return;
      setState(() {
        _approved = approved;
        _pending = pending;
        _badges = badges;
        _hasMoreMembers = approved.length == ClubRepository.memberPageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errored = true);
    }
  }

  /// Appends the next page of approved members. Explicit button rather
  /// than infinite scroll, matching how comments page elsewhere in the
  /// app -- a membership list is something you scan, not a feed.
  Future<void> _loadMoreMembers() async {
    if (_isLoadingMoreMembers) return;
    setState(() => _isLoadingMoreMembers = true);
    try {
      final nextPage = _memberPage + 1;
      final more = await widget.clubRepository
          .fetchApprovedMembers(widget.club.id, page: nextPage);
      if (!mounted) return;
      setState(() {
        _approved = [...?_approved, ...more];
        _memberPage = nextPage;
        _hasMoreMembers = more.length == ClubRepository.memberPageSize;
      });
    } catch (_) {
      // Leaves the button in place so the user can simply tap again --
      // nothing already loaded is lost.
    } finally {
      if (mounted) setState(() => _isLoadingMoreMembers = false);
    }
  }

  Future<bool> _confirm(String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: BrowserSystemText(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const BrowserSystemText('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const BrowserSystemText('ยืนยัน'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: BrowserSystemText(message)));
  }

  Future<void> _approve(ClubMember member) async {
    try {
      await widget.clubRepository
          .approveMember(clubId: widget.club.id, userId: member.userId);
      _load();
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      _showError('อนุมัติไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  Future<void> _reject(ClubMember member) async {
    try {
      await widget.clubRepository
          .rejectMember(clubId: widget.club.id, userId: member.userId);
      _load();
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      _showError('ปฏิเสธไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  Future<void> _setRole(ClubMember member, ClubMemberRole role) async {
    try {
      await widget.clubRepository.setMemberRole(
          clubId: widget.club.id, userId: member.userId, role: role);
      _load();
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      _showError('เปลี่ยนตำแหน่งไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  Future<void> _remove(ClubMember member) async {
    if (!await _confirm('ลบ ${member.nameOrUsername} ออกจาก Club?')) return;
    try {
      await widget.clubRepository
          .removeMember(clubId: widget.club.id, userId: member.userId);
      _load();
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      _showError('ลบสมาชิกไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  Future<void> _ban(ClubMember member) async {
    if (!await _confirm('แบน ${member.nameOrUsername}?')) return;
    try {
      await widget.clubRepository
          .banMember(clubId: widget.club.id, userId: member.userId);
      _load();
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      _showError('แบนไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  // WYN-129 -- badge set/remove. Deliberately calls _clubBadgeRepository
  // directly, never widget.clubRepository/club_role() -- see
  // ClubBadgeRepository's own doc comment for why that separation
  // matters.
  Future<void> _setBadge(ClubMember member) async {
    final existing = _badges[member.userId];
    final result = await showSetClubBadgeDialog(
      context,
      initialLabel: existing?.label ?? '',
      initialColor: existing?.colorKey ?? ClubBadgeColor.gold,
    );
    if (result == null) return;
    final (label, color) = result;
    try {
      await _clubBadgeRepository.setBadge(
        clubId: widget.club.id,
        userId: member.userId,
        label: label,
        color: color,
      );
      if (!mounted) return;
      setState(() {
        _badges = {
          ..._badges,
          member.userId: ClubMemberBadge(
            clubId: widget.club.id,
            userId: member.userId,
            label: label,
            colorKey: color,
            createdBy: Supabase.instance.client.auth.currentUser!.id,
            createdAt: DateTime.now(),
          ),
        };
      });
    } catch (_) {
      if (!mounted) return;
      _showError('ตั้งป้ายไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  Future<void> _removeBadge(ClubMember member) async {
    try {
      await _clubBadgeRepository.removeBadge(
          clubId: widget.club.id, userId: member.userId);
      if (!mounted) return;
      setState(() {
        _badges = {..._badges}..remove(member.userId);
      });
    } catch (_) {
      if (!mounted) return;
      _showError('ถอดป้ายไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  Future<void> _openBadgeMenu(ClubMember member) async {
    final hasBadge = _badges.containsKey(member.userId);
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        ActionSheetRow(
          icon: Icons.local_offer_outlined,
          label: hasBadge ? 'แก้ไขป้าย' : 'ตั้งป้าย',
          onTap: () {
            Navigator.of(sheetContext).pop();
            _setBadge(member);
          },
        ),
        if (hasBadge)
          ActionSheetRow(
            icon: Icons.remove_circle_outline,
            label: 'ถอดป้าย',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _removeBadge(member);
            },
          ),
      ]),
    );
  }

  /// Mirrors the RPC permission boundaries in supabase/schema.sql exactly
  /// (approve/reject/set_club_member_role/remove_club_member/
  /// ban_club_member) -- Owner acts on any non-owner; Admin acts on
  /// Moderator/Member only (never other Admins, never grants Admin);
  /// Moderator acts on plain Members only, and never changes roles.
  List<_MemberAction> _actionsFor(ClubMember member) {
    final viewer = widget.myRole;
    if (viewer == null) return const [];
    if (member.role == ClubMemberRole.owner) return const [];
    if (member.userId == Supabase.instance.client.auth.currentUser!.id) {
      return const [];
    }

    if (viewer == ClubMemberRole.owner) {
      return [
        if (member.role != ClubMemberRole.admin)
          _MemberAction(
              'ตั้งเป็น Admin', () => _setRole(member, ClubMemberRole.admin)),
        if (member.role != ClubMemberRole.moderator)
          _MemberAction('ตั้งเป็น Moderator',
              () => _setRole(member, ClubMemberRole.moderator)),
        if (member.role != ClubMemberRole.member)
          _MemberAction('ตั้งเป็นสมาชิกทั่วไป',
              () => _setRole(member, ClubMemberRole.member)),
        _MemberAction('ลบออกจาก Club', () => _remove(member)),
        _MemberAction('แบน', () => _ban(member)),
      ];
    }

    if (viewer == ClubMemberRole.admin && member.role != ClubMemberRole.admin) {
      return [
        if (member.role != ClubMemberRole.moderator)
          _MemberAction('ตั้งเป็น Moderator',
              () => _setRole(member, ClubMemberRole.moderator)),
        if (member.role != ClubMemberRole.member)
          _MemberAction('ตั้งเป็นสมาชิกทั่วไป',
              () => _setRole(member, ClubMemberRole.member)),
        _MemberAction('ลบออกจาก Club', () => _remove(member)),
        _MemberAction('แบน', () => _ban(member)),
      ];
    }

    if (viewer == ClubMemberRole.moderator &&
        member.role == ClubMemberRole.member) {
      return [
        _MemberAction('ลบออกจาก Club', () => _remove(member)),
        _MemberAction('แบน', () => _ban(member)),
      ];
    }

    return const [];
  }

  String _roleLabel(ClubMemberRole role) {
    switch (role) {
      case ClubMemberRole.owner:
        return 'Owner';
      case ClubMemberRole.admin:
        return 'Admin';
      case ClubMemberRole.moderator:
        return 'Moderator';
      case ClubMemberRole.member:
        return '';
    }
  }

  Widget? _buildRoleBadge(BuildContext context, ClubMemberRole role) {
    if (role == ClubMemberRole.member) return null;
    final scheme = Theme.of(context).colorScheme;
    final Color color;
    switch (role) {
      case ClubMemberRole.owner:
        color = scheme.primary;
      case ClubMemberRole.admin:
        color = scheme.primary.withValues(alpha: 0.5);
      case ClubMemberRole.moderator:
      case ClubMemberRole.member:
        color = scheme.outline;
    }
    return Chip(
      label: BrowserSystemText(
        _roleLabel(role),
        style: TextStyle(color: scheme.onPrimary, fontSize: 13),
      ),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_errored) {
      // Same RefreshIndicator/AlwaysScrollableScrollPhysics fix as
      // club_posts_tab.dart's empty/error states -- a bare Center() has
      // no scrollable ancestor, so pull-to-refresh couldn't even be
      // triggered from this state before.
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: WynSpacing.space8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrowserSystemText('โหลดรายชื่อสมาชิกไม่สำเร็จ'),
                    const SizedBox(height: WynSpacing.space3),
                    TextButton(
                        onPressed: _load,
                        child: const BrowserSystemText('ลองใหม่')),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final approved = _approved;
    final pending = _pending;
    if (approved == null || pending == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // CustomScrollView (not ListView), same reasoning as
    // club_insights_tab.dart's identical comment -- participates
    // correctly in ClubPage's NestedScrollView layout's shared
    // header-collapse scroll position.
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              // Only an approved member can invite -- there is nothing to
              // invite people *into* from outside the Club, and a non-member
              // never reaches this tab's real content in the first place
              // (see ClubPage's role gating).
              if (widget.myRole != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(WynSpacing.space4,
                      WynSpacing.space4, WynSpacing.space4, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onInvite,
                      icon: const Icon(Icons.person_add_alt_outlined),
                      label: const BrowserSystemText('เชิญเพื่อน'),
                    ),
                  ),
                ),
              if (pending.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: BrowserSystemText(
                    'คำขอเข้าร่วม (${pending.length})',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                ...pending.map((member) => _buildPendingRow(member)),
                const Divider(),
              ],
              ...approved.map((member) => _buildApprovedRow(member)),
              if (_hasMoreMembers)
                Padding(
                  padding: const EdgeInsets.all(WynSpacing.space4),
                  child: Center(
                    child: _isLoadingMoreMembers
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            key: const Key('club_load_more_members'),
                            onPressed: _loadMoreMembers,
                            child: const BrowserSystemText('ดูสมาชิกเพิ่มเติม'),
                          ),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRow(ClubMember member) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
      child: Row(
        children: [
          AvatarCircle(
            imageUrl: member.avatarUrl,
            fallbackText: member.username,
            radius: 20,
          ),
          const SizedBox(width: WynSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrowserSystemText(member.nameOrUsername,
                    style: Theme.of(context).textTheme.titleSmall),
                BrowserSystemText(
                  '@${member.username}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          TextButton(
              onPressed: () => _approve(member),
              child: const BrowserSystemText('อนุมัติ')),
          TextButton(
              onPressed: () => _reject(member),
              child: const BrowserSystemText('ปฏิเสธ')),
        ],
      ),
    );
  }

  Widget _buildApprovedRow(ClubMember member) {
    final actions = _actionsFor(member);
    final roleBadge = _buildRoleBadge(context, member.role);
    final memberBadge = _badges[member.userId];

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
      child: Row(
        children: [
          AvatarCircle(
            imageUrl: member.avatarUrl,
            fallbackText: member.username,
            radius: 20,
          ),
          const SizedBox(width: WynSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrowserSystemText(member.nameOrUsername,
                    style: Theme.of(context).textTheme.titleSmall),
                BrowserSystemText(
                  '@${member.username}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          // WYN-129: badge pill sits next to the role chip, never
          // replacing it (Design Rules) -- Wrap (not a plain Row child)
          // so a long role+badge pair can drop to a second line instead
          // of clipping (Responsive Behavior: "ห้าม clip ข้อความ badge").
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: WynSpacing.space1,
            runSpacing: WynSpacing.space1,
            children: [
              if (roleBadge != null) roleBadge,
              if (memberBadge != null) ClubBadgePill(badge: memberBadge),
            ],
          ),
          // WYN-129: a distinct affordance from the role PopupMenuButton
          // below (own icon/key), Owner/Admin only -- keeps this
          // cosmetic action fully separate from the role-permission menu
          // (and its own "no menu on own/Owner row" rule) rather than
          // merging the two into one "..." button.
          if (_canManage)
            BrowserSystemTooltip(
                message: memberBadge != null ? 'จัดการป้าย' : 'ตั้งป้าย',
                child: IconButton(
                  key: ValueKey('member-badge-menu-${member.userId}'),
                  icon: const Icon(Icons.local_offer_outlined, size: 18),
                  onPressed: () => _openBadgeMenu(member),
                )),
          if (actions.isNotEmpty)
            PopupMenuButton<_MemberAction>(
              key: ValueKey('member-menu-${member.userId}'),
              onSelected: (action) => action.onSelected(),
              itemBuilder: (context) => actions
                  .map((action) => PopupMenuItem(
                      value: action, child: BrowserSystemText(action.label)))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _MemberAction {
  const _MemberAction(this.label, this.onSelected);
  final String label;
  final VoidCallback onSelected;
}

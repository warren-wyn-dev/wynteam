import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../profile/presentation/widgets/avatar_circle.dart';
import '../../data/club.dart';
import '../../data/club_member.dart';
import '../../data/club_repository.dart';
import '../../../../core/design/wyn_spacing.dart';

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
  });

  final ClubRepository clubRepository;
  final Club club;
  final ClubMemberRole? myRole;
  final VoidCallback onChanged;

  @override
  State<ClubMembersTab> createState() => _ClubMembersTabState();
}

class _ClubMembersTabState extends State<ClubMembersTab> {
  List<ClubMember>? _approved;
  List<ClubMember>? _pending;
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
    });
    try {
      final approved = await widget.clubRepository.fetchApprovedMembers(widget.club.id);
      final pending =
          _canManage ? await widget.clubRepository.fetchPendingMembers(widget.club.id) : <ClubMember>[];
      if (!mounted) return;
      setState(() {
        _approved = approved;
        _pending = pending;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errored = true);
    }
  }

  Future<bool> _confirm(String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _approve(ClubMember member) async {
    try {
      await widget.clubRepository.approveMember(clubId: widget.club.id, userId: member.userId);
      _load();
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      _showError('อนุมัติไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  Future<void> _reject(ClubMember member) async {
    try {
      await widget.clubRepository.rejectMember(clubId: widget.club.id, userId: member.userId);
      _load();
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      _showError('ปฏิเสธไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  Future<void> _setRole(ClubMember member, ClubMemberRole role) async {
    try {
      await widget.clubRepository
          .setMemberRole(clubId: widget.club.id, userId: member.userId, role: role);
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
      await widget.clubRepository.removeMember(clubId: widget.club.id, userId: member.userId);
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
      await widget.clubRepository.banMember(clubId: widget.club.id, userId: member.userId);
      _load();
      widget.onChanged();
    } catch (_) {
      if (!mounted) return;
      _showError('แบนไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
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
          _MemberAction('ตั้งเป็น Admin', () => _setRole(member, ClubMemberRole.admin)),
        if (member.role != ClubMemberRole.moderator)
          _MemberAction('ตั้งเป็น Moderator', () => _setRole(member, ClubMemberRole.moderator)),
        if (member.role != ClubMemberRole.member)
          _MemberAction('ตั้งเป็นสมาชิกทั่วไป', () => _setRole(member, ClubMemberRole.member)),
        _MemberAction('ลบออกจาก Club', () => _remove(member)),
        _MemberAction('แบน', () => _ban(member)),
      ];
    }

    if (viewer == ClubMemberRole.admin && member.role != ClubMemberRole.admin) {
      return [
        if (member.role != ClubMemberRole.moderator)
          _MemberAction('ตั้งเป็น Moderator', () => _setRole(member, ClubMemberRole.moderator)),
        if (member.role != ClubMemberRole.member)
          _MemberAction('ตั้งเป็นสมาชิกทั่วไป', () => _setRole(member, ClubMemberRole.member)),
        _MemberAction('ลบออกจาก Club', () => _remove(member)),
        _MemberAction('แบน', () => _ban(member)),
      ];
    }

    if (viewer == ClubMemberRole.moderator && member.role == ClubMemberRole.member) {
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
      label: Text(
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('โหลดรายชื่อสมาชิกไม่สำเร็จ'),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    final approved = _approved;
    final pending = _pending;
    if (approved == null || pending == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (pending.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'คำขอเข้าร่วม (${pending.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            ...pending.map((member) => _buildPendingRow(member)),
            const Divider(),
          ],
          ...approved.map((member) => _buildApprovedRow(member)),
        ],
      ),
    );
  }

  Widget _buildPendingRow(ClubMember member) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
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
                Text(member.nameOrUsername, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '@${member.username}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: () => _approve(member), child: const Text('อนุมัติ')),
          TextButton(onPressed: () => _reject(member), child: const Text('ปฏิเสธ')),
        ],
      ),
    );
  }

  Widget _buildApprovedRow(ClubMember member) {
    final actions = _actionsFor(member);
    final badge = _buildRoleBadge(context, member.role);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
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
                Text(member.nameOrUsername, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '@${member.username}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
          if (badge != null) badge,
          if (actions.isNotEmpty)
            PopupMenuButton<_MemberAction>(
              key: ValueKey('member-menu-${member.userId}'),
              onSelected: (action) => action.onSelected(),
              itemBuilder: (context) => actions
                  .map((action) => PopupMenuItem(value: action, child: Text(action.label)))
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/club.dart';
import '../../data/club_channel.dart';
import '../../data/club_channel_chat_repository.dart';
import '../../data/club_member.dart';
import '../../data/club_repository.dart';
import 'club_channel_chat_view.dart';
import 'club_channel_switcher.dart';
import '../../../../core/design/wyn_spacing.dart';

/// The "แชท" top-level Club tab -- Discord-style: create as many chat
/// rooms ("ห้อง") as you want (Founder, 2026-09-07). Everything here used
/// to live nested inside the Posts tab behind a "โพสต์ | แชท" toggle
/// (WYN-127/128); the Founder's post-restructuring decision split it out
/// into its own tab and dropped the per-channel post split entirely --
/// channels are a chat-only concept now (see ClubPostsTab's own doc
/// comment). Only reached at all for a developer account -- see
/// ClubPage's `showChat` gate, mirroring `showEvents`/`showInsights`.
class ClubChatTab extends StatefulWidget {
  const ClubChatTab({
    super.key,
    required this.clubRepository,
    required this.club,
    required this.myRole,
    this.onBanned,
    ClubChannelChatRepository? clubChannelChatRepository,
  }) : _clubChannelChatRepository = clubChannelChatRepository;

  /// WYN-127: owns `club_channels` reads/writes.
  final ClubRepository clubRepository;
  final Club club;
  final ClubMemberRole? myRole;

  /// WYN-128: bubbled up from ClubChannelChatView when this user's own
  /// membership in [club] is banned/removed while the chat view is open
  /// -- see that widget's own doc comment for why this tab (not the chat
  /// view itself) is what reacts.
  final VoidCallback? onBanned;

  /// WYN-128: same optional, defaulted-to-a-real-instance shape as every
  /// other optional repository field in this app.
  final ClubChannelChatRepository? _clubChannelChatRepository;

  @override
  State<ClubChatTab> createState() => _ClubChatTabState();
}

class _ClubChatTabState extends State<ClubChatTab> {
  late final ClubChannelChatRepository _clubChannelChatRepository =
      widget._clubChannelChatRepository ?? ClubChannelChatRepository(Supabase.instance.client);

  List<ClubChannel>? _channels;
  String? _selectedChannelId;
  String? _channelsError;

  /// WYN-128: unread message count per channel id -- shown as a small
  /// dot on each channel chip in [ClubChannelSwitcher] now that there's
  /// no single "แชท" toggle segment left to badge (this tab *is* the
  /// chat). Kept live by [_unreadSubscription] for whichever channel
  /// isn't the one currently open.
  Map<String, int> _unreadCounts = {};
  RealtimeChannel? _unreadSubscription;

  bool get _isMember => widget.myRole != null;
  bool get _canManageChannels => widget.myRole?.canManageClub ?? false;

  @override
  void initState() {
    super.initState();
    if (_isMember) _loadChannels();
  }

  @override
  void dispose() {
    _unsubscribeUnread();
    super.dispose();
  }

  void _unsubscribeUnread() {
    final subscription = _unreadSubscription;
    if (subscription != null) {
      _clubChannelChatRepository.unsubscribe(subscription);
      _unreadSubscription = null;
    }
  }

  /// Keeps [_unreadCounts] live for [channelId] while its chat view isn't
  /// the one open -- a lighter-weight subscription than the one
  /// ClubChannelChatView itself opens (no presence tracking), and never
  /// runs at the same time as that one (see [_selectChannel]).
  void _subscribeUnread(String channelId) {
    _unsubscribeUnread();
    _unreadSubscription = _clubChannelChatRepository.subscribeToNewMessagesOnly(
      channelId,
      (message) {
        if (!mounted || message.authorId == Supabase.instance.client.auth.currentUser!.id) return;
        setState(() {
          _unreadCounts = {...(_unreadCounts), channelId: (_unreadCounts[channelId] ?? 0) + 1};
        });
      },
    );
  }

  Future<void> _loadUnreadCounts() async {
    try {
      final counts = await _clubChannelChatRepository.fetchUnreadCounts(widget.club.id);
      if (!mounted) return;
      setState(() => _unreadCounts = counts);
    } catch (_) {
      // Fails open -- an unread dot is a nicety, never worth blocking the
      // channel switcher over.
    }
  }

  Future<void> _loadChannels() async {
    setState(() => _channelsError = null);
    try {
      final channels = await widget.clubRepository.fetchChannels(widget.club.id);
      if (!mounted) return;
      setState(() {
        _channels = channels;
        // Design's User Flow: "แถบ channel ... เริ่มที่ #ทั่วไป เสมอ" --
        // fetchChannels() already sorts oldest-first, and "ทั่วไป" is
        // always the oldest, so this is simply the first channel, unless
        // one is already selected.
        _selectedChannelId ??= channels.isNotEmpty ? channels.first.id : null;
      });
      await _loadUnreadCounts();
      final channelId = _selectedChannelId;
      if (channelId != null) _subscribeUnread(channelId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _channelsError = 'โหลดห้องไม่สำเร็จ');
    }
  }

  void _selectChannel(String channelId) {
    if (channelId == _selectedChannelId) return;
    setState(() {
      _selectedChannelId = channelId;
      _unreadCounts = {..._unreadCounts, channelId: 0};
    });
    _subscribeUnread(channelId);
  }

  bool _isChannelNameTaken(String name, {String? excludingChannelId}) {
    final channels = _channels ?? const [];
    final lower = name.trim().toLowerCase();
    return channels.any(
      (c) => c.id != excludingChannelId && c.name.trim().toLowerCase() == lower,
    );
  }

  Future<void> _createChannel() async {
    final name = await showClubChannelNameDialog(
      context,
      title: 'สร้างห้องใหม่',
      isNameTaken: _isChannelNameTaken,
    );
    if (name == null) return;
    try {
      final channel =
          await widget.clubRepository.createChannel(clubId: widget.club.id, name: name);
      if (!mounted) return;
      setState(() {
        _channels = [...?_channels, channel];
        _selectedChannelId = channel.id;
      });
      _subscribeUnread(channel.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('สร้างห้องไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _editChannel(ClubChannel channel) async {
    final name = await showClubChannelNameDialog(
      context,
      title: 'แก้ไขชื่อห้อง',
      initialName: channel.name,
      isNameTaken: (n) => _isChannelNameTaken(n, excludingChannelId: channel.id),
    );
    if (name == null || name == channel.name) return;
    try {
      await widget.clubRepository.renameChannel(channelId: channel.id, name: name);
      if (!mounted) return;
      setState(() {
        _channels = _channels
            ?.map((c) => c.id == channel.id
                ? ClubChannel(
                    id: c.id,
                    clubId: c.clubId,
                    name: name,
                    createdBy: c.createdBy,
                    createdAt: c.createdAt,
                  )
                : c)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('แก้ไขชื่อห้องไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _deleteChannel(ClubChannel channel) async {
    // Client-side guard, not DB-enforced (same posture as the
    // case-insensitive name-dupe check below): ClubPostsTab always posts
    // into the Club's oldest remaining channel, so at least one channel
    // must always survive for posting to keep working.
    if ((_channels?.length ?? 0) <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ต้องมีอย่างน้อย 1 ห้องเสมอ ลบห้องสุดท้ายไม่ได้')),
      );
      return;
    }
    final deleted = await showDeleteClubChannelDialog(
      context,
      channelName: channel.name,
      onConfirm: () => widget.clubRepository.deleteChannel(channel.id),
    );
    if (!deleted || !mounted) return;
    setState(() {
      _channels = _channels?.where((c) => c.id != channel.id).toList();
      _unreadCounts = {..._unreadCounts}..remove(channel.id);
      if (_selectedChannelId == channel.id) {
        final remaining = _channels;
        _selectedChannelId =
            remaining != null && remaining.isNotEmpty ? remaining.first.id : null;
      }
    });
    final newChannelId = _selectedChannelId;
    if (newChannelId != null) _subscribeUnread(newChannelId);
  }

  /// WYN-128: see ClubChannelChatView.onBanned's own doc comment for why
  /// this tab, not the chat view, is what reacts.
  void _onBanned() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คุณถูกนำออกจาก Club นี้แล้ว')),
    );
    widget.onBanned?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMember) {
      return const Center(child: Text('เข้าร่วม Club เพื่อดูแชท'));
    }

    return Column(
      children: [
        _buildChannelSwitcher(),
        Expanded(child: _buildChatView()),
      ],
    );
  }

  Widget _buildChannelSwitcher() {
    final channels = _channels;
    if (channels == null) {
      // Reserves the same height as the loaded switcher so the chat view
      // below doesn't jump once channels resolve.
      return const SizedBox(height: WynSpacing.touchTargetMin + WynSpacing.space2 * 2);
    }
    if (_channelsError != null) {
      return Padding(
        padding: const EdgeInsets.all(WynSpacing.space3),
        child: Row(
          children: [
            Expanded(child: Text(_channelsError!)),
            TextButton(onPressed: _loadChannels, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }
    return ClubChannelSwitcher(
      channels: channels,
      selectedChannelId: _selectedChannelId,
      canManage: _canManageChannels,
      unreadChannelIds: {
        for (final entry in _unreadCounts.entries)
          if (entry.value > 0) entry.key,
      },
      onSelect: _selectChannel,
      onCreate: _createChannel,
      onEdit: _editChannel,
      onDelete: _deleteChannel,
    );
  }

  Widget _buildChatView() {
    final channelId = _selectedChannelId;
    final channels = _channels;
    if (channelId == null || channels == null) {
      return const SizedBox.shrink();
    }
    String? channelName;
    for (final channel in channels) {
      if (channel.id == channelId) {
        channelName = channel.name;
        break;
      }
    }
    if (channelName == null) return const SizedBox.shrink();
    return ClubChannelChatView(
      key: ValueKey('club-chat-$channelId'),
      repository: _clubChannelChatRepository,
      clubRepository: widget.clubRepository,
      clubId: widget.club.id,
      channelId: channelId,
      channelName: channelName,
      myRole: widget.myRole,
      onBanned: _onBanned,
    );
  }
}

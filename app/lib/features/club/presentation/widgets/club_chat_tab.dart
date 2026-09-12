import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/club.dart';
import '../../data/club_channel.dart';
import '../../data/club_channel_chat_repository.dart';
import '../../data/club_member.dart';
import '../../data/club_repository.dart';
import 'club_channel_dialogs.dart';
import 'club_channel_screen.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';

/// The "แชท" top-level Club tab -- Discord-style: create as many chat
/// rooms ("ห้อง") as you want (Founder, 2026-09-07), optionally grouped
/// under named categories (WYN-133 requirement 7, Founder 2026-09-07:
/// "อยากห้องให้แชท มี วง" after seeing a Discord screenshot with grouped
/// channel headers). This tab shows the **channel list only** -- tapping
/// a row navigates to a dedicated full-screen room ([ClubChannelScreen])
/// instead of swapping content under a chip bar that never left the
/// screen (see .wyn/docs/design/wyn-133-club-chat-channel-navigation.md).
/// Only reached at all for a developer account -- see ClubPage's
/// `showChat` gate, mirroring `showEvents`/`showInsights`.
class ClubChatTab extends StatefulWidget {
  const ClubChatTab({
    super.key,
    required this.clubRepository,
    required this.club,
    required this.myRole,
    this.onBanned,
    ClubChannelChatRepository? clubChannelChatRepository,
  }) : _clubChannelChatRepository = clubChannelChatRepository;

  /// WYN-127/133: owns `club_channels`/`club_channel_categories` reads/writes.
  final ClubRepository clubRepository;
  final Club club;
  final ClubMemberRole? myRole;

  /// WYN-128: bubbled up from [ClubChannelScreen] when this user's own
  /// membership in [club] is banned/removed while a chat room is open --
  /// see that widget's own doc comment for why this tab (not the chat
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
      widget._clubChannelChatRepository ??
          ClubChannelChatRepository(Supabase.instance.client);

  List<ClubChannel>? _channels;
  List<ClubChannelCategory>? _categories;
  String? _channelsError;

  /// WYN-128/133: unread message count per channel id -- a dot on each
  /// channel row on this list, live-updated by [_unreadSubscriptions]
  /// (one per channel, since a Postgres realtime filter can only match
  /// one column -- `subscribeToNewMessagesOnly` is channel-scoped) while
  /// this list is on screen, and resynced from the server every time a
  /// pushed [ClubChannelScreen] is popped back to this list (see
  /// [_openChannel]) -- that pushed screen's own
  /// `ClubChannelChatView.markChannelRead` call already happened by
  /// then, so the resync is what actually clears that channel's dot.
  Map<String, int> _unreadCounts = {};
  final List<RealtimeChannel> _unreadSubscriptions = [];

  bool get _isMember => widget.myRole != null;
  bool get _canManageChannels => widget.myRole?.canManageClub ?? false;
  String get _myUserId => Supabase.instance.client.auth.currentUser!.id;

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
    for (final subscription in _unreadSubscriptions) {
      _clubChannelChatRepository.unsubscribe(subscription);
    }
    _unreadSubscriptions.clear();
  }

  void _subscribeUnreadAll(List<ClubChannel> channels) {
    _unsubscribeUnread();
    for (final channel in channels) {
      _unreadSubscriptions.add(
        _clubChannelChatRepository.subscribeToNewMessagesOnly(channel.id,
            (message) {
          if (!mounted || message.authorId == _myUserId) return;
          setState(() {
            _unreadCounts = {
              ...(_unreadCounts),
              channel.id: (_unreadCounts[channel.id] ?? 0) + 1
            };
          });
        }),
      );
    }
  }

  Future<void> _loadUnreadCounts() async {
    try {
      final counts =
          await _clubChannelChatRepository.fetchUnreadCounts(widget.club.id);
      if (!mounted) return;
      setState(() => _unreadCounts = counts);
    } catch (_) {
      // Fails open -- an unread dot is a nicety, never worth blocking the
      // channel list over.
    }
  }

  Future<void> _loadChannels() async {
    setState(() => _channelsError = null);
    try {
      final channels =
          await widget.clubRepository.fetchChannels(widget.club.id);
      final categories =
          await widget.clubRepository.fetchChannelCategories(widget.club.id);
      if (!mounted) return;
      setState(() {
        _channels = channels;
        _categories = categories;
      });
      await _loadUnreadCounts();
      _subscribeUnreadAll(channels);
    } catch (_) {
      if (!mounted) return;
      setState(() => _channelsError = 'โหลดห้องไม่สำเร็จ');
    }
  }

  bool _isChannelNameTaken(String name, {String? excludingChannelId}) {
    final channels = _channels ?? const [];
    final lower = name.trim().toLowerCase();
    return channels.any(
      (c) => c.id != excludingChannelId && c.name.trim().toLowerCase() == lower,
    );
  }

  bool _isCategoryNameTaken(String name, {String? excludingCategoryId}) {
    final categories = _categories ?? const [];
    final lower = name.trim().toLowerCase();
    return categories.any(
      (c) =>
          c.id != excludingCategoryId && c.name.trim().toLowerCase() == lower,
    );
  }

  Future<void> _openAddMenu() async {
    final action = await showClubChatAddMenu(context);
    if (!mounted) return;
    switch (action) {
      case ClubChatAddAction.channel:
        await _createChannel();
      case ClubChatAddAction.category:
        await _createCategory();
      case null:
        break;
    }
  }

  Future<void> _createChannel() async {
    final result = await showClubChannelNameDialog(
      context,
      title: 'สร้างห้องใหม่',
      categories: _categories ?? const [],
      isNameTaken: _isChannelNameTaken,
    );
    if (result == null) return;
    try {
      await widget.clubRepository.createChannel(
        clubId: widget.club.id,
        name: result.name,
        categoryId: result.categoryId,
      );
      await _loadChannels();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: BrowserSystemText('สร้างห้องไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _editChannel(ClubChannel channel) async {
    final result = await showClubChannelNameDialog(
      context,
      title: 'แก้ไขชื่อห้อง',
      initialName: channel.name,
      initialCategoryId: channel.categoryId,
      categories: _categories ?? const [],
      isNameTaken: (n) =>
          _isChannelNameTaken(n, excludingChannelId: channel.id),
    );
    if (result == null) return;
    try {
      await widget.clubRepository.renameChannel(
        channelId: channel.id,
        name: result.name,
        categoryId: result.categoryId,
      );
      await _loadChannels();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                BrowserSystemText('แก้ไขชื่อห้องไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _moveChannel(ClubChannel channel) async {
    final selection = await showMoveChannelToCategoryDialog(
      context,
      categories: _categories ?? const [],
      currentCategoryId: channel.categoryId,
    );
    if (selection == null) return;
    try {
      await widget.clubRepository.renameChannel(
        channelId: channel.id,
        name: channel.name,
        categoryId: selection.categoryId,
      );
      await _loadChannels();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: BrowserSystemText('ย้ายห้องไม่สำเร็จ ลองใหม่อีกครั้ง')),
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
        const SnackBar(
            content: BrowserSystemText(
                'ต้องมีอย่างน้อย 1 ห้องเสมอ ลบห้องสุดท้ายไม่ได้')),
      );
      return;
    }
    final deleted = await showDeleteClubChannelDialog(
      context,
      channelName: channel.name,
      onConfirm: () => widget.clubRepository.deleteChannel(channel.id),
    );
    if (!deleted || !mounted) return;
    await _loadChannels();
  }

  Future<void> _createCategory() async {
    final name = await showClubCategoryNameDialog(
      context,
      title: 'สร้างกลุ่มใหม่',
      isNameTaken: _isCategoryNameTaken,
    );
    if (name == null) return;
    try {
      await widget.clubRepository
          .createChannelCategory(clubId: widget.club.id, name: name);
      await _loadChannels();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: BrowserSystemText('สร้างกลุ่มไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _editCategory(ClubChannelCategory category) async {
    final name = await showClubCategoryNameDialog(
      context,
      title: 'แก้ไขชื่อกลุ่ม',
      initialName: category.name,
      isNameTaken: (n) =>
          _isCategoryNameTaken(n, excludingCategoryId: category.id),
    );
    if (name == null || name == category.name) return;
    try {
      await widget.clubRepository
          .renameChannelCategory(categoryId: category.id, name: name);
      await _loadChannels();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                BrowserSystemText('แก้ไขชื่อกลุ่มไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _deleteCategory(ClubChannelCategory category) async {
    final deleted = await showDeleteClubCategoryDialog(
      context,
      categoryName: category.name,
      onConfirm: () => widget.clubRepository.deleteChannelCategory(category.id),
    );
    if (!deleted || !mounted) return;
    await _loadChannels();
  }

  Future<void> _showChannelManageSheet(ClubChannel channel) async {
    final action = await showClubChannelManageSheet(context);
    if (!mounted) return;
    switch (action) {
      case ClubChannelManageAction.edit:
        await _editChannel(channel);
      case ClubChannelManageAction.move:
        await _moveChannel(channel);
      case ClubChannelManageAction.delete:
        await _deleteChannel(channel);
      case null:
        break;
    }
  }

  Future<void> _showCategoryManageSheet(ClubChannelCategory category) async {
    final action = await showClubCategoryManageSheet(context);
    if (!mounted) return;
    switch (action) {
      case ClubCategoryManageAction.edit:
        await _editCategory(category);
      case ClubCategoryManageAction.delete:
        await _deleteCategory(category);
      case null:
        break;
    }
  }

  Future<void> _openChannel(ClubChannel channel) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClubChannelScreen(
          repository: _clubChannelChatRepository,
          clubRepository: widget.clubRepository,
          clubId: widget.club.id,
          channelId: channel.id,
          channelName: channel.name,
          myRole: widget.myRole,
          onManage: _canManageChannels
              ? (_) => _showChannelManageSheet(channel)
              : null,
          onBanned: _onBanned,
        ),
      ),
    );
    if (!mounted) return;
    await _loadUnreadCounts();
  }

  /// WYN-128: see ClubChannelScreen.onBanned's own doc comment for why
  /// this tab, not the chat screen, is what reacts.
  void _onBanned() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: BrowserSystemText('คุณถูกนำออกจาก Club นี้แล้ว')),
    );
    widget.onBanned?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMember) {
      return const Center(child: BrowserSystemText('เข้าร่วม Club เพื่อดูแชท'));
    }

    final channels = _channels;
    if (channels == null) {
      if (_channelsError != null) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrowserSystemText(_channelsError!),
              const SizedBox(height: WynSpacing.space3),
              TextButton(
                  onPressed: _loadChannels,
                  child: const BrowserSystemText('ลองใหม่')),
            ],
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return _buildChannelList(channels, _categories ?? const []);
  }

  Widget _buildChannelList(
      List<ClubChannel> channels, List<ClubChannelCategory> categories) {
    final unreadChannelIds = {
      for (final entry in _unreadCounts.entries)
        if (entry.value > 0) entry.key,
    };
    final ungrouped = channels.where((c) => c.categoryId == null).toList();

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WynSpacing.space4,
            WynSpacing.space3,
            WynSpacing.space2,
            WynSpacing.space1,
          ),
          child: Row(
            children: [
              const Expanded(
                child: BrowserSystemText(
                  'ห้องแชท',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: WynColors.ink),
                ),
              ),
              if (_canManageChannels)
                BrowserSystemTooltip(
                    message: 'เพิ่ม',
                    child: IconButton(
                      key: const Key('club_chat_add_button'),
                      icon: const Icon(Icons.add),
                      tooltip: null,
                      onPressed: _openAddMenu,
                    )),
            ],
          ),
        ),
        // Design's Components/States: a Club with no categories yet (the
        // default) renders exactly the pre-WYN-133 flat list -- no
        // category headers, not even an "ไม่มีกลุ่ม" one.
        for (final category in categories) ...[
          _buildCategoryHeader(category),
          for (final channel
              in channels.where((c) => c.categoryId == category.id))
            _buildChannelRow(channel, unreadChannelIds),
        ],
        if (categories.isNotEmpty && ungrouped.isNotEmpty)
          _buildUngroupedHeader(),
        for (final channel in ungrouped)
          _buildChannelRow(channel, unreadChannelIds),
      ],
    );
  }

  Widget _buildCategoryHeader(ClubChannelCategory category) {
    return InkWell(
      key: ValueKey('club_channel_category_${category.id}'),
      onLongPress:
          _canManageChannels ? () => _showCategoryManageSheet(category) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          WynSpacing.space4,
          WynSpacing.space4,
          WynSpacing.space4,
          WynSpacing.space1,
        ),
        child: BrowserSystemText(
          category.name.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: WynColors.graphite,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }

  Widget _buildUngroupedHeader() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(
        WynSpacing.space4,
        WynSpacing.space4,
        WynSpacing.space4,
        WynSpacing.space1,
      ),
      child: BrowserSystemText(
        'ไม่มีกลุ่ม',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: WynColors.graphite,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildChannelRow(ClubChannel channel, Set<String> unreadChannelIds) {
    final hasUnread = unreadChannelIds.contains(channel.id);
    final label = '#${channel.name}';
    return Semantics(
      label: hasUnread ? '$label มีข้อความใหม่' : label,
      button: true,
      excludeSemantics: true,
      child: ListTile(
        key: ValueKey('club_channel_row_${channel.id}'),
        leading: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
              color: WynColors.surfaceTint, shape: BoxShape.circle),
          child: const BrowserSystemText(
            '#',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: WynColors.sapphire),
          ),
        ),
        title: BrowserSystemText(
          label,
          style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: WynColors.ink),
        ),
        trailing: hasUnread
            ? Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: WynColors.sapphire),
              )
            : null,
        onTap: () => _openChannel(channel),
        onLongPress:
            _canManageChannels ? () => _showChannelManageSheet(channel) : null,
      ),
    );
  }
}

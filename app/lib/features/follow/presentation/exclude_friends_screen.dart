import 'package:flutter/material.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../profile/data/profile.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/follow_repository.dart';

/// Screen 3 -- "เลือกเพื่อนที่จะซ่อน" (WYN-097's "ซ่อนเพื่อนบางคน"
/// audience option). Multi-select, per-post (not persisted -- a fresh
/// choice on every Drop, unlike CloseFriendsScreen's standalone
/// setting). Pops with the selected `Set<String>` friend ids (never
/// null -- "ยกเลิก" isn't offered here; the system back button/gesture
/// still works and, per Design spec, simply keeps whatever was already
/// selected in `_CreateDropScreenState` before this screen opened,
/// since selection lives in the parent, not here).
/// See .wyn/docs/design/wyn-097-099-audience-friends-and-likes-privacy.md.
class ExcludeFriendsScreen extends StatefulWidget {
  const ExcludeFriendsScreen({
    super.key,
    required this.followRepository,
    this.initiallySelected = const {},
  });

  final FollowRepository followRepository;

  /// Carried over from a previous visit in the same composing session
  /// (Design spec's "กลับมาจาก Screen 3 ครั้งที่ 2" -- selection state
  /// lives in the parent CreateDropScreen, not this screen).
  final Set<String> initiallySelected;

  @override
  State<ExcludeFriendsScreen> createState() => _ExcludeFriendsScreenState();
}

class _ExcludeFriendsScreenState extends State<ExcludeFriendsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Profile> _friends = [];
  late final Set<String> _selected = {...widget.initiallySelected};
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final friends = await widget.followRepository.fetchMutualFollows(page: 0);
      if (!mounted) return;
      setState(() => _friends = friends);
    } catch (_) {
      if (mounted) setState(() => _error = 'โหลดรายชื่อไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Profile> get _visibleFriends {
    if (_searchQuery.isEmpty) return _friends;
    final q = _searchQuery.toLowerCase();
    return _friends
        .where((p) =>
            p.nameOrUsername.toLowerCase().contains(q) ||
            p.username.toLowerCase().contains(q))
        .toList();
  }

  void _toggle(String friendId) {
    setState(() {
      _selected.contains(friendId)
          ? _selected.remove(friendId)
          : _selected.add(friendId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
        title: Text('เลือกเพื่อนที่จะซ่อนโพสต์นี้',
            style: WynTypography.screenTitle(fontSize: 14, color: WynColors.ink)),
        actions: [
          Semantics(
            label: 'ยืนยัน ซ่อนโพสต์จาก ${_selected.length} คน',
            excludeSemantics: true,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: Text(_selected.isEmpty
                  ? 'เสร็จสิ้น'
                  : 'เสร็จสิ้น (${_selected.length})'),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space6, WynSpacing.space3, WynSpacing.space6, WynSpacing.space2,
      ),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
        decoration: BoxDecoration(
          color: WynColors.surfaceTint,
          borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
          border: Border.all(color: WynColors.hairline),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 14, color: WynColors.mutedNeutral),
            const SizedBox(width: WynSpacing.space2),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'ค้นหา',
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_friends.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Text(
            'คุณยังไม่มีเพื่อน (ติดตามกันทั้งสองทาง) ให้เลือก',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final visible = _visibleFriends;
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Text('ไม่พบผู้ใช้ที่ตรงกับ "$_searchQuery"', textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.builder(
      itemCount: visible.length,
      itemBuilder: (context, index) => _buildRow(visible[index]),
    );
  }

  Widget _buildRow(Profile friend) {
    final checked = _selected.contains(friend.id);
    return Semantics(
      label: '${friend.nameOrUsername}, ยูสเซอร์เนม ${friend.username}, '
          '${checked ? "เลือกซ่อนแล้ว" : "ยังไม่ถูกซ่อน"}',
      button: true,
      excludeSemantics: true,
      child: CheckboxListTile(
        value: checked,
        onChanged: (_) => _toggle(friend.id),
        controlAffinity: ListTileControlAffinity.trailing,
        secondary: AvatarCircle(
          imageUrl: friend.avatarUrl,
          fallbackText: friend.username,
          radius: 21,
        ),
        title: Text(friend.nameOrUsername,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('@${friend.username}'),
      ),
    );
  }
}

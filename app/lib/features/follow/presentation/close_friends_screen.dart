import 'package:flutter/material.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../profile/data/profile.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/follow_repository.dart';

/// Screen 4 -- "เพื่อนที่สนิท" (Close Friends), WYN-097.
/// See .wyn/docs/design/wyn-097-099-audience-friends-and-likes-privacy.md.
/// Reached 2 ways: (1) from the Audience Selector sheet the first time
/// "เพื่อนที่สนิท" is picked ([showWelcomeBanner] true), and (2) from
/// Settings > ความเป็นส่วนตัว ([showWelcomeBanner] false). Toggling a
/// row saves immediately (optimistic, revert-on-fail) -- unlike
/// ExcludeFriendsScreen's batch "เสร็จสิ้น (N)" confirm, this list is a
/// persistent, standalone setting, not part of composing one Drop.
class CloseFriendsScreen extends StatefulWidget {
  const CloseFriendsScreen({
    super.key,
    required this.followRepository,
    this.showWelcomeBanner = false,
  });

  final FollowRepository followRepository;

  /// True only when opened from the Audience Selector sheet the very
  /// first time "เพื่อนที่สนิท" is picked with an empty list -- see
  /// Design spec's Screen 4 "เมื่อเปิดจาก Screen 2 เป็นครั้งแรก".
  final bool showWelcomeBanner;

  @override
  State<CloseFriendsScreen> createState() => _CloseFriendsScreenState();
}

class _CloseFriendsScreenState extends State<CloseFriendsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Profile> _friends = [];
  final Set<String> _closeFriendIds = {};
  final Set<String> _pendingIds = {};
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
      // Loaded together -- the mutual-follow candidate list ("เพื่อน
      // ทั้งหมด") and the subset already on the Close Friends list --
      // so every row can render its Switch's initial state in one pass.
      final results = await Future.wait([
        widget.followRepository.fetchMutualFollows(page: 0),
        widget.followRepository.fetchCloseFriends(),
      ]);
      if (!mounted) return;
      setState(() {
        _friends = results[0];
        _closeFriendIds
          ..clear()
          ..addAll(results[1].map((p) => p.id));
      });
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

  Future<void> _toggle(Profile friend) async {
    if (_pendingIds.contains(friend.id)) return;
    final wasOn = _closeFriendIds.contains(friend.id);
    setState(() {
      _pendingIds.add(friend.id);
      wasOn ? _closeFriendIds.remove(friend.id) : _closeFriendIds.add(friend.id);
    });
    try {
      if (wasOn) {
        await widget.followRepository.removeCloseFriend(friendId: friend.id);
      } else {
        await widget.followRepository.addCloseFriend(friendId: friend.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        wasOn ? _closeFriendIds.add(friend.id) : _closeFriendIds.remove(friend.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _pendingIds.remove(friend.id));
    }
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('เพื่อนที่สนิท',
            style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink)),
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
          color: const Color(0xFFF1EFE9),
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
            'คุณยังไม่มีเพื่อน (mutual follow) ให้เลือก',
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
      itemCount: visible.length + (widget.showWelcomeBanner ? 1 : 0),
      itemBuilder: (context, index) {
        if (widget.showWelcomeBanner) {
          if (index == 0) return _buildWelcomeBanner();
          return _buildRow(visible[index - 1]);
        }
        return _buildRow(visible[index]);
      },
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        WynSpacing.space6, WynSpacing.space2, WynSpacing.space6, WynSpacing.space2,
      ),
      padding: const EdgeInsets.all(WynSpacing.space4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: WynColors.graphite),
          SizedBox(width: WynSpacing.space3),
          Expanded(
            child: Text(
              'คุณยังไม่มีเพื่อนที่สนิท เลือกจากรายชื่อเพื่อนของคุณได้เลย',
              style: TextStyle(fontSize: 13, color: WynColors.graphite),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Profile friend) {
    final isOn = _closeFriendIds.contains(friend.id);
    return Semantics(
      label: '${friend.nameOrUsername}, '
          '${isOn ? 'อยู่ในรายชื่อเพื่อนที่สนิท' : 'ไม่อยู่ในรายชื่อเพื่อนที่สนิท'}',
      toggled: isOn,
      excludeSemantics: true,
      child: ListTile(
        leading: AvatarCircle(
          imageUrl: friend.avatarUrl,
          fallbackText: friend.username,
          radius: 21,
        ),
        title: Text(friend.nameOrUsername,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('@${friend.username}'),
        trailing: _pendingIds.contains(friend.id)
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            // No explicit color override -- Switch's default ON color
            // already resolves to the app theme's colorScheme.primary
            // (Sapphire), per Design spec's Screen 4.
            : Switch.adaptive(
                value: isOn,
                onChanged: (_) => _toggle(friend),
              ),
        onTap: () => _toggle(friend),
      ),
    );
  }
}

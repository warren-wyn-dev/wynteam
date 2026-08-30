import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../follow/data/follow_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/chat_repository.dart';
import 'conversation_screen.dart';

/// 17-new-message.tsx -- reached by tapping the pencil icon on the Chat
/// Inbox header (chat_inbox_screen.dart's own doc comment named this
/// file as the deferred destination). A person picker, not a full
/// compose screen: selecting someone pushes straight into a Chat Thread
/// with them via [ChatRepository.getOrCreateConversation] -- the exact
/// same call [ViewProfileScreen]'s own message button already makes.
///
/// Default list is "ติดตามอยู่" (people the current user follows), same
/// as the mockup. Unlike the mockup's own static list, the search box is
/// wired to real search -- [ProfileRepository.searchProfiles], the exact
/// same call Search's own User tab uses -- rather than only filtering
/// the people you already follow, so this can actually start a
/// conversation with anyone.
class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({
    super.key,
    required this.chatRepository,
    required this.profileRepository,
    required this.followRepository,
  });

  final ChatRepository chatRepository;
  final ProfileRepository profileRepository;
  final FollowRepository followRepository;

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final _searchController = TextEditingController();
  Timer? _debounceTimer;
  String _query = '';

  final List<Profile> _following = [];
  bool _isLoadingFollowing = true;

  final List<Profile> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  bool _isStartingChat = false;

  bool get _showSearchResults => _query.trim().length >= 2;

  String get _myUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadFollowing();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowing() async {
    try {
      final profiles =
          await widget.followRepository.fetchFollowing(userId: _myUserId, page: 0);
      if (!mounted) return;
      setState(() {
        _following
          ..clear()
          ..addAll(profiles);
      });
    } catch (_) {
      // Silent -- same posture as every other list's load failure in
      // this codebase; the empty state just shows instead.
    } finally {
      if (mounted) setState(() => _isLoadingFollowing = false);
    }
  }

  void _onQueryChanged(String text) {
    _debounceTimer?.cancel();
    setState(() {}); // repaint the clear button's visibility immediately

    final trimmed = text.trim();
    if (trimmed.length < 2) {
      setState(() => _query = trimmed);
      return;
    }
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _query = trimmed);
      _search();
    });
  }

  Future<void> _search() async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final results = await widget.profileRepository
          .searchProfiles(query: _query, page: 0);
      if (!mounted) return;
      setState(() {
        _searchResults
          ..clear()
          ..addAll(results.where((p) => p.id != _myUserId));
      });
    } catch (_) {
      if (mounted) setState(() => _searchError = 'ค้นหาไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _openChat(Profile profile) async {
    if (_isStartingChat) return;
    setState(() => _isStartingChat = true);
    try {
      final conversationId =
          await widget.chatRepository.getOrCreateConversation(profile.id);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            chatRepository: widget.chatRepository,
            conversationId: conversationId,
            otherUserId: profile.id,
            otherUsername: profile.username,
            otherDisplayName: profile.displayName,
            otherAvatarUrl: profile.avatarUrl,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เริ่มบทสนทนาไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isStartingChat = false);
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
          icon: const Icon(Icons.close, size: 20, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('ข้อความใหม่', style: WynTypography.screenTitle(fontSize: 17, color: WynColors.ink)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_isStartingChat) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _showSearchResults ? _buildSearchResults() : _buildFollowingList()),
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
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1EFE9),
          borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
          border: Border.all(color: WynColors.hairline),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 15, color: WynColors.mutedNeutral),
            const SizedBox(width: WynSpacing.space2),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: _textStyle(fontSize: 16, color: WynColors.ink),
                decoration: InputDecoration(
                  hintText: 'ค้นหาผู้ใช้',
                  hintStyle: _textStyle(fontSize: 16, color: WynColors.mutedNeutral),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                onChanged: _onQueryChanged,
              ),
            ),
            if (_searchController.text.isNotEmpty)
              Semantics(
                label: 'ล้างคำค้นหา',
                button: true,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () {
                    _debounceTimer?.cancel();
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(left: WynSpacing.space1),
                    child: Icon(Icons.close, size: 16, color: WynColors.mutedNeutral),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowingList() {
    if (_isLoadingFollowing) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_following.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Text(
            'คุณยังไม่ได้ติดตามใครเลย ลองค้นหาคนที่อยากคุยด้วยดูสิ',
            textAlign: TextAlign.center,
            style: _textStyle(fontSize: 13, color: WynColors.graphite),
          ),
        ),
      );
    }
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WynSpacing.space6, WynSpacing.space4, WynSpacing.space6, WynSpacing.space2,
          ),
          child: Text(
            'ติดตามอยู่',
            style: _textStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: WynColors.mutedNeutral,
              letterSpacing: 11 * 0.14,
            ),
          ),
        ),
        for (final profile in _following) _buildPersonRow(profile),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_searchError!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _search, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'ไม่พบผู้ใช้ที่ตรงกับ "$_query"',
          style: _textStyle(fontSize: 13, color: WynColors.faint),
        ),
      );
    }
    return ListView(
      children: [for (final profile in _searchResults) _buildPersonRow(profile)],
    );
  }

  Widget _buildPersonRow(Profile profile) {
    final displayName = profile.displayName?.isNotEmpty == true
        ? profile.displayName!
        : profile.username;
    return Semantics(
      label: 'เริ่มบทสนทนากับ $displayName',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _openChat(profile),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: WynSpacing.space6, vertical: WynSpacing.space3 - 2),
          child: Row(
            children: [
              AvatarCircle(
                imageUrl: profile.avatarUrl,
                fallbackText: profile.username,
                radius: 21,
                ring: true,
              ),
              const SizedBox(width: WynSpacing.space3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: _textStyle(fontSize: 14, fontWeight: FontWeight.w600, color: WynColors.ink),
                  ),
                  Text(
                    '@${profile.username}',
                    style: _textStyle(fontSize: 12, color: WynColors.mutedNeutral),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? letterSpacing,
}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );

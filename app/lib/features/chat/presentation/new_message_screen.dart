import 'package:wyn/core/typography/browser_system_text.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/widgets/empty_state_block.dart';
import '../../follow/data/follow_repository.dart';
import '../../presence/data/presence_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/chat_repository.dart';
import 'conversation_screen.dart';
import 'widgets/chat_ui.dart';

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
    this.presenceRepository,
  });

  final ChatRepository chatRepository;
  final ProfileRepository profileRepository;
  final FollowRepository followRepository;

  /// Optional/defaulted to Supabase.instance.client when omitted, same
  /// shape as every other repository this app threads through
  /// optionally -- threaded down to [ConversationScreen]'s own WYN-139
  /// presence subscriptions.
  final PresenceRepository? presenceRepository;

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

  /// WYN-122: defense-in-depth -- in practice this screen is only ever
  /// reached through ChatInboxScreen, which already shows its own
  /// Locked state before the pencil icon that opens this one is even
  /// tappable in a meaningful way. Checked independently anyway so a
  /// future entry point that forgets this doesn't leave a user staring
  /// at a working-looking search box that fails at the RPC layer.
  bool _lockCheckDone = false;
  bool _isLocked = false;

  bool get _showSearchResults => _query.trim().length >= 2;

  String get _myUserId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    bool allowed;
    try {
      allowed = await widget.chatRepository.isChatAllowed();
    } catch (_) {
      allowed = true;
    }
    if (!mounted) return;
    setState(() {
      _lockCheckDone = true;
      _isLocked = !allowed;
    });
    if (allowed) _loadFollowing();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowing() async {
    try {
      final profiles = await widget.followRepository
          .fetchFollowing(userId: _myUserId, page: 0);
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
      final results =
          await widget.profileRepository.searchProfiles(query: _query, page: 0);
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
            presenceRepository: widget.presenceRepository,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      // WYN-122: reachable even though this screen's own Locked check
      // already passed -- that check only asks "am I allowed to use
      // chat at all", not "is this specific person also allowlisted"
      // (e.g. an allowlisted tester browsing their following list and
      // tapping a non-allowlisted person). Same specific message as
      // ViewProfileScreen's identical catch, so the reason reads the
      // same everywhere it can occur.
      final message = e is PostgrestException &&
              e.message.contains('temporarily closed for testing')
          ? 'ระบบแชทปิดปรับปรุงชั่วคราว'
          : 'เริ่มบทสนทนาไม่สำเร็จ ลองใหม่อีกครั้ง';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: BrowserSystemText(message)));
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
        surfaceTintColor: WynColors.paper,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 58,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 21, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const BrowserSystemText(
          'ข้อความใหม่',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: WynColors.ink),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: !_lockCheckDone
          ? const Center(child: CircularProgressIndicator(color: WynColors.ink))
          : _isLocked
              ? const Center(
                  child: EmptyStateBlock(
                    icon: Icons.lock_clock_outlined,
                    title: 'ระบบแชทปิดปรับปรุงชั่วคราว',
                    subtitle: 'จะเปิดให้ใช้งานได้เร็ว ๆ นี้',
                  ),
                )
              : Column(
                  children: [
                    _buildSearchBar(),
                    if (_isStartingChat)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: _showSearchResults
                          ? _buildSearchResults()
                          : _buildFollowingList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space4,
        WynSpacing.space3,
        WynSpacing.space4,
        WynSpacing.space2,
      ),
      child: ChatSearchField(
        controller: _searchController,
        hintText: 'ค้นหาผู้ใช้...',
        onChanged: _onQueryChanged,
        onClear: () {
          _debounceTimer?.cancel();
          _searchController.clear();
          setState(() => _query = '');
        },
      ),
    );
  }

  Widget _buildFollowingList() {
    if (_isLoadingFollowing) {
      return const Center(
          child: CircularProgressIndicator(color: WynColors.ink));
    }
    if (_following.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: BrowserSystemText(
            'คุณยังไม่ได้ติดตามใครเลย ลองค้นหาคนที่อยากคุยด้วยดูสิ',
            textAlign: TextAlign.center,
            style: _textStyle(fontSize: 13, color: WynColors.graphite),
          ),
        ),
      );
    }
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            WynSpacing.space6,
            WynSpacing.space4,
            WynSpacing.space6,
            WynSpacing.space2,
          ),
          child: ChatSectionLabel('ติดตามอยู่'),
        ),
        for (final profile in _following) _buildPersonRow(profile),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
          child: CircularProgressIndicator(color: WynColors.ink));
    }
    if (_searchError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrowserSystemText(_searchError!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(
                onPressed: _search, child: const BrowserSystemText('ลองใหม่')),
          ],
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: BrowserSystemText(
          'ไม่พบผู้ใช้ที่ตรงกับ "$_query"',
          style: _textStyle(fontSize: 13, color: WynColors.faint),
        ),
      );
    }
    return ListView(
      children: [
        for (final profile in _searchResults) _buildPersonRow(profile)
      ],
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
              horizontal: WynSpacing.space4, vertical: 10),
          child: Row(
            children: [
              AvatarCircle(
                imageUrl: profile.avatarUrl,
                fallbackText: profile.username,
                radius: 23,
                ring: false,
              ),
              const SizedBox(width: WynSpacing.space3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BrowserSystemText(
                    displayName,
                    style: _textStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w600,
                        color: WynColors.ink),
                  ),
                  BrowserSystemText(
                    '@${profile.username}',
                    style:
                        _textStyle(fontSize: 13.5, color: WynColors.graphite),
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

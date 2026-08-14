import 'dart:async';

import 'package:flutter/material.dart';

import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../drop/data/drop_repository.dart';
import '../../follow/data/follow_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../saved/data/saved_repository.dart';
import 'widgets/search_club_results_tab.dart';
import 'widgets/search_drop_results_tab.dart';
import 'widgets/search_pop_results_tab.dart';
import 'widgets/search_user_results_tab.dart';

/// Screen opened from Home's search bar (WYN-009) -- replaces the WYN-007
/// SearchPlaceholderScreen. One shared query box above a User/Drop/Pop/
/// Club TabBar (Club tab added WYN-015) rather than a per-tab search box:
/// the user types once and flips tabs to see what matches, rather than
/// retyping four times. See .wyn/docs/design/wyn-009-search.md and
/// .wyn/docs/design/wyn-015-club-discovery-integration.md (Screen 2).
class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.profileRepository,
    required this.followRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.savedRepository,
    required this.clubRepository,
    required this.clubPostRepository,
  });

  final ProfileRepository profileRepository;
  final FollowRepository followRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;

  // The *effective* search query passed down to the three result tabs --
  // only updated after the debounce delay elapses (or immediately when
  // the box is cleared, since that's a cancellation, not a new search).
  // Deliberately separate from _controller.text, which updates on every
  // keystroke for the TextField itself.
  String _query = '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String text) {
    _debounceTimer?.cancel();
    setState(() {}); // repaint the clear button's visibility immediately

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      // Clearing the box is a cancellation, not a new search -- go back
      // to the prompt state right away instead of waiting out the debounce
      // window for nothing. See .wyn/learning/PATTERNS.md for the general
      // "cancel, don't just delay" debounce-timer discipline this follows.
      setState(() => _query = '');
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _query = trimmed);
    });
  }

  void _clear() {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'ค้นหา username, Drop, Pop, Club',
              border: InputBorder.none,
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : Semantics(
                      label: 'ล้างคำค้นหา',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _clear,
                      ),
                    ),
            ),
            onChanged: _onQueryChanged,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person_outline), text: 'User'),
              Tab(icon: Icon(Icons.grid_view_outlined), text: 'Drop'),
              Tab(icon: Icon(Icons.play_circle_outline), text: 'Pop'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Club'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SearchUserResultsTab(
              query: _query,
              profileRepository: widget.profileRepository,
              followRepository: widget.followRepository,
              dropRepository: widget.dropRepository,
              popRepository: widget.popRepository,
              savedRepository: widget.savedRepository,
            ),
            SearchDropResultsTab(
              query: _query,
              dropRepository: widget.dropRepository,
              followRepository: widget.followRepository,
              profileRepository: widget.profileRepository,
              popRepository: widget.popRepository,
              savedRepository: widget.savedRepository,
            ),
            SearchPopResultsTab(
              query: _query,
              popRepository: widget.popRepository,
              followRepository: widget.followRepository,
              profileRepository: widget.profileRepository,
              dropRepository: widget.dropRepository,
              savedRepository: widget.savedRepository,
            ),
            SearchClubResultsTab(
              query: _query,
              clubRepository: widget.clubRepository,
              clubPostRepository: widget.clubPostRepository,
            ),
          ],
        ),
      ),
    );
  }
}

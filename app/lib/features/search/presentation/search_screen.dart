import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../drop/data/drop_repository.dart';
import '../../follow/data/follow_repository.dart';
import '../../follow/data/follow_request_repository.dart';
import '../../home/data/home_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../data/discovery_repository.dart';
import 'widgets/discovery_view.dart';
import 'widgets/search_club_results_tab.dart';
import 'widgets/search_drop_results_tab.dart';
import 'widgets/search_pop_results_tab.dart';
import 'widgets/search_user_results_tab.dart';

/// Search tab (Bottom Nav, WYN-024 -- previously opened from Home's
/// search bar, WYN-009). One shared query box above a User/Drop/Pop/Club
/// TabBar (Club tab added WYN-015) rather than a per-tab search box: the
/// user types once and flips tabs to see what matches, rather than
/// retyping four times. See .wyn/docs/design/wyn-009-search.md,
/// .wyn/docs/design/wyn-015-club-discovery-integration.md (Screen 2), and
/// .wyn/docs/design/wyn-024-bottom-nav-v1-restructure.md (Screen 3).
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
    this.autofocus = false,
    this.followRequestRepository,
    this.discoveryRepository,
  });

  final ProfileRepository profileRepository;
  final FollowRepository followRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  // WYN-024: defaults to false now that this screen is a permanent
  // Bottom Nav tab root rather than something only reached by an
  // intentional tap on a search bar -- popping the keyboard open every
  // time the user merely switches to this tab would be intrusive. Pass
  // true at a call site that still represents deliberate search intent.
  final bool autofocus;

  // WYN-040: optional and defaulted to Supabase.instance.client when
  // omitted (see the State's _followRequestRepository/
  // _discoveryRepository getters below) -- same "optional/defaulted
  // repository" shape ViewProfileScreen already established for
  // _reportRepository/_blockRepository/etc, so DiscoveryView's own
  // dependencies (only needed for the empty/short-query state) don't
  // become new *required* parameters at this screen's one call site
  // (RootShell) or in any existing test that builds a SearchScreen.
  final FollowRequestRepository? followRequestRepository;
  final DiscoveryRepository? discoveryRepository;

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

  late final FollowRequestRepository _followRequestRepository =
      widget.followRequestRepository ??
          FollowRequestRepository(Supabase.instance.client);
  late final DiscoveryRepository _discoveryRepository =
      widget.discoveryRepository ??
          DiscoveryRepository(
            Supabase.instance.client,
            homeRepository: HomeRepository(Supabase.instance.client),
            profileRepository: widget.profileRepository,
          );

  // WYN-040 Design doc, "ทิศทางภาพรวม" -- the same <2-char threshold the
  // result tabs already use internally (SearchUserResultsTab._queryTooShort
  // etc) to decide not to fire a query, reused here to decide whether the
  // TabBar+TabBarView shows at all, not just each tab's own empty state.
  bool get _showDiscovery => _query.trim().length < 2;

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
        backgroundColor: WynColors.paper,
        appBar: AppBar(
          backgroundColor: WynColors.paper,
          foregroundColor: WynColors.ink,
          elevation: 0,
          toolbarHeight: 66,
          titleSpacing: WynSpacing.space4,
          // 03-search.tsx's search bar: a rounded pill, not a bare
          // AppBar TextField -- real controller/focusNode/autofocus/
          // onChanged debounce/clear button all unchanged, styling only.
          title: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
            decoration: BoxDecoration(
              // Literal one-off, not one of SPEC.md's 7 tokens -- the
              // search box's own slightly-off-paper fill, same "single
              // contained use" precedent as _kMessageBodyColor
              // (notification_list_screen.dart).
              color: const Color(0xFFF1EFE9),
              borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
              border: Border.all(color: WynColors.hairline),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, size: 16, color: WynColors.mutedNeutral),
                const SizedBox(width: WynSpacing.space2),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    style: GoogleFonts.inter(fontSize: 13.5, color: WynColors.ink),
                    decoration: InputDecoration(
                      hintText: 'ค้นหา username, Drop, Pop, Club',
                      hintStyle: GoogleFonts.inter(fontSize: 13.5, color: WynColors.graphite),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    onChanged: _onQueryChanged,
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  Semantics(
                    label: 'ล้างคำค้นหา',
                    button: true,
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: _clear,
                      child: const Padding(
                        padding: EdgeInsets.only(left: WynSpacing.space1),
                        child: Icon(Icons.close, size: 16, color: WynColors.mutedNeutral),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // WYN-040: no reason for the TabBar to stick around while
          // Discovery shows instead of the result tabs it would flip
          // between -- both come/go together, not just the body.
          bottom: _showDiscovery
              ? null
              : const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.person_outline), text: 'User'),
                    Tab(icon: Icon(Icons.grid_view_outlined), text: 'Drop'),
                    Tab(icon: Icon(Icons.play_circle_outline), text: 'Pop'),
                    Tab(icon: Icon(Icons.groups_outlined), text: 'Club'),
                  ],
                ),
        ),
        body: _showDiscovery
            ? DiscoveryView(
                discoveryRepository: _discoveryRepository,
                clubRepository: widget.clubRepository,
                clubPostRepository: widget.clubPostRepository,
                profileRepository: widget.profileRepository,
                followRepository: widget.followRepository,
                followRequestRepository: _followRequestRepository,
                dropRepository: widget.dropRepository,
                popRepository: widget.popRepository,
                savedRepository: widget.savedRepository,
              )
            : TabBarView(
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

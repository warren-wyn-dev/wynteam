import 'package:flutter/material.dart';
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
import 'widgets/search_user_results_tab.dart';

/// Search tab (Bottom Nav, WYN-024 -- previously opened from Home's
/// search bar, WYN-009). One shared query box above a User/โพสต์/Club
/// TabBar (Club tab added WYN-015; Pop's own tab hidden -- not deleted
/// -- by WYN-102) rather than a per-tab search box: the
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

  // The *effective* search query passed down to the four result tabs --
  // WYN-080 (Wynos V1.0.0 Beta2, item 9): only updated by an explicit
  // [_submit] (search button or keyboard "search" action) now, not on
  // every keystroke -- Founder didn't like results firing while still
  // typing. Deliberately separate from _controller.text, which still
  // updates on every keystroke for the TextField itself and for
  // DiscoveryView's own live "TikTok feel" (trending hashtags/suggested
  // content) that keeps showing until a search is actually submitted --
  // see _showDiscovery below.
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
  // etc) to decide not to fire a query.
  //
  // WYN-080 (Wynos V1.0.0 Beta2, item 9): also true whenever the box has
  // been edited since the last submitted search (_controller.text no
  // longer matches _query) -- not just on a short/empty query -- so
  // DiscoveryView's live trending/suggested content ("ฟิว TikTok" per
  // Founder) keeps showing while the user is mid-typing a new search,
  // and only the actual result tabs from an explicit [_submit] replace
  // it.
  bool get _showDiscovery =>
      _query.trim().length < 2 || _controller.text.trim() != _query;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Repaints the clear button's visibility and re-evaluates
  // [_showDiscovery] on every keystroke -- WYN-080: deliberately does
  // NOT touch [_query] anymore (that only happens in [_submit] now), so
  // typing alone never fires a search.
  void _onQueryChanged(String text) => setState(() {});

  // WYN-080: the explicit "search" action -- keyboard search key
  // (TextField's onSubmitted) or the tappable search icon, either one
  // calls this. Empty/whitespace-only text is the same as never having
  // submitted (falls back to DiscoveryView via _showDiscovery above),
  // not an error.
  void _submit() {
    setState(() => _query = _controller.text.trim());
    _focusNode.unfocus();
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      // WYN-102 (Wynos V1.0.0 Beta2, item 11, 2026-09-02): was 4 (User/
      // โพสต์/Pop/Club) -- Pop's own tab is hidden, not deleted (see the
      // removed Tab/SearchPopResultsTab below and Pop's own code, still
      // untouched under app/lib/features/pop/). widget.popRepository
      // stays required: DiscoveryView and the other result tabs below
      // still use it.
      length: 3,
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
              color: WynColors.surfaceTint,
              borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
              border: Border.all(color: WynColors.hairline),
            ),
            child: Row(
              children: [
                // WYN-080: now a real button (was a bare, non-interactive
                // Icon) -- the explicit "ปุ่มให้กดค้นหา" (search button)
                // Founder asked for, alongside the keyboard's own search
                // action below.
                Semantics(
                  label: 'ค้นหา',
                  button: true,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: _submit,
                    child: const Icon(Icons.search,
                        size: 16, color: WynColors.mutedNeutral),
                  ),
                ),
                const SizedBox(width: WynSpacing.space2),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    style: const TextStyle(fontSize: 16, color: WynColors.ink),
                    decoration: const InputDecoration(
                      hintText: 'ค้นหา username, โพสต์, Club',
                      hintStyle: TextStyle(fontSize: 16, color: WynColors.graphite),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: _onQueryChanged,
                    onSubmitted: (_) => _submit(),
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
                    Tab(icon: Icon(Icons.grid_view_outlined), text: 'โพสต์'),
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

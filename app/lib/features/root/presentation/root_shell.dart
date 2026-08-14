import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_feed_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../home/data/home_repository.dart';
import '../../home/presentation/home_feed_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../pop/presentation/pop_feed_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../saved/data/saved_repository.dart';

/// The 4-tab Bottom Navigation shell (Home / Drop / Pop / Profile) from
/// the "WYN V0.1 — CORE APP FEATURE PROMPT" (see
/// .wyn/company/DECISIONS.md, 2026-08-14). Renders as AuthGate's signed-
/// in + onboarded state, replacing the old single-screen Feed.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  // Bumped every time the user switches *to* the Profile tab -- used as
  // ViewProfileScreen's key so it remounts (fresh fetch) on each visit.
  // IndexedStack keeps every tab's State alive to preserve scroll
  // position/etc, so without this a Follow/Unfollow done from Drop or
  // Pop would never be reflected in the Follower/Following counts shown
  // back on Profile. See .wyn/docs/design/wyn-008-follow.md, Screen 4.
  int _profileVisitKey = 0;

  void _onDestinationSelected(int index) {
    setState(() {
      if (index == 3 && _index != 3) _profileVisitKey++;
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    final dropRepository = DropRepository(Supabase.instance.client);
    final popRepository = PopRepository(Supabase.instance.client);
    final followRepository = FollowRepository(Supabase.instance.client);
    final profileRepository = ProfileRepository(Supabase.instance.client);
    final savedRepository = SavedRepository(Supabase.instance.client);

    final tabs = [
      HomeFeedScreen(
        homeRepository: HomeRepository(Supabase.instance.client),
        dropRepository: dropRepository,
        popRepository: popRepository,
        followRepository: followRepository,
        profileRepository: profileRepository,
        savedRepository: savedRepository,
      ),
      DropFeedScreen(
        dropRepository: dropRepository,
        followRepository: followRepository,
        profileRepository: profileRepository,
        popRepository: popRepository,
        savedRepository: savedRepository,
      ),
      PopFeedScreen(
        popRepository: popRepository,
        followRepository: followRepository,
        dropRepository: dropRepository,
        profileRepository: profileRepository,
        savedRepository: savedRepository,
      ),
      ViewProfileScreen(
        key: ValueKey(_profileVisitKey),
        profileRepository: profileRepository,
        followRepository: followRepository,
        dropRepository: dropRepository,
        popRepository: popRepository,
        savedRepository: savedRepository,
        userId: userId,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Drop',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle),
            label: 'Pop',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

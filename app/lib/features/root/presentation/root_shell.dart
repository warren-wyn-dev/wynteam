import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_feed_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../pop/presentation/pop_feed_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';

/// The 4-tab Bottom Navigation shell (Home / Drop / Pop / Profile) from
/// the "WYN V0.1 — CORE APP FEATURE PROMPT" (see
/// .wyn/company/DECISIONS.md, 2026-08-14). Renders as AuthGate's signed-
/// in + onboarded state, replacing the old single-screen Feed.
///
/// Home (WYN-007) isn't built yet -- a placeholder tab holds its spot so
/// the nav structure matches the spec now instead of needing another
/// shell rewrite once it lands.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser!.id;

    final tabs = [
      const _ComingSoonTab(label: 'Home'),
      DropFeedScreen(dropRepository: DropRepository(Supabase.instance.client)),
      PopFeedScreen(popRepository: PopRepository(Supabase.instance.client)),
      ViewProfileScreen(
        profileRepository: ProfileRepository(Supabase.instance.client),
        userId: userId,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
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

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: const Center(child: Text('เร็ว ๆ นี้')),
    );
  }
}

import 'package:flutter/material.dart';

/// Placeholder for "สำรวจ Club" -- full Discovery (Search/Categories/
/// Popular/New/Recommended) is WYN-015, not this round. Same
/// deferred-feature-placeholder convention as SearchPlaceholderScreen
/// was in WYN-007 before WYN-009 built it for real.
class ExploreClubsPlaceholderScreen extends StatelessWidget {
  const ExploreClubsPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สำรวจ Club')),
      body: const Center(child: Text('เร็ว ๆ นี้')),
    );
  }
}

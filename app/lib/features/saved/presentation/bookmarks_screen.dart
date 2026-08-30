import 'package:flutter/material.dart';

import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_typography.dart';
import '../../drop/data/drop_repository.dart';
import '../../follow/data/follow_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/widgets/profile_saved_tab.dart';
import '../data/saved_repository.dart';

/// 15-bookmarks.tsx -- the real destination behind Side Menu's "บันทึกไว้"
/// row and Profile's own bookmark icon (`ViewProfileScreen._openSaved`).
/// Gives that destination its own named screen/header restyled to the
/// reference (chevron back, Fraunces "บันทึกไว้" title, hairline divider)
/// instead of an anonymous inline `Scaffold` -- previously built ad hoc
/// at each call site.
///
/// The body is still the exact same [ProfileSavedTab] (mixed Drop+Pop,
/// 3-column grid, real pagination) rather than the mockup's own full-row
/// post-list layout with a per-row "unsave" icon: that would mean
/// reshaping a shared, already-tested grid used elsewhere and adding a
/// new remove-from-list action neither this pass nor any prior one has
/// scoped -- left as a real, flagged gap rather than guessed at, see
/// this repo's PR/commit notes for this file.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({
    super.key,
    required this.savedRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.followRepository,
    required this.profileRepository,
  });

  final SavedRepository savedRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;

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
        title: Text('บันทึกไว้', style: WynTypography.fraunces(fontSize: 17, color: WynColors.ink)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: ProfileSavedTab(
        savedRepository: savedRepository,
        dropRepository: dropRepository,
        popRepository: popRepository,
        followRepository: followRepository,
        profileRepository: profileRepository,
      ),
    );
  }
}

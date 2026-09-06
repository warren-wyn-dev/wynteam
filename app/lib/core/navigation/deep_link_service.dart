import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_navigator.dart';
import '../../features/club/data/club_post_repository.dart';
import '../../features/club/data/club_repository.dart';
import '../../features/club/presentation/club_page.dart';
import '../../features/club/presentation/club_post_detail_screen.dart';
import '../../features/drop/data/drop_repository.dart';
import '../../features/drop/presentation/drop_detail_screen.dart';
import '../../features/follow/data/follow_repository.dart';
import '../../features/pop/data/pop_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/presentation/view_profile_screen.dart';
import '../../features/saved/data/saved_repository.dart';

/// Opens the screen a shared web link points at, the first time the app
/// loads on that URL -- WYN-114 (`dropShareLink`/`popShareLink`/
/// `clubShareLink`/`clubPostShareLink`/`profileShareLink` in their
/// respective screens all produce a URL like this; before this class
/// existed the app ignored the path entirely and every one of those
/// links just opened to Home/Welcome, no matter what was shared).
///
/// Web only: `Uri.base` is the browser's address bar, which is
/// meaningless on native -- no custom URL scheme is registered for these
/// paths there (iOS Associated Domains / Android App Links is separate
/// platform config a Dart-only change can't add, tracked as follow-up
/// work in WYN-114's own task file, not attempted here).
///
/// Fires at most once per app load. Call [handleInitialLink] from
/// `RootShell.initState` the same way `PushNotificationService.initialize()`
/// already is (see that class's own doc comment) -- that only runs once
/// per real sign-in, not once per rebuild, which matters here too: a
/// user who deep-links in, then signs out and back in, should not be
/// bounced back to the same shared link a second time.
class DeepLinkService {
  DeepLinkService._();

  static bool _handled = false;

  /// Test-only: the "fires once per app load" guard is static (deep
  /// links aren't scoped to a widget instance the way most other
  /// per-session state in this app is), so it leaks across tests in the
  /// same isolate unless a test resets it first.
  @visibleForTesting
  static void resetForTest() => _handled = false;

  /// Test-only: lets a test observe a specific starting path without
  /// depending on `Uri.base` (which reflects this test runner's own
  /// location, not a URL under test).
  @visibleForTesting
  static Future<void> debugHandlePath(String path) => _handle(path);

  static Future<void> handleInitialLink() async {
    if (!kIsWeb || _handled) return;
    _handled = true;
    await _handle(Uri.base.path);
  }

  static Future<void> _handle(String path) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return;

    final client = Supabase.instance.client;
    final first = segments.first;

    if (first.startsWith('@') && first.length > 1) {
      await _openProfileByUsername(navigator, client, first.substring(1));
      return;
    }

    if (segments.length < 2) return;
    final id = segments[1];

    switch (first) {
      case 'drop':
        await _openDrop(navigator, client, id);
      case 'pop':
        // WYN-102: Pop has no user-facing access point anymore -- same
        // "content not available" treatment as a push notification for
        // an old like_pop/comment_pop (PushNotificationService._openPop).
        appScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('เนื้อหานี้ไม่พร้อมใช้งานแล้ว')),
        );
      case 'club':
        _openClub(navigator, client, id);
      case 'club-post':
        await _openClubPost(navigator, client, id);
    }
  }

  static Future<void> _openDrop(
    NavigatorState navigator,
    SupabaseClient client,
    String dropId,
  ) async {
    final dropRepository = DropRepository(client);
    final drop = await dropRepository.fetchById(dropId);
    if (drop == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          dropRepository: dropRepository,
          followRepository: FollowRepository(client),
          profileRepository: ProfileRepository(client),
          popRepository: PopRepository(client),
          savedRepository: SavedRepository(client),
          drop: drop,
        ),
      ),
    );
  }

  static Future<void> _openProfileByUsername(
    NavigatorState navigator,
    SupabaseClient client,
    String username,
  ) async {
    final profileRepository = ProfileRepository(client);
    final profile = await profileRepository.fetchProfileByUsername(username);
    if (profile == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: profileRepository,
          followRepository: FollowRepository(client),
          dropRepository: DropRepository(client),
          popRepository: PopRepository(client),
          savedRepository: SavedRepository(client),
          userId: profile.id,
        ),
      ),
    );
  }

  static void _openClub(
    NavigatorState navigator,
    SupabaseClient client,
    String clubId,
  ) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ClubPage(
          clubRepository: ClubRepository(client),
          clubPostRepository: ClubPostRepository(client),
          clubId: clubId,
        ),
      ),
    );
  }

  static Future<void> _openClubPost(
    NavigatorState navigator,
    SupabaseClient client,
    String clubPostId,
  ) async {
    final clubPostRepository = ClubPostRepository(client);
    final post = await clubPostRepository.fetchById(clubPostId);
    if (post == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ClubPostDetailScreen(
          clubPostRepository: clubPostRepository,
          post: post,
          myRole: null,
        ),
      ),
    );
  }
}

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
/// loads on that URL -- WYN-119 (`dropShareLink`/`popShareLink`/
/// `clubShareLink`/`clubPostShareLink`/`profileShareLink` in their
/// respective screens all produce a URL like this; before this class
/// existed the app ignored the path entirely and every one of those
/// links just opened to Home/Welcome, no matter what was shared).
///
/// Web only: `Uri.base` is the browser's address bar, which is
/// meaningless on native -- no custom URL scheme is registered for these
/// paths there (iOS Associated Domains / Android App Links is separate
/// platform config a Dart-only change can't add, tracked as follow-up
/// work in WYN-119's own task file, not attempted here).
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

  /// Test-only: forces [hasContentPath]'s result instead of deriving it
  /// from `kIsWeb`/`Uri.base` -- neither is controllable from a widget
  /// test (the default test target is never web, and `Uri.base` there is
  /// the test runner's own location, same limitation [debugHandlePath]
  /// exists for). Reset to null after each test that sets it.
  @visibleForTesting
  static bool? debugForceHasContentPath;

  /// True when the browser's current URL points at a specific piece of
  /// content this service knows how to open (drop/pop/club/club-post/
  /// @username) -- used by [AuthGate] to decide whether a signed-out
  /// visitor should be silently dropped into a guest (Anonymous Sign-In)
  /// session instead of WelcomeScreen, so a shared link opens the
  /// content it actually points at (WYN-119's Requirement 2) rather than
  /// forcing a login first. Deliberately mirrors only the *shape check*
  /// half of [_handle]'s routing -- never touches Supabase, never
  /// navigates -- so it is safe to call from a build() method on every
  /// rebuild.
  static bool hasContentPath() {
    final forced = debugForceHasContentPath;
    if (forced != null) return forced;
    if (!kIsWeb) return false;
    final segments =
        Uri.base.path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return false;
    final first = segments.first;
    if (first.startsWith('@') && first.length > 1) return true;
    if (segments.length < 2) return false;
    return const {'drop', 'pop', 'club', 'club-post'}.contains(first);
  }

  static Future<void> _handle(String path) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) return;

    final first = segments.first;

    // `Supabase.instance.client` is only reached from here down, once a
    // segment shape that actually needs a repository is confirmed --
    // every no-op path above (empty, `/`, `/club` with no id, `/@` with
    // no username, an unrecognized prefix) returns without ever touching
    // it. Production always has Supabase initialized by the time this
    // runs (RootShell can't mount before main.dart's Supabase.initialize()
    // completes), but reaching for it unconditionally made this method
    // impossible to unit test for its no-op branches without an
    // unrelated fake Supabase session, and needlessly so -- a snackbar
    // for `pop` doesn't touch the network either.
    if (first.startsWith('@') && first.length > 1) {
      await _openProfileByUsername(
          navigator, Supabase.instance.client, first.substring(1));
      return;
    }

    if (segments.length < 2) return;
    final id = segments[1];

    switch (first) {
      case 'drop':
        await _openDrop(navigator, Supabase.instance.client, id);
      case 'pop':
        // WYN-102: Pop has no user-facing access point anymore -- same
        // "content not available" treatment as a push notification for
        // an old like_pop/comment_pop (PushNotificationService._openPop).
        appScaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('เนื้อหานี้ไม่พร้อมใช้งานแล้ว')),
        );
      case 'club':
        _openClub(navigator, Supabase.instance.client, id);
      case 'club-post':
        await _openClubPost(navigator, Supabase.instance.client, id);
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

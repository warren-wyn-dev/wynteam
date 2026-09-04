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

/// A parsed `.../club|drop|pop|club-post/<id>` or `.../@<username>` path
/// -- the same 5 shapes clubShareLink/dropShareLink/popShareLink/
/// clubPostShareLink/profileShareLink produce on wynos.online. Shared by
/// both the web build (the browser's own URL at launch) and the native
/// app (Universal Links / App Links, via `deep_link_coordinator.dart`),
/// so there is exactly one place that knows what a WYN share link looks
/// like.
sealed class ContentLink {
  const ContentLink();

  /// Null for anything that isn't one of the 5 known shapes --
  /// deliberately permissive about scheme/host rather than allow-listing
  /// `wynos.online` specifically, so this only ever recognises real
  /// content paths. A native custom-scheme redirect (e.g.
  /// auth_repository.dart's `io.wyn.app://login-callback` OAuth
  /// callback) has no path segments matching any case below and simply
  /// falls through as null -- it is never fed here in practice (that
  /// URI never reaches this parser), but this keeps the parser itself
  /// honest either way.
  static ContentLink? parse(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (segments.length == 2) {
      final id = segments[1];
      if (id.isEmpty) return null;
      switch (segments[0]) {
        case 'club':
          return ClubLink(id);
        case 'drop':
          return DropLink(id);
        case 'pop':
          return PopLink(id);
        case 'club-post':
          return ClubPostLink(id);
      }
    }

    if (segments.length == 1 && segments[0].length > 1 && segments[0].startsWith('@')) {
      return ProfileLink(segments[0].substring(1));
    }

    return null;
  }
}

class ClubLink extends ContentLink {
  const ClubLink(this.clubId);
  final String clubId;
}

class DropLink extends ContentLink {
  const DropLink(this.dropId);
  final String dropId;
}

/// Pop is unmounted from normal navigation (WYN-102) -- see
/// [openContentLink]'s own case for why this opens a message, not a
/// screen.
class PopLink extends ContentLink {
  const PopLink(this.popId);
  final String popId;
}

class ClubPostLink extends ContentLink {
  const ClubPostLink(this.postId);
  final String postId;
}

class ProfileLink extends ContentLink {
  const ProfileLink(this.username);
  final String username;
}

/// Opens [link] on top of whatever the app is currently showing, using
/// the app-root navigator (see app_navigator.dart -- a deep link, like a
/// push-notification tap, has no widget-local BuildContext of its own to
/// call `Navigator.of(context)` from). Mirrors
/// `PushNotificationService._openFromPushData`'s per-type cases as
/// closely as the two situations allow (a share link only ever carries
/// the target's own id/username, never the extra context a notification
/// row has, e.g. which tab a club update belongs on) -- including
/// WYN-102's fix: a Pop link opens the same "content not available"
/// message a Pop push notification does, rather than the hidden screen.
///
/// Every unresolvable target (deleted content, unknown username) is a
/// silent no-op, same posture as every other `_open*` case in
/// push_notification_service.dart.
Future<void> openContentLink(ContentLink link) async {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;
  final client = Supabase.instance.client;

  switch (link) {
    case ClubLink(:final clubId):
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ClubPage(
            clubRepository: ClubRepository(client),
            clubPostRepository: ClubPostRepository(client),
            clubId: clubId,
          ),
        ),
      );

    case DropLink(:final dropId):
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

    case PopLink():
      appScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('เนื้อหานี้ไม่พร้อมใช้งานแล้ว')),
      );

    case ClubPostLink(:final postId):
      final clubPostRepository = ClubPostRepository(client);
      final post = await clubPostRepository.fetchById(postId);
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

    case ProfileLink(:final username):
      final profile = await ProfileRepository(client).fetchProfileByUsername(username);
      if (profile == null) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ViewProfileScreen(
            profileRepository: ProfileRepository(client),
            followRepository: FollowRepository(client),
            dropRepository: DropRepository(client),
            popRepository: PopRepository(client),
            savedRepository: SavedRepository(client),
            userId: profile.id,
          ),
        ),
      );
  }
}

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../../core/push_env.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/presentation/conversation_screen.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../club/presentation/club_page.dart';
import '../../club/presentation/club_post_detail_screen.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_detail_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../follow/data/follow_request_repository.dart';
import '../../follow/presentation/follow_request_list_screen.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../moderation/presentation/my_moderation_action_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../saved/data/saved_repository.dart';
import '../../zoky/data/zoky_repository.dart';
import '../../zoky/presentation/zoky_order_detail_screen.dart';
import '../data/push_token_repository.dart';

/// Where this device stands with the OS/browser on push notifications.
///
/// Beta4 §11.2 requires all four outcomes to be handled distinctly, and
/// they are genuinely different situations, not shades of "off":
///
/// * [unsupported] -- there is nothing to ask. Firebase never
///   initialized (no config; see `main.dart`), or this is a web build
///   with no VAPID key. The UI must not offer a toggle it cannot
///   honour.
/// * [notDetermined] -- nobody has asked yet. This is the *only* state
///   in which showing the OS prompt is allowed, and only after the
///   in-app explainer (see `PushPermissionCard`).
/// * [granted] -- includes iOS's `provisional` (quiet delivery, which
///   is a real grant, not a half one).
/// * [denied] -- the person said no, or dismissed the prompt on a
///   platform that treats dismissal as a refusal. **Unrecoverable
///   in-app**: neither iOS nor any browser will show the prompt a
///   second time, so the UI's only honest move is to point at system
///   settings. Asking again does nothing at all -- silently, which is
///   worse than saying so.
enum PushPermissionState { unsupported, notDetermined, granted, denied }

/// Wires up WYN-016 push notifications: permission handling + token
/// registration, and tapping a push open to the right screen (mirrors
/// `NotificationListScreen._openNotification`'s switch exactly, since
/// the push payload's `data` fields are the same columns the
/// `notifications` table already has -- see
/// .wyn/docs/design/wyn-016-push-notifications.md).
///
/// Every public method checks [Firebase.apps] first and no-ops if empty
/// -- `Firebase.initializeApp()` (called in `main.dart`, wrapped in its
/// own try/catch) throws until the Founder adds real
/// `google-services.json`/`GoogleService-Info.plist` files (and, on
/// web, until `--dart-define` carries a config -- see [PushEnv]), and
/// nothing here should ever surface that as a user-visible error. This
/// class builds its own repository instances from
/// `Supabase.instance.client` (same pattern `root_shell.dart`/
/// `SellerAuthGate` already use) rather than being threaded
/// repositories from wherever it's constructed, since it's instantiated
/// once at the app root, not from inside a screen that already has them
/// all in scope.
///
/// ## Beta4 §11.2: permission is no longer requested on sight
///
/// [initialize] used to call `requestPermission()` outright, from
/// `RootShell.initState` -- so the OS dialog fired the instant a user
/// finished onboarding, before they had seen a single notification and
/// with no explanation of what they were agreeing to. That is the one
/// permission prompt a person only ever gets asked once: a reflexive
/// "Don't Allow" there is permanent, and no amount of later UI can
/// re-open it.
///
/// So [initialize] now only *adopts* a permission that already exists:
/// it registers a token and wires up listeners when the answer is
/// already [PushPermissionState.granted], and otherwise does nothing at
/// all. The ask itself moved behind an explicit user action --
/// [requestPermissionAndRegister], called from the explainer card on
/// the Notifications screen and the switch in Notification Settings,
/// both of which say what push is for *before* the OS dialog appears.
class PushNotificationService {
  PushNotificationService(this._tokenRepository);

  final PushTokenRepository _tokenRepository;

  static bool get _isReady => Firebase.apps.isNotEmpty;

  /// Web needs a VAPID key on top of a Firebase app before a token can
  /// be obtained at all -- see [PushEnv.isWebPushConfigured].
  static bool get _canObtainToken =>
      _isReady && (!kIsWeb || PushEnv.isWebPushConfigured);

  static PushPermissionState _stateFrom(AuthorizationStatus status) =>
      switch (status) {
        // `provisional` is iOS's quiet-delivery grant: notifications
        // arrive, they just land in the Notification Centre without
        // interrupting. That is a grant -- re-prompting on top of it
        // would ask a question the person has already answered.
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional =>
          PushPermissionState.granted,
        AuthorizationStatus.notDetermined => PushPermissionState.notDetermined,
        AuthorizationStatus.denied => PushPermissionState.denied,
      };

  /// What the OS/browser currently says, without asking for anything.
  ///
  /// Safe to call on any platform and at any time: `getNotificationSettings`
  /// reads state, it never prompts.
  Future<PushPermissionState> currentPermissionState() async {
    if (!_canObtainToken) return PushPermissionState.unsupported;
    try {
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      return _stateFrom(settings.authorizationStatus);
    } catch (_) {
      // A browser with the Notification API absent or blocked by
      // policy, or a platform channel that isn't there. Nothing to
      // offer, and nothing worth an error dialog over.
      return PushPermissionState.unsupported;
    }
  }

  /// Call once, after the user is signed in and onboarded (see
  /// `RootShell.initState`).
  ///
  /// Registers this device's token and starts listening for token
  /// refreshes and notification taps -- but **only if permission has
  /// already been granted**. Never prompts; see the class doc comment.
  Future<void> initialize() async {
    if (!_canObtainToken) return;

    final state = await currentPermissionState();
    if (state != PushPermissionState.granted) return;

    await _startDelivery();
  }

  /// The explicit opt-in: shows the OS prompt (once -- see
  /// [PushPermissionState.denied]) and, on a grant, registers this
  /// device immediately so the next notification actually arrives.
  ///
  /// Returns the state the device ended up in, so the caller can tell
  /// "you're set up" from "you'll have to turn this on in system
  /// settings" without a second round trip.
  Future<PushPermissionState> requestPermissionAndRegister() async {
    if (!_canObtainToken) return PushPermissionState.unsupported;

    final PushPermissionState state;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      state = _stateFrom(settings.authorizationStatus);
    } catch (_) {
      return PushPermissionState.unsupported;
    }

    if (state == PushPermissionState.granted) {
      await _startDelivery();
    }
    return state;
  }

  /// Token registration + the two listeners, shared by [initialize]
  /// (permission already granted) and [requestPermissionAndRegister]
  /// (just granted). Idempotent by construction: the token upsert keys
  /// on the token itself, and re-listening on a stream this app never
  /// cancels only ever happens once per [RootShell] lifetime, which is
  /// once per signed-in account since Beta4 keyed that shell by user id.
  Future<void> _startDelivery() async {
    final messaging = FirebaseMessaging.instance;

    await _registerCurrentToken(messaging);
    messaging.onTokenRefresh.listen((token) {
      _tokenRepository.upsertToken(token: token, platform: _currentPlatform);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _openFromPushData(message.data);
    });
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _openFromPushData(initialMessage.data);
    }
  }

  /// Deletes this device's currently-registered token -- call on
  /// sign-out, and **before switching accounts** (Beta4 §11.5). See the
  /// RLS comment in supabase/schema.sql for why this (not an
  /// RLS-permitted cross-user update) is what lets a different WYN
  /// account cleanly register the same token afterward.
  ///
  /// Beta4 §11.5/§11.8, why the "before switching accounts" half
  /// matters: `push_tokens` is unique on `token`, and its RLS forbids
  /// one user from retargeting a row another user owns. So on a device
  /// where account A had registered, account B's own registration
  /// *fails* -- silently, since the upsert is fire-and-forget -- and
  /// the row stays pointed at A. Every push meant for A then lands on a
  /// device where B is signed in. Deleting the row as A (who does own
  /// it) is the only sequence that leaves B able to register at all.
  Future<void> unregisterCurrentDevice() async {
    if (!_canObtainToken) return;
    final token = await FirebaseMessaging.instance.getToken(
      vapidKey: kIsWeb ? PushEnv.vapidKey : null,
    );
    if (token != null) {
      await _tokenRepository.deleteToken(token);
    }
  }

  Future<void> _registerCurrentToken(FirebaseMessaging messaging) async {
    // `vapidKey` is web-only and must be omitted (null) elsewhere --
    // passing one on Android/iOS is not merely ignored by every version
    // of the plugin.
    final token = await messaging.getToken(
      vapidKey: kIsWeb ? PushEnv.vapidKey : null,
    );
    if (token == null) return;
    await _tokenRepository.upsertToken(token: token, platform: _currentPlatform);
  }

  PushPlatform get _currentPlatform {
    if (kIsWeb) return PushPlatform.web;
    return Platform.isIOS ? PushPlatform.ios : PushPlatform.android;
  }

  /// Test-only entry point for [_openFromPushData]. Production code
  /// never calls this directly -- real push taps only ever reach
  /// `_openFromPushData` through [initialize]'s own two listeners
  /// (`onMessageOpenedApp`/`getInitialMessage`), both of which require
  /// a real Firebase app to fire at all. `_openFromPushData` is
  /// private and this class otherwise has no public surface a widget
  /// test can drive to exercise a specific push `type` end to end.
  @visibleForTesting
  Future<void> debugOpenFromPushData(Map<String, dynamic> data) =>
      _openFromPushData(data);

  /// [data] carries the same fields as a `notifications` row (`type`
  /// plus whichever of `drop_id`/`pop_id`/`club_id`/`club_post_id`/
  /// `order_id`/`conversation_id`/`moderation_action_id`/`actor_id`
  /// apply) -- set by the send-push-notification Edge Function directly
  /// from the row that triggered the push, so this needs no separate
  /// deep-link table of its own. Mirrors
  /// `NotificationListScreen._openNotification`'s switch exactly (see
  /// that file for the per-type reasoning) -- `moderation_warning`/
  /// `moderation_content_removed`/`appeal_approved`/`appeal_rejected`
  /// all open the same destination, and `system` is a deliberate no-op
  /// (the announcement's full text is already the push body itself).
  Future<void> _openFromPushData(Map<String, dynamic> data) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    final type = data['type'] as String?;
    if (type == null) return;

    final client = Supabase.instance.client;

    switch (type) {
      case 'like_drop':
      case 'comment_drop':
      case 'mention_drop':
      case 'redrop':
        await _openDrop(navigator, client, data['drop_id'] as String?);
      case 'like_pop':
      case 'comment_pop':
        await _openPop(navigator, client, data['pop_id'] as String?);
      case 'follow':
      case 'follow_request_accepted':
        _openProfile(navigator, data['actor_id'] as String?);
      case 'club_join_request':
        _openClub(navigator, client, data['club_id'] as String?, initialTabIndex: 1);
      case 'club_join_approved':
        _openClub(navigator, client, data['club_id'] as String?, initialTabIndex: 0);
      case 'club_post_like':
      case 'club_post_comment':
      case 'mention_club_post':
        await _openClubPost(navigator, client, data['club_post_id'] as String?);
      case 'new_order':
      case 'order_shipped':
      case 'order_cancelled':
      case 'order_refunded':
        _openOrder(navigator, client, data['order_id'] as String?);
      case 'moderation_warning':
      case 'moderation_content_removed':
      case 'appeal_approved':
      case 'appeal_rejected':
        _openModerationAction(navigator, data['moderation_action_id'] as String?);
      case 'message_request':
        await _openConversation(
          navigator,
          client,
          data['conversation_id'] as String?,
          data['actor_id'] as String?,
        );
      case 'follow_request':
        _openFollowRequests(navigator, client);
      case 'system':
        // WYN-043: no detail screen -- the announcement's full text is
        // already the push notification itself.
        return;
    }
  }

  Future<void> _openDrop(
    NavigatorState navigator,
    SupabaseClient client,
    String? dropId,
  ) async {
    if (dropId == null) return;
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

  // WYN-102 (Wynos V1.0.0 Beta2, item 11, 2026-09-02): Pop is hidden
  // from the app entirely -- tapping a push notification for an old
  // like_pop/comment_pop used to fetch and open the real Pop
  // regardless (Pop content/PopRepository/PopSingleClipScreen are all
  // still there, just unreachable through normal navigation now).
  // Never fetches or navigates anymore, so a push tap can't become a
  // live access point either -- mirrors
  // `NotificationListScreen._openPop()`'s fix exactly (same "content
  // not available" copy), shown via [appScaffoldMessengerKey] since
  // this class runs outside any widget's own BuildContext.
  Future<void> _openPop(
    NavigatorState navigator,
    SupabaseClient client,
    String? popId,
  ) async {
    appScaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('เนื้อหานี้ไม่พร้อมใช้งานแล้ว')),
    );
  }

  void _openProfile(NavigatorState navigator, String? userId) {
    if (userId == null) return;
    final client = Supabase.instance.client;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: ProfileRepository(client),
          followRepository: FollowRepository(client),
          dropRepository: DropRepository(client),
          popRepository: PopRepository(client),
          savedRepository: SavedRepository(client),
          userId: userId,
        ),
      ),
    );
  }

  void _openClub(
    NavigatorState navigator,
    SupabaseClient client,
    String? clubId, {
    required int initialTabIndex,
  }) {
    if (clubId == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ClubPage(
          clubRepository: ClubRepository(client),
          clubPostRepository: ClubPostRepository(client),
          clubId: clubId,
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  Future<void> _openClubPost(
    NavigatorState navigator,
    SupabaseClient client,
    String? clubPostId,
  ) async {
    if (clubPostId == null) return;
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

  void _openOrder(NavigatorState navigator, SupabaseClient client, String? orderId) {
    if (orderId == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ZokyOrderDetailScreen(
          zokyRepository: ZokyRepository(client),
          orderId: orderId,
        ),
      ),
    );
  }

  /// WYN-030: all 4 moderation-related types (Warning/Content Removed/
  /// Appeal Approved/Appeal Rejected) open the same destination -- see
  /// notification_list_screen.dart's own comment. A push whose data has
  /// no `moderation_action_id` (shouldn't happen for a real WYN-030 row,
  /// but matches the in-app screen's own backward-compat no-op posture)
  /// stays a no-op.
  void _openModerationAction(NavigatorState navigator, String? actionId) {
    if (actionId == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => MyModerationActionScreen(
          appealRepository: AppealRepository(Supabase.instance.client),
          actionId: actionId,
        ),
      ),
    );
  }

  /// WYN-032: goes straight to `ConversationScreen`, same destination
  /// `NotificationListScreen`'s own messageRequest case uses. Unlike
  /// that in-app case (which already has the actor's profile fields
  /// loaded on the `WynNotification` row), the push payload only carries
  /// `actor_id` -- fetches the profile first so `otherUsername` (a
  /// required, non-nullable param) is real rather than an empty
  /// placeholder. Fails silently (same no-op posture as every other
  /// case here) if the actor's profile can no longer be fetched.
  Future<void> _openConversation(
    NavigatorState navigator,
    SupabaseClient client,
    String? conversationId,
    String? actorId,
  ) async {
    if (conversationId == null || actorId == null) return;
    try {
      final actor = await ProfileRepository(client).fetchProfile(actorId);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            chatRepository: ChatRepository(client),
            conversationId: conversationId,
            otherUserId: actorId,
            otherUsername: actor.username,
            otherDisplayName: actor.displayName,
            otherAvatarUrl: actor.avatarUrl,
          ),
        ),
      );
    } catch (_) {
      // Actor profile no longer fetchable (deleted account) -- no-op,
      // same posture as every other unresolvable-target case here.
    }
  }

  /// WYN-039: every followRequest notification opens the same list --
  /// mirrors notification_list_screen.dart's own case (no per-request
  /// destination to jump to directly, Accept/Reject both live on the
  /// list screen itself).
  void _openFollowRequests(NavigatorState navigator, SupabaseClient client) {
    navigator.push(
      MaterialPageRoute(
        builder: (_) => FollowRequestListScreen(
          followRequestRepository: FollowRequestRepository(client),
        ),
      ),
    );
  }
}

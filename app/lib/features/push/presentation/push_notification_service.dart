import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../club/presentation/club_page.dart';
import '../../club/presentation/club_post_detail_screen.dart';
import '../../drop/data/drop_repository.dart';
import '../../drop/presentation/drop_detail_screen.dart';
import '../../follow/data/follow_repository.dart';
import '../../home/presentation/pop_single_clip_screen.dart';
import '../../pop/data/pop_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/view_profile_screen.dart';
import '../../saved/data/saved_repository.dart';
import '../../zoky/data/zoky_repository.dart';
import '../../zoky/presentation/zoky_order_detail_screen.dart';
import '../data/push_token_repository.dart';

/// Wires up WYN-016 push notifications: permission request + token
/// registration, and tapping a push open to the right screen (mirrors
/// `NotificationListScreen._openNotification`'s switch exactly, since
/// the push payload's `data` fields are the same columns the
/// `notifications` table already has -- see
/// .wyn/docs/design/wyn-016-push-notifications.md).
///
/// Every public method checks [Firebase.apps] first and no-ops if empty
/// -- `Firebase.initializeApp()` (called in `main.dart`, wrapped in its
/// own try/catch) throws until the Founder adds real
/// `google-services.json`/`GoogleService-Info.plist` files, and nothing
/// here should ever surface that as a user-visible error. This class
/// builds its own repository instances from `Supabase.instance.client`
/// (same pattern `root_shell.dart`/`SellerAuthGate` already use) rather
/// than being threaded repositories from wherever it's constructed,
/// since it's instantiated once at the app root, not from inside a
/// screen that already has them all in scope.
class PushNotificationService {
  PushNotificationService(this._tokenRepository);

  final PushTokenRepository _tokenRepository;

  static bool get _isReady => Firebase.apps.isNotEmpty;

  /// Call once, after the user is signed in and onboarded (see
  /// `RootShell.initState`) -- requests notification permission, then
  /// registers the current device's FCM token and starts listening for
  /// both token refreshes and notification taps.
  Future<void> initialize() async {
    if (!_isReady) return;

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

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
  /// sign-out. See the RLS comment in supabase/schema.sql for why this
  /// (not an RLS-permitted cross-user update) is what lets a different
  /// WYN account cleanly register the same token afterward.
  Future<void> unregisterCurrentDevice() async {
    if (!_isReady) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _tokenRepository.deleteToken(token);
    }
  }

  Future<void> _registerCurrentToken(FirebaseMessaging messaging) async {
    final token = await messaging.getToken();
    if (token == null) return;
    await _tokenRepository.upsertToken(token: token, platform: _currentPlatform);
  }

  PushPlatform get _currentPlatform {
    if (kIsWeb) return PushPlatform.web;
    return Platform.isIOS ? PushPlatform.ios : PushPlatform.android;
  }

  /// [data] carries the same fields as a `notifications` row (`type`
  /// plus whichever of `drop_id`/`pop_id`/`club_id`/`club_post_id`/
  /// `order_id`/`actor_id` apply) -- set by the send-push-notification
  /// Edge Function directly from the row that triggered the push, so
  /// this needs no separate deep-link table of its own.
  Future<void> _openFromPushData(Map<String, dynamic> data) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    final type = data['type'] as String?;
    if (type == null) return;

    final client = Supabase.instance.client;

    switch (type) {
      case 'like_drop':
      case 'comment_drop':
        await _openDrop(navigator, client, data['drop_id'] as String?);
      case 'like_pop':
      case 'comment_pop':
        await _openPop(navigator, client, data['pop_id'] as String?);
      case 'follow':
        _openProfile(navigator, data['actor_id'] as String?);
      case 'club_join_request':
        _openClub(navigator, client, data['club_id'] as String?, initialTabIndex: 1);
      case 'club_join_approved':
        _openClub(navigator, client, data['club_id'] as String?, initialTabIndex: 0);
      case 'club_post_like':
      case 'club_post_comment':
        await _openClubPost(navigator, client, data['club_post_id'] as String?);
      case 'new_order':
      case 'order_shipped':
      case 'order_cancelled':
      case 'order_refunded':
        _openOrder(navigator, client, data['order_id'] as String?);
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

  Future<void> _openPop(
    NavigatorState navigator,
    SupabaseClient client,
    String? popId,
  ) async {
    if (popId == null) return;
    final popRepository = PopRepository(client);
    final pop = await popRepository.fetchById(popId);
    if (pop == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => PopSingleClipScreen(
          pop: pop,
          popRepository: popRepository,
          followRepository: FollowRepository(client),
          profileRepository: ProfileRepository(client),
          dropRepository: DropRepository(client),
          savedRepository: SavedRepository(client),
        ),
      ),
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
}

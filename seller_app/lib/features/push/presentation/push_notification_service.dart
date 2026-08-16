import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/navigation/app_navigator.dart';
import '../../order/presentation/seller_order_detail_screen.dart';
import '../../store/data/seller_repository.dart';
import '../data/push_token_repository.dart';

/// Wires up WYN-016 push notifications for the seller side: permission
/// request + token registration, and tapping a push open to the right
/// screen. Scoped to the 2 notification types a seller can ever receive
/// (`new_order`/`order_cancelled` -- see `SellerNotification`'s doc
/// comment for why `order_shipped`/`order_refunded` never reach a
/// seller), both of which just open `SellerOrderDetailScreen`, so this
/// is considerably simpler than `app/`'s equivalent (which has to
/// handle 13 types across 6 destination screens).
///
/// Every public method checks [Firebase.apps] first and no-ops if empty
/// -- see `app/`'s identical file for the full reasoning (same pattern,
/// duplicated for the same "no shared package" reason as everything
/// else cross-app in this project).
class PushNotificationService {
  PushNotificationService(this._tokenRepository);

  final PushTokenRepository _tokenRepository;

  static bool get _isReady => Firebase.apps.isNotEmpty;

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

  void _openFromPushData(Map<String, dynamic> data) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    final type = data['type'] as String?;
    final orderId = data['order_id'] as String?;
    if (orderId == null) return;
    if (type != 'new_order' && type != 'order_cancelled') return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => SellerOrderDetailScreen(
          sellerRepository: SellerRepository(Supabase.instance.client),
          orderId: orderId,
        ),
      ),
    );
  }
}

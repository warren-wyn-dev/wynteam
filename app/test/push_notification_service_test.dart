import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/push/presentation/push_notification_service.dart';

import 'support/recording_push_token_repository.dart';

/// WYN-016: Firebase.initializeApp() is never called during `flutter
/// test` (main() never runs in a widget test), so every one of these
/// exercises the exact "Firebase not configured yet" path production
/// code hits today, before the Founder adds real config files. Every
/// public method must no-op cleanly rather than throw -- these are
/// regression tests for that contract, not (yet) for real push
/// delivery, which needs a real Firebase project to verify end-to-end.
void main() {
  late RecordingPushTokenRepository tokenRepo;

  setUp(() {
    tokenRepo = RecordingPushTokenRepository();
  });

  test('initialize() does not throw and does not touch the token '
      'repository when Firebase is not initialized', () async {
    final service = PushNotificationService(tokenRepo);

    await service.initialize();

    expect(tokenRepo.upsertCalls, 0);
  });

  test('unregisterCurrentDevice() does not throw and does not touch the '
      'token repository when Firebase is not initialized', () async {
    final service = PushNotificationService(tokenRepo);

    await service.unregisterCurrentDevice();

    expect(tokenRepo.deleteCalls, 0);
  });
}

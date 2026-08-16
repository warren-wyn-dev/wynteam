import 'package:flutter_test/flutter_test.dart';

import 'package:zoky_seller/features/push/presentation/push_notification_service.dart';

import 'support/recording_push_token_repository.dart';

/// WYN-016: mirrors `app/`'s identical test file -- see that file's doc
/// comment for why every assertion here exercises the "Firebase not
/// configured yet" path (which is always true during `flutter test`).
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

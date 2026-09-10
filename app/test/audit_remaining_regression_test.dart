import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'BUG-002 push listeners are process-wide and RootShell detaches callback',
    () {
      final service = File(
        'lib/features/push/presentation/push_notification_service.dart',
      ).readAsStringSync();
      final root = File('lib/features/root/presentation/root_shell.dart')
          .readAsStringSync();
      expect(
        service.contains(
          'static StreamSubscription<String>? _tokenRefreshSubscription',
        ),
        isTrue,
      );
      expect(service.contains('_tokenRefreshSubscription ??='), isTrue);
      expect(service.contains('_openedAppSubscription ??='), isTrue);
      expect(service.contains('_foregroundSubscription ??='), isTrue);
      expect(root.contains('_pushNotificationService.dispose();'), isTrue);
    },
  );

  test(
    'POTENTIAL-002 password-state synchronization is verified and retryable',
    () {
      final source = File('lib/features/auth/data/auth_repository.dart')
          .readAsStringSync();
      expect(
        source.contains('for (var attempt = 0; attempt < 3; attempt++)'),
        isTrue,
      );
      expect(source.contains(".update({'password_set': true})"), isTrue);
      expect(source.contains(".select('id')"), isTrue);
    },
  );

  test('package metadata matches stable Beta5', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(
      pubspec.contains('description: WYNOS — social app (V1.0.0 Beta5)'),
      isTrue,
    );
    expect(pubspec.contains('version: 1.0.0+5'), isTrue);
  });
}

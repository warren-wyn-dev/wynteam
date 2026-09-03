import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/network_error.dart';

/// Stand-ins for the platform exception types this helper matches by
/// name -- the real ones cannot both be imported into one test (dart:io
/// does not exist on web, package:http is only a transitive dependency),
/// which is the whole reason the helper matches by name.
class SocketException implements Exception {
  SocketException(this.message);
  final String message;
  @override
  String toString() => 'SocketException: $message';
}

class ClientException implements Exception {
  ClientException(this.message);
  final String message;
  @override
  String toString() => 'ClientException: $message';
}

class PostgrestishException implements Exception {
  PostgrestishException(this.message);
  final String message;
  @override
  String toString() => 'PostgrestException(message: $message, code: 500)';
}

void main() {
  group('isNetworkError', () {
    test('a timeout is a network error', () {
      expect(isNetworkError(TimeoutException('too slow')), isTrue);
    });

    test('a native SocketException is a network error', () {
      expect(isNetworkError(SocketException('Failed host lookup')), isTrue);
    });

    test('a web ClientException is a network error', () {
      expect(isNetworkError(ClientException('XMLHttpRequest error')), isTrue);
    });

    test('a wrapped transport failure is caught by its message', () {
      expect(
        isNetworkError(Exception('SocketException: Connection refused')),
        isTrue,
      );
    });

    test('a real server error is NOT a network error -- the user should '
        'not be told their connection is down', () {
      expect(isNetworkError(PostgrestishException('permission denied')),
          isFalse);
    });

    test('an ordinary application error is not a network error', () {
      expect(isNetworkError(StateError('bad state')), isFalse);
      expect(isNetworkError(ArgumentError('nope')), isFalse);
    });
  });

  group('errorMessageFor', () {
    test('offline gets the connectivity message, not the screen message', () {
      expect(
        errorMessageFor(SocketException('Failed host lookup'),
            serverMessage: 'โหลด Home ไม่สำเร็จ'),
        networkErrorMessage,
      );
    });

    test('a server failure keeps the screen-specific message', () {
      expect(
        errorMessageFor(PostgrestishException('boom'),
            serverMessage: 'โหลด Home ไม่สำเร็จ'),
        'โหลด Home ไม่สำเร็จ',
      );
    });
  });
}

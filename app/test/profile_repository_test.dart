import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/text_utils.dart';

void main() {
  group('normalizeOptionalText', () {
    test('converts an empty string to null', () {
      // Regression test for WYN-003: profiles_display_name_length requires
      // display_name to be NULL or 1-50 characters. Every user starts with
      // an empty display name field, so sending '' instead of null on
      // save violated that constraint and failed on essentially every
      // first profile edit. See .wyn/tasks/bugs/WYN-003-user-profile.md.
      expect(normalizeOptionalText(''), isNull);
    });

    test('leaves a non-empty string unchanged', () {
      expect(normalizeOptionalText('น้ำฝน'), 'น้ำฝน');
    });
  });
}

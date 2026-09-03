import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/text_utils.dart';
import 'package:wyn/features/profile/data/profile.dart';

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

  group('Profile.fromMap', () {
    // Regression test (2026-09-03 Beta2 review): `profiles.username` is
    // nullable in the schema and a stub row with no username is a real,
    // reachable state -- LegalRepository.acceptMandatoryDocuments() and
    // AuthRepository.setDateOfBirth() both upsert `{'id': userId}` before
    // onboarding ever reaches the Username step. The old bare
    // `map['username'] as String` threw a TypeError on exactly those
    // rows, which surfaced as ViewProfileScreen's
    // "โหลดโปรไฟล์ไม่สำเร็จ" error state (and crashed anything else
    // reading that profile).
    test('a profile row with no username yet parses instead of throwing', () {
      final profile = Profile.fromMap(const <String, dynamic>{
        'id': 'stub-user',
        'username': null,
      });

      expect(profile.id, 'stub-user');
      expect(profile.username, '');
    });

    test('falls back to the display name when there is no username', () {
      final profile = Profile.fromMap(const <String, dynamic>{
        'id': 'stub-user',
        'username': null,
        'display_name': 'น้ำฝน',
      });

      expect(profile.nameOrUsername, 'น้ำฝน');
    });

    test('a normal row is unchanged', () {
      final profile = Profile.fromMap(const <String, dynamic>{
        'id': 'real-user',
        'username': 'namfon',
        'display_name': 'น้ำฝน',
        'likes_visibility': 'friends',
      });

      expect(profile.username, 'namfon');
      expect(profile.nameOrUsername, 'น้ำฝน');
      expect(profile.likesVisibility, LikesVisibility.friends);
    });
  });
}

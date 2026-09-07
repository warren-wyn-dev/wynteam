import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club_invite_link.dart';

void main() {
  group('ClubInviteLink.fromMap', () {
    Map<String, dynamic> baseMap({
      String? expiresAt,
      int? maxUses,
      int useCount = 0,
      String? revokedAt,
    }) =>
        {
          'id': 'link-1',
          'club_id': 'club-1',
          'code': 'AbCd12EfGh',
          'created_by': 'owner-1',
          'created_at': '2026-09-07T10:00:00Z',
          'expires_at': expiresAt,
          'max_uses': maxUses,
          'use_count': useCount,
          'revoked_at': revokedAt,
        };

    test('parses every field', () {
      final link = ClubInviteLink.fromMap(baseMap(
        expiresAt: '2026-09-14T10:00:00Z',
        maxUses: 50,
        useCount: 3,
      ));

      expect(link.id, 'link-1');
      expect(link.clubId, 'club-1');
      expect(link.code, 'AbCd12EfGh');
      expect(link.createdBy, 'owner-1');
      expect(link.expiresAt, isNotNull);
      expect(link.maxUses, 50);
      expect(link.useCount, 3);
      expect(link.revokedAt, isNull);
    });

    test('no-expiration/no-max-uses map to null fields, not zero', () {
      final link = ClubInviteLink.fromMap(baseMap());

      expect(link.expiresAt, isNull);
      expect(link.maxUses, isNull);
      expect(link.isExpired, isFalse);
      expect(link.isExhausted, isFalse);
      expect(link.isActive, isTrue);
    });

    test('isExpired is true once expiresAt is in the past', () {
      final link = ClubInviteLink.fromMap(baseMap(
        expiresAt: DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      ));

      expect(link.isExpired, isTrue);
      expect(link.isActive, isFalse);
    });

    test('isExhausted is true once useCount reaches maxUses', () {
      final link = ClubInviteLink.fromMap(baseMap(maxUses: 10, useCount: 10));

      expect(link.isExhausted, isTrue);
      expect(link.isActive, isFalse);
    });

    test('isRevoked/isActive reflect a non-null revokedAt', () {
      final link = ClubInviteLink.fromMap(baseMap(revokedAt: '2026-09-08T10:00:00Z'));

      expect(link.isRevoked, isTrue);
      expect(link.isActive, isFalse);
    });
  });

  group('ClubInvitePreview.fromMap', () {
    test('parses a valid status with every club field', () {
      final preview = ClubInvitePreview.fromMap(
        {
          'status': 'valid',
          'club_id': 'club-1',
          'club_name': 'Test Club',
          'club_privacy': 'private',
          'club_icon_url': 'clubs/club-1/icon.jpg',
        },
        signedIconUrl: 'https://example.supabase.co/signed/icon.jpg',
      );

      expect(preview.status, ClubInviteLinkStatus.valid);
      expect(preview.clubId, 'club-1');
      expect(preview.clubName, 'Test Club');
      expect(preview.clubPrivacy, 'private');
      expect(preview.clubIconUrl, 'https://example.supabase.co/signed/icon.jpg');
    });

    for (final entry in {
      'expired': ClubInviteLinkStatus.expired,
      'revoked': ClubInviteLinkStatus.revoked,
      'exhausted': ClubInviteLinkStatus.exhausted,
      'not_found': ClubInviteLinkStatus.notFound,
    }.entries) {
      test('parses status "${entry.key}"', () {
        final preview = ClubInvitePreview.fromMap({
          'status': entry.key,
          'club_id': null,
          'club_name': null,
          'club_privacy': null,
          'club_icon_url': null,
        });

        expect(preview.status, entry.value);
        expect(preview.clubId, isNull);
        expect(preview.clubName, isNull);
      });
    }
  });
}

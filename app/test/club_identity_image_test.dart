import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';

/// Beta4 §8.1 -- "Club ใช้รูปเพียง 1 รูป ... ห้าม: Cover Image แยก /
/// Background Image แยก / อัปโหลดสองรูปสำหรับ Club เดียว".
///
/// The `clubs` table has carried `icon_url` and `cover_url` since
/// WYN-014, and the UI had drifted into treating them as two unrelated
/// pictures: the create/edit forms only ever uploaded `cover_url`,
/// while the Club page header, "Club ของฉัน", the ranked rows and the
/// mini cards all read `icon_url` -- a column nothing in the product
/// could set. So one upload produced a photo on a discovery card and a
/// grey letter-avatar everywhere else.
///
/// [Club.identityImageUrl] is the single read path that closes that,
/// and these tests pin its resolution order. The column itself is left
/// in place: dropping it would blank every Club created before Beta4.
void main() {
  Club club({String? iconUrl, String? coverUrl}) => Club(
        id: 'c1',
        name: 'ชมรมถ่ายภาพ',
        iconUrl: iconUrl,
        coverUrl: coverUrl,
        privacy: ClubPrivacy.public,
        ownerId: 'owner',
        createdAt: DateTime(2026, 1, 1),
        memberCount: 3,
      );

  test('a Club created from Beta4 onwards resolves to its icon_url', () {
    // createClub writes the single picked image here.
    expect(
      club(iconUrl: 'signed://icon.jpg').identityImageUrl,
      'signed://icon.jpg',
    );
  });

  test(
      'a Club created before Beta4 still shows the image its owner actually '
      'chose, which lives in cover_url', () {
    // The pre-Beta4 create form only ever wrote cover_url. Without this
    // fallback, every existing Club would have gone image-less the day
    // Beta4 shipped.
    expect(
      club(coverUrl: 'signed://cover.jpg').identityImageUrl,
      'signed://cover.jpg',
    );
  });

  test('icon_url wins when a legacy Club has since been given a new image',
      () {
    // uploadClubIdentityImage writes icon_url and clears cover_url, so
    // this state is transient -- but the precedence has to be
    // unambiguous either way, or "which picture am I looking at"
    // depends on write order.
    expect(
      club(iconUrl: 'signed://new.jpg', coverUrl: 'signed://old.jpg')
          .identityImageUrl,
      'signed://new.jpg',
    );
  });

  test('a Club with no image at all resolves to null, not a broken URL', () {
    // Picking an image is optional (only name and privacy are
    // required), so every Club surface must handle this -- they fall
    // back to the Club's initial, same as an avatar-less profile.
    expect(club().identityImageUrl, isNull);
  });

  test('Club.fromMap still round-trips both columns', () {
    // cover_url stays a real field, not a dropped one -- see the class
    // doc. A future migration is a Founder decision, not a side effect
    // of a UI change.
    final parsed = Club.fromMap(
      {
        'id': 'c1',
        'name': 'ชมรมถ่ายภาพ',
        'description': null,
        'rules': null,
        'icon_url': null,
        'cover_url': 'signed://cover.jpg',
        'category': null,
        'privacy': 'public',
        'owner_id': 'owner',
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
      },
      memberCount: 3,
    );
    expect(parsed.coverUrl, 'signed://cover.jpg');
    expect(parsed.iconUrl, isNull);
    expect(parsed.identityImageUrl, 'signed://cover.jpg');
  });
}

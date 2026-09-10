import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_v2_header.dart';

void main() {
  test('Beta5 Profile parses cover_url', () {
    final profile = Profile.fromMap({
      'id': 'me',
      'username': 'warren',
      'cover_url': 'https://example.com/cover.jpg',
    });
    expect(profile.coverUrl, 'https://example.com/cover.jpg');
  });

  testWidgets('Beta5 full header keeps the large edit/link band out', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileV2Header(
            profile: const Profile(
              id: 'me',
              username: 'warren',
              displayName: 'WARREN',
              bio: 'WYNOS',
            ),
            nameRow: const Text('WARREN'),
            followingCount: 3,
            followerCount: 6,
            onFollowingTap: () {},
            onFollowersTap: () {},
            onEditCover: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('profile_v2_full_header')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์'), findsNothing);
    expect(find.byKey(const Key('profile_cover_edit_button')), findsOneWidget);
  });
}

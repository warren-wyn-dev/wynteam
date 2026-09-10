import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/core/design/wyn_spacing.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/widgets/avatar_circle.dart';
import 'package:wyn/features/profile/presentation/widgets/wynos_founder_profile_header.dart';

void main() {
  const profile = Profile(
    id: 'me',
    username: 'kkcu52',
    displayName: 'หาเพื่อนคุย',
    bio: 'ทักทายได้นะครับ',
  );

  Widget buildHeader() => const MaterialApp(
        home: Scaffold(
          body: WynosFounderProfileHeader(
            profile: profile,
            followingCount: 49,
            followerCount: 3,
            isOwnProfile: true,
            showStats: true,
            actions: SizedBox(height: 44),
            onFollowingTap: _noop,
            onFollowersTap: _noop,
            onDisplayNameTap: _noop,
            showOnline: true,
          ),
        ),
      );

  testWidgets('ordinary membership badge is removed', (tester) async {
    await tester.pumpWidget(buildHeader());
    expect(find.text('สมาชิกทั่วไป'), findsNothing);
  });

  testWidgets('avatar is laid out in the white profile body beside identity',
      (tester) async {
    await tester.pumpWidget(buildHeader());

    final avatar = tester.getRect(find.byType(AvatarCircle));
    final name = tester.getRect(find.text('หาเพื่อนคุย'));
    expect(avatar.top, greaterThanOrEqualTo(0));
    expect(name.left, greaterThan(avatar.right));
  });

  testWidgets('username sits beside display name on the same row',
      (tester) async {
    await tester.pumpWidget(buildHeader());

    final name = tester.getRect(find.text('หาเพื่อนคุย'));
    final username = tester.getRect(find.text('@kkcu52'));
    expect(username.left, greaterThan(name.left));
    expect((username.center.dy - name.center.dy).abs(), lessThan(8));
  });

  testWidgets('own display-name switcher keeps a 44px accessible tap target',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(buildHeader());

    final finder = find.byKey(const Key('profile_account_switcher'));
    expect(finder, findsOneWidget);
    expect(
      tester.getSize(finder).height,
      greaterThanOrEqualTo(WynSpacing.touchTargetMin),
    );
    final semantics = tester.getSemantics(finder);
    expect(semantics.label, contains('สลับบัญชี'));
    expect(semantics.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('compact profile icon action still renders its glyph',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WynosProfileIconAction(
            icon: Icons.person_add_alt_1_outlined,
            tooltip: 'แนะนำสำหรับคุณ',
            onPressed: _noop,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.person_add_alt_1_outlined), findsOneWidget);
  });
}

void _noop() {}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/follow/presentation/close_friends_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/recording_follow_repository.dart';

void main() {
  late RecordingFollowRepository followRepository;

  setUp(() {
    followRepository = RecordingFollowRepository();
  });

  Widget buildScreen({bool showWelcomeBanner = false}) => MaterialApp(
        home: CloseFriendsScreen(
          followRepository: followRepository,
          showWelcomeBanner: showWelcomeBanner,
        ),
      );

  testWidgets('empty mutual-follow list shows the "no friends" empty state',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('คุณยังไม่มีเพื่อน (mutual follow) ให้เลือก'), findsOneWidget);
  });

  testWidgets(
      'shows every mutual-follow with a Switch, ON for the ones already '
      'in close_friends', (tester) async {
    followRepository.mutualFollows = [
      const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
      const Profile(id: 'u2', username: 'kai', displayName: 'Kai'),
    ];
    followRepository.closeFriends = [const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah')];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('@namfah'), findsOneWidget);
    expect(find.text('@kai'), findsOneWidget);

    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.length, 2);
    expect(switches[0].value, isTrue); // namfah
    expect(switches[1].value, isFalse); // kai
  });

  testWidgets('toggling ON calls addCloseFriend and flips the Switch',
      (tester) async {
    followRepository.mutualFollows = [
      const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
    ];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(followRepository.addCloseFriendArgs, ['u1']);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('toggling OFF calls removeCloseFriend and flips the Switch',
      (tester) async {
    followRepository.mutualFollows = [
      const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
    ];
    followRepository.closeFriends = [const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah')];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(followRepository.removeCloseFriendArgs, ['u1']);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('a failed toggle reverts the Switch and shows an error',
      (tester) async {
    followRepository.mutualFollows = [
      const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
    ];
    followRepository.addCloseFriendError = Exception('network error');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
  });

  testWidgets(
      'showWelcomeBanner true + an empty close-friends list shows the '
      'welcome banner as the first item', (tester) async {
    followRepository.mutualFollows = [
      const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
    ];

    await tester.pumpWidget(buildScreen(showWelcomeBanner: true));
    await tester.pumpAndSettle();

    expect(
      find.text('คุณยังไม่มีเพื่อนที่สนิท เลือกจากรายชื่อเพื่อนของคุณได้เลย'),
      findsOneWidget,
    );
  });

  testWidgets('typing in the search bar filters the visible list',
      (tester) async {
    followRepository.mutualFollows = [
      const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
      const Profile(id: 'u2', username: 'kai', displayName: 'Kai'),
    ];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'nam');
    await tester.pumpAndSettle();

    expect(find.text('@namfah'), findsOneWidget);
    expect(find.text('@kai'), findsNothing);
  });

  testWidgets('a load failure shows an error with a retry button',
      (tester) async {
    followRepository.fetchMutualFollowsError = Exception('network error');

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('โหลดรายชื่อไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองใหม่'), findsOneWidget);
  });
}

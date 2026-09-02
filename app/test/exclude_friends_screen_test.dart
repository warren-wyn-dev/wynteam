import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/follow/presentation/exclude_friends_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/recording_follow_repository.dart';

void main() {
  late RecordingFollowRepository followRepository;

  setUp(() {
    followRepository = RecordingFollowRepository();
  });

  Widget buildScreen({Set<String> initiallySelected = const {}}) => MaterialApp(
        home: ExcludeFriendsScreen(
          followRepository: followRepository,
          initiallySelected: initiallySelected,
        ),
      );

  testWidgets('empty mutual-follow list shows the "no friends" empty state',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('คุณยังไม่มีเพื่อน (ติดตามกันทั้งสองทาง) ให้เลือก'),
        findsOneWidget);
  });

  testWidgets('shows every mutual-follow as a checkbox row, "เสร็จสิ้น" '
      'with no count when nothing is selected', (tester) async {
    followRepository.mutualFollows = [
      const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
      const Profile(id: 'u2', username: 'kai', displayName: 'Kai'),
    ];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('@namfah'), findsOneWidget);
    expect(find.text('@kai'), findsOneWidget);
    expect(find.text('เสร็จสิ้น'), findsOneWidget);
  });

  testWidgets(
      'tapping a row toggles its checkbox and updates the "เสร็จสิ้น (N)" '
      'count', (tester) async {
    followRepository.mutualFollows = [
      const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
      const Profile(id: 'u2', username: 'kai', displayName: 'Kai'),
    ];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('@namfah'));
    await tester.pump();

    expect(find.text('เสร็จสิ้น (1)'), findsOneWidget);
    final checkbox =
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile).first);
    expect(checkbox.value, isTrue);
  });

  testWidgets('tapping "เสร็จสิ้น" pops with the selected id set',
      (tester) async {
    followRepository.mutualFollows = [
      const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
      const Profile(id: 'u2', username: 'kai', displayName: 'Kai'),
    ];

    Set<String>? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<Set<String>>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ExcludeFriendsScreen(followRepository: followRepository),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('@namfah'));
    await tester.pump();
    await tester.tap(find.text('เสร็จสิ้น (1)'));
    await tester.pumpAndSettle();

    expect(result, {'u1'});
  });

  testWidgets('initiallySelected pre-checks those rows (returning to this '
      'screen a 2nd time in the same composing session)', (tester) async {
    followRepository.mutualFollows = [
      const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
      const Profile(id: 'u2', username: 'kai', displayName: 'Kai'),
    ];

    await tester.pumpWidget(buildScreen(initiallySelected: const {'u2'}));
    await tester.pumpAndSettle();

    expect(find.text('เสร็จสิ้น (1)'), findsOneWidget);
    final checkboxes =
        tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).toList();
    expect(checkboxes[0].value, isFalse); // namfah
    expect(checkboxes[1].value, isTrue); // kai
  });

  testWidgets('typing in the search bar filters the visible list',
      (tester) async {
    followRepository.mutualFollows = [
      const Profile(id: 'u1', username: 'namfah', displayName: 'Nam Fah'),
      const Profile(id: 'u2', username: 'kai', displayName: 'Kai'),
    ];

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'kai');
    await tester.pumpAndSettle();

    expect(find.text('@kai'), findsOneWidget);
    expect(find.text('@namfah'), findsNothing);
  });
}

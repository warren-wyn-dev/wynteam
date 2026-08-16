import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/mention_input.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_profile_repository.dart';

void main() {
  late RecordingProfileRepository profileRepo;
  late RecordingProfileRepository noMatchProfileRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    profileRepo = RecordingProfileRepository(
      searchResults: [
        const Profile(id: 'u1', username: 'namfah', displayName: 'น้ำฝน'),
      ],
    );
    noMatchProfileRepo = RecordingProfileRepository(searchResults: []);
  });

  Widget buildInput({
    required RecordingProfileRepository profileRepository,
    required TextEditingController controller,
    required ValueChanged<Set<String>> onMentionedUsersChanged,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: MentionInput(
            controller: controller,
            profileRepository: profileRepository,
            onMentionedUsersChanged: onMentionedUsersChanged,
          ),
        ),
      );

  testWidgets('typing @ followed by a query shows matching users after the debounce',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(buildInput(
      profileRepository: profileRepo,
      controller: controller,
      onMentionedUsersChanged: (_) {},
    ));

    await tester.enterText(find.byType(TextField), 'สวัสดี @nam');
    await tester.pump(const Duration(milliseconds: 500));

    expect(profileRepo.searchProfilesCalls, 1);
    expect(profileRepo.searchProfilesQueryArgs, ['nam']);
    expect(find.text('น้ำฝน'), findsOneWidget);
    expect(find.text('@namfah'), findsOneWidget);
  });

  testWidgets('does not search while just "@" has been typed with no query yet',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(buildInput(
      profileRepository: profileRepo,
      controller: controller,
      onMentionedUsersChanged: (_) {},
    ));

    await tester.enterText(find.byType(TextField), 'สวัสดี @');
    await tester.pump(const Duration(milliseconds: 500));

    expect(profileRepo.searchProfilesCalls, 0);
  });

  testWidgets('a space after @query closes the mention token -- no dropdown',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(buildInput(
      profileRepository: profileRepo,
      controller: controller,
      onMentionedUsersChanged: (_) {},
    ));

    await tester.enterText(find.byType(TextField), '@nam ต่อ');
    await tester.pump(const Duration(milliseconds: 500));

    expect(profileRepo.searchProfilesCalls, 0);
    expect(find.byKey(const Key('mention_suggestions_list')), findsNothing);
  });

  testWidgets('shows nothing when there are no matching users', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(buildInput(
      profileRepository: noMatchProfileRepo,
      controller: controller,
      onMentionedUsersChanged: (_) {},
    ));

    await tester.enterText(find.byType(TextField), '@zzz');
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('mention_suggestions_list')), findsNothing);
  });

  testWidgets(
      'selecting a suggestion inserts "@username " at the caret and reports the '
      'resolved user id', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    Set<String> reported = {};

    await tester.pumpWidget(buildInput(
      profileRepository: profileRepo,
      controller: controller,
      onMentionedUsersChanged: (ids) => reported = ids,
    ));

    await tester.enterText(find.byType(TextField), 'สวัสดี @nam');
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('น้ำฝน'));
    await tester.pump();

    expect(controller.text, 'สวัสดี @namfah ');
    expect(reported, {'u1'});
    expect(find.byKey(const Key('mention_suggestions_list')), findsNothing);
  });
}

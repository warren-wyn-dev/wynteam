import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/mention_input.dart';
import 'package:wyn/features/hashtag/data/hashtag_repository.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_profile_repository.dart';

void main() {
  late RecordingProfileRepository profileRepo;
  late RecordingProfileRepository noMatchProfileRepo;
  // WYNOS V1.0.0 Beta requirement 7 -- constructed once in setUpAll, same
  // "not inline inside a testWidgets body" discipline as the other
  // Recording* repos here (avoids a leaked GoTrue auto-refresh timer per
  // .wyn/learning/PATTERNS.md).
  late RecordingDropRepository hashtagDropRepo;
  late RecordingClubPostRepository hashtagClubPostRepo;
  late HashtagRepository hashtagRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    hashtagDropRepo = RecordingDropRepository();
    hashtagClubPostRepo = RecordingClubPostRepository();
    hashtagRepo = HashtagRepository.from(
      dropRepository: hashtagDropRepo,
      clubPostRepository: hashtagClubPostRepo,
    );
  });

  setUp(() {
    profileRepo = RecordingProfileRepository(
      searchResults: [
        const Profile(id: 'u1', username: 'namfah', displayName: 'น้ำฝน'),
      ],
    );
    noMatchProfileRepo = RecordingProfileRepository(searchResults: []);
    hashtagDropRepo.hashtagSuggestionCaptionsToReturn = [];
    hashtagClubPostRepo.hashtagSuggestionContentToReturn = [];
  });

  Widget buildInput({
    required RecordingProfileRepository profileRepository,
    required TextEditingController controller,
    required ValueChanged<Set<String>> onMentionedUsersChanged,
    HashtagRepository? hashtagRepository,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: MentionInput(
            controller: controller,
            profileRepository: profileRepository,
            hashtagRepository: hashtagRepository,
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

  group('hashtag suggestions (WYNOS V1.0.0 Beta requirement 7)', () {
    testWidgets(
        'typing # followed by a query shows matching hashtags with post '
        'counts, ranked by count', (tester) async {
      hashtagDropRepo.hashtagSuggestionCaptionsToReturn = [
        '#เกมมือถือ สนุกมาก',
        '#เกมมือถือ อีกโพสต์',
        '#เกม ทั่วไป',
      ];
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildInput(
        profileRepository: profileRepo,
        controller: controller,
        onMentionedUsersChanged: (_) {},
        hashtagRepository: hashtagRepo,
      ));

      await tester.enterText(find.byType(TextField), 'สนใจ #เกม');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('hashtag_suggestions_list')), findsOneWidget);
      expect(find.text('#เกมมือถือ'), findsOneWidget);
      expect(find.text('2 โพสต์'), findsOneWidget);
      expect(find.text('#เกม'), findsOneWidget);
      expect(find.text('1 โพสต์'), findsOneWidget);
    });

    testWidgets('does not search while just "#" has been typed with no '
        'query yet', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildInput(
        profileRepository: profileRepo,
        controller: controller,
        onMentionedUsersChanged: (_) {},
        hashtagRepository: hashtagRepo,
      ));

      await tester.enterText(find.byType(TextField), 'สนใจ #');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('hashtag_suggestions_list')), findsNothing);
    });

    testWidgets('selecting a hashtag suggestion inserts "#tag " at the '
        'caret', (tester) async {
      hashtagDropRepo.hashtagSuggestionCaptionsToReturn = ['#เกมมือถือ สนุก'];
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildInput(
        profileRepository: profileRepo,
        controller: controller,
        onMentionedUsersChanged: (_) {},
        hashtagRepository: hashtagRepo,
      ));

      await tester.enterText(find.byType(TextField), 'สนใจ #เกม');
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('#เกมมือถือ'));
      await tester.pump();

      expect(controller.text, 'สนใจ #เกมมือถือ ');
      expect(find.byKey(const Key('hashtag_suggestions_list')), findsNothing);
    });

    testWidgets('mention suggestions take priority and clear any showing '
        'hashtag suggestions when the caret moves into an @token',
        (tester) async {
      hashtagDropRepo.hashtagSuggestionCaptionsToReturn = ['#เกมมือถือ สนุก'];
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildInput(
        profileRepository: profileRepo,
        controller: controller,
        onMentionedUsersChanged: (_) {},
        hashtagRepository: hashtagRepo,
      ));

      await tester.enterText(find.byType(TextField), '#เกม');
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const Key('hashtag_suggestions_list')), findsOneWidget);

      await tester.enterText(find.byType(TextField), '#เกม @nam');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('hashtag_suggestions_list')), findsNothing);
      expect(find.byKey(const Key('mention_suggestions_list')), findsOneWidget);
    });

    // Whether MentionInput falls back to a real Supabase-backed
    // HashtagRepository when none is supplied (see the class doc
    // comment on MentionInput.hashtagRepository) isn't exercised here --
    // that would require a real network round-trip against the fake
    // Supabase project URL, unlike every other case in this file, which
    // only ever talks to a Recording* fake. The lazy-construction fix
    // itself is covered by create_drop_screen_test.dart's suite (every
    // one of its widget tests renders MentionInput with no
    // hashtagRepository and never touches Supabase.instance as a
    // result, since none of them type "#").
  });
}

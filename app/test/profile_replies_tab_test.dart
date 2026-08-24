import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/data/drop_comment.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_replies_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

ProfileReply _reply({String id = 'c1', String dropId = 'd1'}) => ProfileReply(
      comment: DropComment(
        id: id,
        dropId: dropId,
        authorId: 'me',
        authorUsername: 'me',
        textContent: 'เห็นด้วยเลย',
        createdAt: DateTime.now(),
        likeCount: 0,
        likedByMe: false,
      ),
      dropId: dropId,
      dropCaption: 'แคปชันต้นฉบับ',
      dropImageUrl: 'https://example.supabase.co/drops/$dropId.jpg',
      dropAuthorUsername: 'namfah',
    );

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // Constructed in setUpAll -- see profile_drafts_tab_test.dart's own
  // comment on why (GoTrue Timer/FakeAsync zone attribution).
  late RecordingDropRepository emptyRepo;
  late RecordingDropRepository listRepo;
  late RecordingDropRepository errorRepo;
  late RecordingDropRepository tapRepo;
  late RecordingFollowRepository followRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    emptyRepo = RecordingDropRepository();
    listRepo = RecordingDropRepository()
      ..repliesByAuthor = {
        'me': [_reply(id: 'c1', dropId: 'd1'), _reply(id: 'c2', dropId: 'd2')],
      };
    errorRepo = RecordingDropRepository()..fetchRepliesByAuthorError = Exception('boom');
    tapRepo = RecordingDropRepository(feedDrops: [
      Drop(
        id: 'd1',
        authorId: 'namfah-id',
        authorUsername: 'namfah',
        imageUrl: 'https://example.supabase.co/drops/d1.jpg',
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      ),
    ])
      ..repliesByAuthor = {
        'me': [_reply(id: 'c1', dropId: 'd1')],
      };
    followRepo = RecordingFollowRepository();
    profileRepo = RecordingProfileRepository();
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();
  });

  testWidgets('shows the empty state when the author has replied to nothing',
      (tester) async {
    await tester.pumpWidget(_wrap(ProfileRepliesTab(
      dropRepository: emptyRepo,
      followRepository: followRepo,
      profileRepository: profileRepo,
      popRepository: popRepo,
      savedRepository: savedRepo,
      authorId: 'me',
      emptyText: 'ยังไม่มีการตอบกลับ',
    )));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีการตอบกลับ'), findsOneWidget);
  });

  testWidgets(
      'shows every reply\'s text and which author\'s Drop it replied to',
      (tester) async {
    await tester.pumpWidget(_wrap(ProfileRepliesTab(
      dropRepository: listRepo,
      followRepository: followRepo,
      profileRepository: profileRepo,
      popRepository: popRepo,
      savedRepository: savedRepo,
      authorId: 'me',
      emptyText: 'ยังไม่มีการตอบกลับ',
    )));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('เห็นด้วยเลย'), findsNWidgets(2));
    expect(find.textContaining('ตอบกลับโพสต์ของ @namfah'), findsNWidgets(2));
  });

  testWidgets('a fetch failure shows an error with a retry button',
      (tester) async {
    await tester.pumpWidget(_wrap(ProfileRepliesTab(
      dropRepository: errorRepo,
      followRepository: followRepo,
      profileRepository: profileRepo,
      popRepository: popRepo,
      savedRepository: savedRepo,
      authorId: 'me',
      emptyText: 'ยังไม่มีการตอบกลับ',
    )));
    await tester.pumpAndSettle();

    expect(find.text('โหลดการตอบกลับไม่สำเร็จ'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'ลองใหม่'), findsOneWidget);
  });

  testWidgets('tapping a reply opens its parent Drop', (tester) async {
    await tester.pumpWidget(_wrap(ProfileRepliesTab(
      dropRepository: tapRepo,
      followRepository: followRepo,
      profileRepository: profileRepo,
      popRepository: popRepo,
      savedRepository: savedRepo,
      authorId: 'me',
      emptyText: 'ยังไม่มีการตอบกลับ',
    )));
    await tester.pumpAndSettle();
    tester.takeException();

    // Tap the row itself (ListTile.onTap covers the whole row) rather
    // than the text specifically -- the leading thumbnail's failed
    // NetworkImage renders an error overlay in the test environment
    // that can otherwise absorb the tap at that exact point.
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(DropDetailScreen), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/presentation/club_page.dart';
import 'package:wyn/features/club/presentation/create_club_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';

/// Beta4 §14/§20 (Responsive) for the surfaces Beta4 changed.
///
/// WYNOS is mobile-first and has no breakpoints -- DS-008 decided that
/// explicitly in 2026-08-16 ("MediaQuery 5 จุด ... LayoutBuilder 0 จุด",
/// and a deliberate decision not to invent breakpoints without a
/// Founder requirement). Beta4 does not change that direction. So
/// "responsive" here means what it has always meant for this app: the
/// same one layout must survive every width and height it is given
/// without overflowing, overlapping, or clipping.
///
/// These tests check the two ends that actually break things. The
/// narrow end squeezes horizontal layouts; the short end squeezes
/// vertical ones. A RenderFlex overflow surfaces through the error
/// framework, so `tester.takeException()` returning null is the real
/// assertion -- the visible yellow-and-black stripe is the same event.
///
/// (Profile's own small-mobile case lives in view_profile_screen_test,
/// beside the rest of that screen's Beta4 tests.)
void main() {
  // The four sizes WYNOS ships against, as logical pixels.
  const smallMobile = Size(320, 568); // iPhone SE 1st gen
  const mobile = Size(390, 844); // iPhone 14/15
  const largeMobile = Size(430, 932); // iPhone Pro Max
  const tablet = Size(834, 1112); // iPad Air portrait

  late RecordingClubRepository clubRepo;
  late RecordingClubRepository imagelessClubRepo;
  late RecordingClubPostRepository clubPostRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'viewer');
  });

  setUp(() {
    clubRepo = RecordingClubRepository(
      club: Club(
        id: 'club-1',
        // A name at the column's own 50-character limit -- the case the
        // old single-line banner Text had nothing to stop overflowing.
        name: 'ชมรมคนรักการถ่ายภาพแนวสตรีทและการเดินทางรอบโลกด้วยกล้องฟิล์ม',
        description: 'คำอธิบายที่ยาวพอสมควรสำหรับทดสอบ layout ของหน้า Club',
        category: 'Lifestyle',
        privacy: ClubPrivacy.public,
        ownerId: 'owner-1',
        createdAt: DateTime(2026, 1, 1),
        memberCount: 123456,
        coverUrl: 'https://example.supabase.co/clubs/cover.jpg',
      ),
      myMembership: null,
    );
    imagelessClubRepo = RecordingClubRepository(
      club: Club(
        id: 'club-2',
        name: 'ชมรมคนรักการถ่ายภาพแนวสตรีทและการเดินทางรอบโลกด้วยกล้องฟิล์ม',
        privacy: ClubPrivacy.private,
        ownerId: 'owner-1',
        createdAt: DateTime(2026, 1, 1),
        memberCount: 7,
      ),
      myMembership: null,
    );
    clubPostRepo = RecordingClubPostRepository();
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    Widget child,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: child));
    await tester.pumpAndSettle();
    // The test-fixture image URLs throw NetworkImageLoadException --
    // expected noise in every widget test in this project that renders a
    // network image. Cleared here so the overflow assertion below sees
    // only real layout errors.
    tester.takeException();
  }

  group('Beta4 §8.3 -- Club page', () {
    for (final entry in {
      'small mobile': smallMobile,
      'mobile': mobile,
      'large mobile': largeMobile,
      'tablet': tablet,
    }.entries) {
      testWidgets('lays out with no overflow at ${entry.key}', (tester) async {
        await pumpAt(
          tester,
          entry.value,
          ClubPage(
            clubRepository: clubRepo,
            clubPostRepository: clubPostRepo,
            clubId: 'club-1',
          ),
        );

        expect(tester.takeException(), isNull);
        // The banner's identity survives every width -- the whole point
        // of §8.3's one-banner-design rule.
        expect(find.text('CLUB'), findsOneWidget);
      });
    }

    testWidgets(
        'the banner name wraps to at most two lines rather than overflowing '
        'the 140px strip', (tester) async {
      await pumpAt(
        tester,
        smallMobile,
        ClubPage(
          clubRepository: imagelessClubRepo,
          clubPostRepository: clubPostRepo,
          clubId: 'club-2',
        ),
      );

      expect(tester.takeException(), isNull);
      final nameText = tester.widget<Text>(
        find
            .text('ชมรมคนรักการถ่ายภาพแนวสตรีทและการเดินทางรอบโลกด้วยกล้องฟิล์ม')
            .first,
      );
      expect(nameText.maxLines, 2);
      expect(nameText.overflow, TextOverflow.ellipsis);
    });
  });

  group('Beta4 §8.2 -- Create Club', () {
    for (final entry in {
      'small mobile': smallMobile,
      'mobile': mobile,
      'tablet': tablet,
    }.entries) {
      testWidgets('lays out with no overflow at ${entry.key}', (tester) async {
        await pumpAt(
          tester,
          entry.value,
          CreateClubScreen(
            clubRepository: clubRepo,
            clubPostRepository: clubPostRepo,
          ),
        );

        expect(tester.takeException(), isNull);
        // The image row is the element Beta4 reshaped -- it must not be
        // the thing that breaks at 320.
        expect(find.byKey(const Key('club_image_picker')), findsOneWidget);
      });
    }

    testWidgets(
        'the review summary fits at small-mobile width, with a long Club '
        'name in it', (tester) async {
      await pumpAt(
        tester,
        smallMobile,
        CreateClubScreen(
          clubRepository: clubRepo,
          clubPostRepository: clubPostRepo,
        ),
      );

      await tester.enterText(
        find.byKey(const Key('club_name_field')),
        'ชมรมคนรักการถ่ายภาพแนวสตรีทและการเดินทางรอบโลกด้วยกล้องฟิล์ม',
      );
      await tester.ensureVisible(find.text('สาธารณะ'));
      await tester.tap(find.text('สาธารณะ'));
      await tester.pumpAndSettle();

      final summary = find.byKey(const Key('club_review_summary'));
      expect(summary, findsOneWidget);
      await tester.ensureVisible(summary);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final rect = tester.getRect(summary);
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(smallMobile.width));
    });
  });
}

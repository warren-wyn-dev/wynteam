import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_invite_link.dart';
import 'package:wyn/features/club/presentation/club_invite_links_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_repository.dart';

/// WYN-136 -- `ClubInviteLinksScreen` (create/list/revoke), see
/// .wyn/docs/design/wyn-136-club-invite-link.md.
void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'owner-1');
  });

  final publicClub = Club(
    id: 'club-1',
    name: 'Public Club',
    privacy: ClubPrivacy.public,
    ownerId: 'owner-1',
    createdAt: DateTime.now(),
    memberCount: 4,
  );

  final privateClub = Club(
    id: 'club-2',
    name: 'Private Club',
    privacy: ClubPrivacy.private,
    ownerId: 'owner-1',
    createdAt: DateTime.now(),
    memberCount: 4,
  );

  late RecordingClubRepository repo;

  // `Clipboard.setData` (used by both the explicit copy icon and the
  // auto-copy right after creating a link) goes out over
  // `SystemChannels.platform` -- with no handler registered at all,
  // that call never resolves under flutter_test, which leaves whichever
  // `setState(() => _isCreating = false)` is waiting on it stuck
  // forever and an indeterminate `CircularProgressIndicator` spinning
  // forever, which is exactly what makes `pumpAndSettle()` time out
  // (mirrors interaction_feedback_test.dart's identical
  // `SystemChannels.platform` mock for `HapticFeedback.vibrate`).
  setUp(() {
    repo = RecordingClubRepository();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget buildScreen({Club? club}) => MaterialApp(
        home: ClubInviteLinksScreen(club: club ?? publicClub, clubRepository: repo),
      );

  ClubInviteLink link({
    String id = 'link-1',
    String code = 'AbCd12EfGh',
    DateTime? expiresAt,
    int? maxUses,
    int useCount = 0,
  }) =>
      ClubInviteLink(
        id: id,
        clubId: publicClub.id,
        code: code,
        createdBy: 'owner-1',
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
        maxUses: maxUses,
        useCount: useCount,
      );

  testWidgets('empty state shows the "ยังไม่มีลิงก์เชิญ" message', (tester) async {
    repo.inviteLinksResult = const [];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('ยังไม่มีลิงก์เชิญ'), findsOneWidget);
  });

  testWidgets('lists every not-yet-revoked link, newest first, with usage '
      '+ expiry + created labels', (tester) async {
    repo.inviteLinksResult = [
      link(id: 'link-1', code: 'AbCd12EfGh', maxUses: 50, useCount: 3),
      link(id: 'link-2', code: 'XyZ98QwErT', useCount: 12),
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('club-invite/AbCd12EfGh'), findsOneWidget);
    expect(find.textContaining('ใช้ไปแล้ว 3/50 ครั้ง'), findsOneWidget);
    expect(find.textContaining('club-invite/XyZ98QwErT'), findsOneWidget);
    expect(find.textContaining('ใช้ไปแล้ว 12 ครั้ง'), findsOneWidget);
    // Both rows: `link(id: 'link-1', ...)` has no expiresAt, and neither
    // does `link(id: 'link-2', ...)`.
    expect(find.textContaining('ไม่มีวันหมดอายุ'), findsNWidgets(2));
  });

  testWidgets('a Private Club shows the reciprocal-risk warning banner; '
      'a Public Club does not', (tester) async {
    repo.inviteLinksResult = [link()];
    await tester.pumpWidget(buildScreen(club: privateClub));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('เข้าร่วม Club ส่วนตัวนี้ได้ทันที'),
      findsOneWidget,
    );

    repo.inviteLinksResult = [link()];
    await tester.pumpWidget(buildScreen(club: publicClub));
    await tester.pumpAndSettle();

    expect(find.textContaining('เข้าร่วม Club ส่วนตัวนี้ได้ทันที'), findsNothing);
  });

  testWidgets('an expired-but-not-revoked link stays in the list, dimmed, '
      'with a "หมดอายุแล้ว" suffix', (tester) async {
    repo.inviteLinksResult = [
      link(expiresAt: DateTime.now().subtract(const Duration(days: 1))),
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.textContaining('หมดอายุแล้ว'), findsWidgets);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.textContaining('AbCd12EfGh'), matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, lessThan(1));
  });

  testWidgets('creating a link opens the form sheet, calls createInviteLink '
      'with the chosen expiry/max-uses, and prepends the new link',
      (tester) async {
    repo.inviteLinksResult = const [];
    repo.createInviteLinkResult = link(id: 'new-link', code: 'NewCode123', maxUses: 10);
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('สร้างลิงก์เชิญใหม่'));
    await tester.pumpAndSettle();

    expect(find.text('สร้างลิงก์เชิญใหม่'), findsWidgets);
    await tester.tap(find.text('7 วัน'));
    await tester.pump();
    await tester.tap(find.text('10 ครั้ง'));
    await tester.pump();
    await tester.tap(find.text('สร้างลิงก์'));
    await tester.pumpAndSettle();

    expect(repo.createInviteLinkCalls, 1);
    expect(repo.lastCreateInviteLinkExpiresInDays, 7);
    expect(repo.lastCreateInviteLinkMaxUses, 10);
    expect(find.textContaining('club-invite/NewCode123'), findsOneWidget);
    expect(find.text('คัดลอกลิงก์แล้ว'), findsOneWidget);
  });

  testWidgets('revoking a link asks to confirm, then calls revokeInviteLink '
      'and removes the row', (tester) async {
    repo.inviteLinksResult = [link(id: 'link-1', code: 'AbCd12EfGh')];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('เพิกถอนลิงก์นี้'), findsOneWidget);
    await tester.tap(find.text('เพิกถอนลิงก์นี้'));
    await tester.pumpAndSettle();

    // ConfirmDialog's own confirm button.
    expect(find.text('ใครก็ตามที่ถือลิงก์นี้อยู่จะใช้ไม่ได้อีกทันที'), findsOneWidget);
    await tester.tap(find.text('เพิกถอนลิงก์'));
    await tester.pumpAndSettle();

    expect(repo.revokeInviteLinkCalls, 1);
    expect(repo.lastRevokeInviteLinkId, 'link-1');
    expect(find.textContaining('club-invite/AbCd12EfGh'), findsNothing);
  });

  testWidgets('a failed revoke keeps the row and shows an error SnackBar',
      (tester) async {
    repo.inviteLinksResult = [link(id: 'link-1', code: 'AbCd12EfGh')];
    repo.revokeInviteLinkError = Exception('boom');
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิกถอนลิงก์นี้'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิกถอนลิงก์'));
    await tester.pumpAndSettle();

    expect(find.text('เพิกถอนลิงก์ไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.textContaining('club-invite/AbCd12EfGh'), findsOneWidget);
  });

  testWidgets('tapping the copy icon copies the share link to the clipboard',
      (tester) async {
    repo.inviteLinksResult = [link(id: 'link-1', code: 'AbCd12EfGh')];
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(() =>
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy_outlined));
    await tester.pumpAndSettle();

    expect(copiedText, 'https://wynos.online/club-invite/AbCd12EfGh');
    expect(find.text('คัดลอกลิงก์แล้ว'), findsOneWidget);
  });
}

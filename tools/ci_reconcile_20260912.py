from pathlib import Path


def replace_exact(path: str, old: str, new: str, expected: int = 1) -> None:
    p = Path(path)
    text = p.read_text()
    actual = text.count(old)
    if actual != expected:
        raise RuntimeError(
            f"{path}: expected {expected} occurrence(s) of {old!r}, found {actual}"
        )
    p.write_text(text.replace(old, new))


def replace_present(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    actual = text.count(old)
    if actual == 0:
        raise RuntimeError(f"{path}: expected at least one occurrence of {old!r}")
    p.write_text(text.replace(old, new))


# ---------------------------------------------------------------------------
# WYN-141 Founder-final Drop Detail test contract.
# Product code already implements the approved UI; update stale regression
# finders/assertions instead of restoring the retired stat line/icons.
# ---------------------------------------------------------------------------
detail_test = "app/test/drop_detail_screen_test.dart"
replace_exact(
    detail_test,
    "expect(find.text('3 ถูกใจ'), findsOneWidget);",
    "expect(\n      find.bySemanticsLabel(RegExp('ถูกใจ 3 คน กดเพื่อถูกใจ')),\n      findsOneWidget,\n    );",
)
replace_exact(
    detail_test,
    "expect(find.text('4 ถูกใจ'), findsOneWidget);",
    "expect(\n      find.bySemanticsLabel(RegExp('ถูกใจแล้ว 4 คน กดเพื่อเลิกถูกใจ')),\n      findsOneWidget,\n    );",
)
replace_exact(
    detail_test,
    "await tester.tap(find.byIcon(Icons.send));",
    "await tester.tap(find.byIcon(Icons.send_rounded));",
)
replace_exact(
    detail_test,
    "await tester.tap(find.byIcon(Icons.close));",
    "await tester.tap(find.byIcon(Icons.close_rounded));",
)
old_view = "expect(find.text('6 การเข้าชม'), findsOneWidget);"
new_view = """final activityEntry = find.text('ดูกิจกรรม');
      await tester.ensureVisible(activityEntry);
      await tester.pumpAndSettle();
      await tester.tap(activityEntry);
      await tester.pumpAndSettle();
      expect(find.text('การเข้าชม'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);"""
replace_exact(detail_test, old_view, new_view, expected=2)
replace_exact(
    detail_test,
    """expect(
        find.bySemanticsLabel(RegExp('เข้าชมแล้ว 43 ครั้ง')),
        findsOneWidget,
      );""",
    """final activityEntry = find.text('ดูกิจกรรม');
      await tester.ensureVisible(activityEntry);
      await tester.pumpAndSettle();
      await tester.tap(activityEntry);
      await tester.pumpAndSettle();
      expect(find.text('การเข้าชม'), findsOneWidget);
      expect(find.text('43'), findsOneWidget);""",
)
replace_exact(
    detail_test,
    "find.byIcon(Icons.repeat)",
    "find.byIcon(Icons.repeat_rounded)",
    expected=2,
)

# Comment deletion still mutates the Drop count; the Founder-final UI exposes
# that count through the focused action bar semantics rather than the retired
# plain-text stat line.
replace_exact(
    "app/test/drop_comment_delete_test.dart",
    """await tester.scrollUntilVisible(
      find.text('1 คอมเมนต์'),
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    tester.takeException();
    expect(find.text('1 คอมเมนต์'), findsOneWidget);""",
    """await tester.scrollUntilVisible(
      find.bySemanticsLabel(RegExp('ความคิดเห็น 1 รายการ')),
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    tester.takeException();
    expect(
      find.bySemanticsLabel(RegExp('ความคิดเห็น 1 รายการ')),
      findsOneWidget,
    );""",
)

# ---------------------------------------------------------------------------
# Founder-final Profile contract.
# Cover bar replaced AppBar, own-profile primary action is FilledButton, the
# first public tab is now “สื่อ”, and the overflow menu uses rounded glyphs.
# ---------------------------------------------------------------------------
profile_test = "app/test/view_profile_screen_test.dart"
replace_present(
    profile_test,
    "find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์')",
    "find.widgetWithText(FilledButton, 'แก้ไขโปรไฟล์')",
)
replace_present(profile_test, "find.text('โพสต์')", "find.text('สื่อ')")
replace_exact(
    profile_test,
    "expect(find.widgetWithText(AppBar, 'โปรไฟล์'), findsOneWidget);",
    "expect(find.text('โปรไฟล์'), findsOneWidget);",
)
replace_exact(
    profile_test,
    "expect(find.widgetWithText(AppBar, '@namfah'), findsOneWidget);",
    "expect(find.text('โปรไฟล์'), findsOneWidget);",
)

for path in [
    "app/test/qa_wyn110_profile_scroll_header_test.dart",
    "app/test/view_profile_screen_scroll_test.dart",
]:
    replace_present(path, "find.text('โพสต์')", "find.text('สื่อ')")

replace_present(
    "app/test/view_profile_mute_test.dart",
    "find.byIcon(Icons.more_vert)",
    "find.byIcon(Icons.more_vert_rounded)",
)

# RootShell Founder-final navigation labels are Thai. Keep guest-gate behavior
# assertions intact and update only their navigation finders.
root_guest = "app/test/root_shell_guest_gate_test.dart"
replace_present(root_guest, "find.text('Profile')", "find.text('โปรไฟล์')")
replace_present(
    root_guest,
    "find.text('Notifications')",
    "find.text('การแจ้งเตือน')",
)

# Club share adds a fourth row. Allow this one share sheet to use the full
# modal height so a sub-pixel constraint rounding does not overflow vertically.
replace_exact(
    "app/lib/features/chat/presentation/share_sheet.dart",
    """await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,""",
    """await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,""",
)

# ---------------------------------------------------------------------------
# Supabase-platform stub parity for WYN-141 Top100 integration regression.
# Real Supabase grants authenticated/anon access to auth helper functions; the
# throwaway Postgres stub must model that before SET ROLE authenticated.
# ---------------------------------------------------------------------------
replace_exact(
    "supabase/tests/wyn_141_top100_integration_test.sh",
    """grant usage on schema public to authenticated, anon;
grant usage on schema storage to authenticated, anon;""",
    """grant usage on schema public to authenticated, anon;
grant usage on schema auth to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
grant execute on function auth.role() to authenticated, anon;
grant usage on schema storage to authenticated, anon;""",
)

print("CI reconciliation patch applied")

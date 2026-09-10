from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, found {count}")
    return text.replace(old, new, 1)


# 1) Keep the accepted cover, but remove the back affordance from the profile
# cover bar. Share/settings and the Profile title stay intact.
view_path = ROOT / "app/lib/features/profile/presentation/view_profile_screen.dart"
view = view_path.read_text(encoding="utf-8")

old_go_back = '''  Widget _buildProfileCoverBar(Profile profile, bool isOwnProfile) {
    void goBack() {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        widget.onRootBack?.call();
      }
    }

'''
new_go_back = '''  Widget _buildProfileCoverBar(Profile profile, bool isOwnProfile) {
'''
view = replace_once(view, old_go_back, new_go_back, "remove profile back callback")

old_back_button = '''                IconButton(
                  tooltip: 'ย้อนกลับ',
                  icon: const Icon(
                    Icons.chevron_left_rounded,
                    size: 32,
                    color: WynColors.paper,
                  ),
                  onPressed: goBack,
                ),
'''
view = replace_once(view, old_back_button, "", "remove profile back button")
view_path.write_text(view, encoding="utf-8")


# 2) Put @username on the same visual line as the display name, matching the
# latest approved mockup, and remove the old second-line username.
header_path = ROOT / "app/lib/features/profile/presentation/widgets/wynos_founder_profile_header.dart"
header = header_path.read_text(encoding="utf-8")

verified_block = '''        if (profile.isVerified) ...[
          const SizedBox(width: 4),
          const VerifiedBadge(),
        ],
        if (isOwnProfile) ...[
'''
verified_replacement = '''        if (profile.isVerified) ...[
          const SizedBox(width: 4),
          const VerifiedBadge(),
        ],
        const SizedBox(width: 8),
        Text(
          '@${profile.username}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.1,
            color: WynColors.graphite,
            fontWeight: FontWeight.w400,
          ),
        ),
        if (isOwnProfile) ...[
'''
header = replace_once(
    header,
    verified_block,
    verified_replacement,
    "username beside display name",
)

old_username_line = '''                      const SizedBox(height: 3),
                      Text(
                        '@${profile.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          height: 1.1,
                          color: WynColors.graphite,
                        ),
                      ),
'''
header = replace_once(header, old_username_line, "", "remove old username line")
header_path.write_text(header, encoding="utf-8")


# 3) Regression test: the username should be horizontally beside the display
# name (same row), not below it.
test_path = ROOT / "app/test/wynos_founder_profile_header_test.dart"
test = test_path.read_text(encoding="utf-8")
marker = '''  testWidgets('own display-name switcher keeps a 44px accessible tap target',
'''
insert = '''  testWidgets('username sits beside display name on the same row',
      (tester) async {
    await tester.pumpWidget(buildHeader());

    final name = tester.getRect(find.text('หาเพื่อนคุย'));
    final username = tester.getRect(find.text('@kkcu52'));
    expect(username.left, greaterThan(name.left));
    expect((username.center.dy - name.center.dy).abs(), lessThan(8));
  });

'''
if test.count(marker) != 1:
    raise SystemExit("test insertion marker not unique")
test = test.replace(marker, insert + marker, 1)
test_path.write_text(test, encoding="utf-8")

print("Applied latest approved Profile layout patch")

from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"expected one match in {path} but found {count}: {old[:120]!r}")
    path.write_text(text.replace(old, new, 1))


# Home header / tabs ---------------------------------------------------------
home = Path('app/lib/features/home/presentation/home_feed_screen.dart')
replace_once(
    home,
    """    return WynosSocialHeader(\n      title: 'WYNOS',\n""",
    """    return WynosSocialHeader(\n      title: 'WYNOS',\n      // Keep the 48px actions fully tappable while pulling the feed tabs\n      // 8px closer to the WYNOS wordmark. Home is intentionally denser\n      // than the generic social-screen header; other screens keep 60px.\n      height: 52,\n      showBottomDivider: false,\n""",
)
replace_once(home, "      scrollable: true,\n", "      scrollable: false,\n")
replace_once(home, "          label: 'ติดตาม',\n", "          label: 'กำลังติดตาม',\n")
replace_once(home, "          label: 'Club',\n", "          label: 'คลับของฉัน',\n")


# Shared header keeps its existing default, but Home may request a denser
# height without changing every other screen that uses WynosSocialHeader.
chrome = Path('app/lib/core/widgets/wynos_social_chrome.dart')
replace_once(
    chrome,
    """    this.trailing,\n    this.titleWidget,\n    this.showBottomDivider = true,\n  });\n\n  final String title;\n  final Widget? leading;\n  final Widget? trailing;\n  final Widget? titleWidget;\n  final bool showBottomDivider;\n""",
    """    this.trailing,\n    this.titleWidget,\n    this.showBottomDivider = true,\n    this.height = WynosSocialChrome.headerHeight,\n  });\n\n  final String title;\n  final Widget? leading;\n  final Widget? trailing;\n  final Widget? titleWidget;\n  final bool showBottomDivider;\n  final double height;\n""",
)
replace_once(
    chrome,
    "      height: WynosSocialChrome.headerHeight,\n",
    "      height: height,\n",
)


# Feed cards ----------------------------------------------------------------
card = Path('app/lib/features/home/presentation/widgets/home_drop_card.dart')
replace_once(
    card,
    """          // Compact post header: 8px above the author row and 16px\n          // below the card. The reduced top gap, one-line author/time row,\n          // and tighter caption spacing pull media/caption upward without\n          // changing the card's horizontal alignment.\n          padding: const EdgeInsets.fromLTRB(\n            0,\n            WynSpacing.space2,\n            0,\n            WynSpacing.space4,\n          ),\n""",
    """          // Threads-like compact rhythm: keep 8px above the author\n          // row, but only 8px after the action row before the divider.\n          // The card stays easy to scan without carrying a large blank tail.\n          padding: const EdgeInsets.fromLTRB(\n            0,\n            WynSpacing.space2,\n            0,\n            WynSpacing.space2,\n          ),\n""",
)
replace_once(
    card,
    """                            // WYN-107: no left inset -- the content column already\n                            // starts at the name. Only the right edge is held off\n                            // the screen. WYN-140: bottom bumped 8->12 so the\n                            // gap to whatever follows (poll/media, or the\n                            // action bar on a caption-only Drop) reads as a\n                            // deliberate break rather than a cramped one.\n                            padding: const EdgeInsets.fromLTRB(\n                              0,\n                              WynSpacing.space1,\n                              homeCardEdgeInset,\n                              WynSpacing.space3,\n                            ),\n""",
    """                            // WYN-107: no left inset -- the content column already\n                            // starts at the name. Compact feed polish removes the\n                            // extra top spacer and uses an 8px bottom rhythm so\n                            // caption -> media/action reads as one post, not two\n                            // vertically separated blocks.\n                            padding: const EdgeInsets.fromLTRB(\n                              0,\n                              0,\n                              homeCardEdgeInset,\n                              WynSpacing.space2,\n                            ),\n""",
)
replace_once(
    card,
    """                        // WYN-140: one fixed 12px gap after whatever media\n                        // rendered above (Poll/carousel/single image), same\n                        // value regardless of what follows it (LikedByRow or\n                        // straight to the action bar) -- previously this gap\n                        // was 0 with no LikedByRow and ~10 with one, an\n                        // inconsistency nothing asked for. Absent entirely for\n                        // a caption-only Drop, which has no media block to\n                        // follow -- the caption's own bottom padding already\n                        // provides the gap in that case.\n                        if (item.isPoll || item.imageUrl != null)\n                          const SizedBox(height: WynSpacing.space3),\n""",
    """                        // Compact feed polish: one fixed 8px gap after media\n                        // before liked-by/actions. Caption-only Drops already get\n                        // the same 8px from the caption's own bottom padding.\n                        if (item.isPoll || item.imageUrl != null)\n                          const SizedBox(height: WynSpacing.space2),\n""",
)


# Regression expectations ---------------------------------------------------
home_test = Path('app/test/home_feed_screen_test.dart')
text = home_test.read_text()
# In this test file, these two strings are the Home feed selector labels;
# HomeDropCard itself has no Follow button, so updating them is scoped safely.
text = text.replace("find.text('Club')", "find.text('คลับของฉัน')")
text = text.replace("find.text('ติดตาม')", "find.text('กำลังติดตาม')")
home_test.write_text(text)

root_test = Path('app/test/root_shell_test.dart')
text = root_test.read_text()
old = "expect(find.text('ติดตาม'), findsOneWidget);"
if old not in text:
    raise SystemExit('root_shell_test Home feed label assertion not found')
# RootShell only uses this exact assertion for Home's feed-mode toggle.
text = text.replace(old, "expect(find.text('กำลังติดตาม'), findsOneWidget);", 1)
root_test.write_text(text)

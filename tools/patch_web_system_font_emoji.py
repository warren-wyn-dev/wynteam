from pathlib import Path


def replace(path, old, new, count=1):
    p = Path(path)
    text = p.read_text()
    found = text.count(old)
    if found < count:
        raise SystemExit(
            f"{path}: expected at least {count} occurrence(s), found {found}: {old[:80]!r}"
        )
    p.write_text(text.replace(old, new, count))


# HashtagText: keep the existing native Flutter implementation, but use one
# browser DOM block on Web so both text and emoji come from the visitor's OS.
replace(
    "app/lib/core/widgets/hashtag_text.dart",
    "import '../text_utils.dart';\nimport '../typography/native_emoji.dart';",
    "import '../text_utils.dart';\nimport '../typography/browser_system_text.dart';\nimport '../typography/native_emoji.dart';",
)
replace(
    "app/lib/core/widgets/hashtag_text.dart",
    "    Text buildRichText(String text) {\n      final spans = <InlineSpan>[];",
    """    Widget buildRichText(String text) {
      if (usesBrowserSystemTextDom) {
        final browserSpans = <BrowserSystemSpan>[];
        var browserLastEnd = 0;
        for (final token in _findTokens(text)) {
          if (token.start < browserLastEnd) continue;
          if (token.start > browserLastEnd) {
            browserSpans.add(
              BrowserSystemSpan(text: text.substring(browserLastEnd, token.start)),
            );
          }
          browserSpans.add(
            BrowserSystemSpan(
              text: text.substring(token.start, token.end),
              style: token.kind == _SpanKind.hashtag ? hashtagStyle : mentionStyle,
              onTap: token.kind == _SpanKind.hashtag
                  ? () => _openHashtagFeed(token.value)
                  : () => _openMentionedProfile(token.value),
            ),
          );
          browserLastEnd = token.end;
        }
        if (browserLastEnd < text.length) {
          browserSpans.add(
            BrowserSystemSpan(text: text.substring(browserLastEnd)),
          );
        }
        return BrowserSystemRichText(
          spans: browserSpans,
          style: baseStyle,
          maxLines: widget.maxLines,
          overflow: widget.overflow ?? TextOverflow.clip,
          semanticsLabel: text,
        );
      }

      final spans = <InlineSpan>[];""",
)

# Home Drop card: visible author/timestamp/location/redrop metadata.
replace(
    "app/lib/features/home/presentation/widgets/home_drop_card.dart",
    "import '../../../../core/text_utils.dart';",
    "import '../../../../core/text_utils.dart';\nimport '../../../../core/typography/browser_system_text.dart';",
)
replace(
    "app/lib/features/home/presentation/widgets/home_drop_card.dart",
    "                          child: Text(\n                            // WYN-087",
    "                          child: BrowserSystemText(\n                            // WYN-087",
)
replace(
    "app/lib/features/home/presentation/widgets/home_drop_card.dart",
    "                                        child: Text(\n                                          item.authorNameOrUsername,",
    "                                        child: BrowserSystemText(\n                                          item.authorNameOrUsername,",
)
replace(
    "app/lib/features/home/presentation/widgets/home_drop_card.dart",
    "                                        child: Text(\n                                          item.location != null",
    "                                        child: BrowserSystemText(\n                                          item.location != null",
)

# Home Pop card: same author/timestamp treatment as Drop.
replace(
    "app/lib/features/home/presentation/widgets/home_pop_card.dart",
    "import '../../../../core/text_utils.dart';",
    "import '../../../../core/text_utils.dart';\nimport '../../../../core/typography/browser_system_text.dart';",
)
replace(
    "app/lib/features/home/presentation/widgets/home_pop_card.dart",
    "                                        child: Text(\n                                          item.authorNameOrUsername,",
    "                                        child: BrowserSystemText(\n                                          item.authorNameOrUsername,",
)
replace(
    "app/lib/features/home/presentation/widgets/home_pop_card.dart",
    "                                        child: Text(\n                                          relativeTimeLabel(",
    "                                        child: BrowserSystemText(\n                                          relativeTimeLabel(",
)

# Shared Home/social chrome.
replace(
    "app/lib/core/widgets/wynos_social_chrome.dart",
    "import '../design/wyn_typography.dart';",
    "import '../design/wyn_typography.dart';\nimport '../typography/browser_system_text.dart';",
)
replace(
    "app/lib/core/widgets/wynos_social_chrome.dart",
    "                  Text(\n                    title,",
    "                  BrowserSystemText(\n                    title,",
)
replace(
    "app/lib/core/widgets/wynos_social_chrome.dart",
    "                  child: Text(\n                    item.label,",
    "                  child: BrowserSystemText(\n                    item.label,",
)
replace(
    "app/lib/core/widgets/wynos_social_chrome.dart",
    "        tabs: [for (final label in labels) Tab(text: label)],",
    """        tabs: [
          for (final label in labels)
            Tab(
              child: BrowserSystemText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],""",
)

# Home wordmark text.
replace(
    "app/lib/features/home/presentation/home_feed_screen.dart",
    "import '../../../core/interaction/wyn_motion.dart';",
    "import '../../../core/interaction/wyn_motion.dart';\nimport '../../../core/typography/browser_system_text.dart';",
)
replace(
    "app/lib/features/home/presentation/home_feed_screen.dart",
    "          Text(\n            'WYNOS',",
    "          BrowserSystemText(\n            'WYNOS',",
)

# Founder bottom navigation labels.
replace(
    "app/lib/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart",
    "import '../../../../core/design/wynos_founder_metrics.dart';",
    "import '../../../../core/design/wynos_founder_metrics.dart';\nimport '../../../../core/typography/browser_system_text.dart';",
)
replace(
    "app/lib/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart",
    "                        const Text(\n                          'โพสต์',",
    "                        const BrowserSystemText(\n                          'โพสต์',",
)
replace(
    "app/lib/features/root/presentation/widgets/wynos_founder_bottom_navigation.dart",
    "              Text(\n                label,",
    "              BrowserSystemText(\n                label,",
)

# Secondary feed metadata can contain Thai names and emoji too.
replace(
    "app/lib/features/home/presentation/widgets/liked_by_row.dart",
    "import '../../../../core/design/wyn_spacing.dart';",
    "import '../../../../core/design/wyn_spacing.dart';\nimport '../../../../core/typography/browser_system_text.dart';",
)
replace(
    "app/lib/features/home/presentation/widgets/liked_by_row.dart",
    """            child: Text.rich(
              TextSpan(
                style: baseStyle,
                children: [
                  const TextSpan(text: 'ถูกใจโดย '),
                  TextSpan(
                    text: shown[0].nameOrUsername,
                    style: baseStyle?.copyWith(
                      color: WynColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (extra > 0) TextSpan(text: ' และอีก $extra คน'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),""",
    """            child: BrowserSystemRichText(
              style: baseStyle,
              spans: [
                const BrowserSystemSpan(text: 'ถูกใจโดย '),
                BrowserSystemSpan(
                  text: shown[0].nameOrUsername,
                  style: baseStyle?.copyWith(
                    color: WynColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (extra > 0) BrowserSystemSpan(text: ' และอีก $extra คน'),
              ],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),""",
)

replace(
    "app/lib/features/home/presentation/widgets/top_reply_preview.dart",
    "import '../../../../core/design/wyn_colors.dart';",
    "import '../../../../core/design/wyn_colors.dart';\nimport '../../../../core/typography/browser_system_text.dart';",
)
replace(
    "app/lib/features/home/presentation/widgets/top_reply_preview.dart",
    """                    child: Text.rich(
                      TextSpan(
                        style: baseStyle,
                        children: [
                          TextSpan(
                            text: reply.authorNameOrUsername,
                            style: baseStyle?.copyWith(
                              color: WynColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(text: ' '),
                          TextSpan(text: reply.text),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),""",
    """                    child: BrowserSystemRichText(
                      style: baseStyle,
                      spans: [
                        BrowserSystemSpan(
                          text: reply.authorNameOrUsername,
                          style: baseStyle?.copyWith(
                            color: WynColors.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const BrowserSystemSpan(text: ' '),
                        BrowserSystemSpan(text: reply.text),
                      ],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),""",
)

# Stop downloading the old external Thai fallback.
replace("app/lib/main.dart", "import 'dart:async';\n\n", "")
replace(
    "app/lib/main.dart",
    "import 'core/typography/looped_thai_font_loader.dart';\n",
    "",
)
replace(
    "app/lib/main.dart",
    """  // Flutter Web uses a canvas renderer and therefore cannot read the Thai
  // system font installed on Safari/iOS. The OFL-licensed looped Thai font is
  // only a visual enhancement, so never make the first frame depend on a
  // cross-origin network request. Native builds use a no-op implementation.
  unawaited(loadLoopedThaiFontForWeb());

""",
    "",
)

replace(
    "app/lib/core/design/wyn_theme.dart",
    """  /// Flutter Web cannot read the visitor's installed Thai system font from
  /// its canvas renderer. This family is registered at web startup from the
  /// OFL-licensed Noto Sans Thai Looped file. Latin text still resolves to
  /// the platform/default Flutter font first; this is only a missing-glyph
  /// fallback for Thai and other glyphs that the primary face lacks.
  static const List<String> fontFamilyFallback = ['WYNThaiLooped'];

""",
    "",
)
replace(
    "app/lib/core/design/wyn_theme.dart",
    "    fontFamilyFallback: fontFamilyFallback,\n",
    "",
    count=2,
)

# Tests: the theme no longer injects the downloaded fallback.
replace(
    "app/test/system_typography_ios_accessibility_test.dart",
    """  test('theme keeps the looped Thai family in the fallback chain', () {
    expect(
      WynTheme.light.textTheme.bodyLarge?.fontFamilyFallback,
      contains('WYNThaiLooped'),
    );
    expect(
      WynTheme.dark.textTheme.labelSmall?.fontFamilyFallback,
      contains('WYNThaiLooped'),
    );
  });""",
    """  test('theme leaves font selection to the running platform', () {
    expect(WynTheme.light.textTheme.bodyLarge?.fontFamily, isNull);
    expect(WynTheme.light.textTheme.bodyLarge?.fontFamilyFallback, isNull);
    expect(WynTheme.dark.textTheme.labelSmall?.fontFamily, isNull);
    expect(WynTheme.dark.textTheme.labelSmall?.fontFamilyFallback, isNull);
  });""",
)

# Dead external font-loader files are removed rather than left as an accidental
# future re-entry point.
for path in [
    "app/lib/core/typography/looped_thai_font_loader.dart",
    "app/lib/core/typography/looped_thai_font_loader_stub.dart",
    "app/lib/core/typography/looped_thai_font_loader_web.dart",
]:
    Path(path).unlink()

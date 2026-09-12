from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected 1 match, found {count}: {old[:100]!r}')
    p.write_text(text.replace(old, new, 1))


def replace_all_checked(path: str, old: str, new: str, expected: int) -> None:
    p = Path(path)
    text = p.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{path}: expected {expected} matches, found {count}: {old[:100]!r}')
    p.write_text(text.replace(old, new))


# Shared Home-card geometry: larger avatar, slightly tighter screen inset/gap.
metrics = 'app/lib/features/home/presentation/widgets/home_card_metrics.dart'
replace_once(metrics, 'const double homeCardEdgeInset = WynSpacing.space6;',
             'const double homeCardEdgeInset = WynSpacing.space5;')
replace_once(metrics, 'const double homeCardAvatarDiameter = 40;',
             'const double homeCardAvatarDiameter = 48;')
replace_once(metrics, 'const double homeCardAvatarGap = 14;',
             'const double homeCardAvatarGap = WynSpacing.space3;')
replace_once(metrics,
             '/// 24 + 40 + 14 = 78 on any width. Every section of a card lines up\n',
             '/// 20 + 48 + 12 = 80 on any width. Every section of a card lines up\n')

# ActionMetric can now hide zeroes on compact Home cards while keeping old callers unchanged.
action_metric = 'app/lib/core/widgets/action_metric.dart'
replace_once(action_metric,
'''    required this.semanticsLabel,
    required this.onTap,
  });''',
'''    required this.semanticsLabel,
    required this.onTap,
    this.hideZeroCount = false,
    this.countTextStyle,
  });''')
replace_once(action_metric,
'''  final String semanticsLabel;

  /// Null for a display-only, non-tappable metric (e.g. view count).
  final VoidCallback? onTap;''',
'''  final String semanticsLabel;

  /// Threads-like Home cards omit a numeric label when the metric is zero.
  /// Defaults to false so Profile/Club/legacy call sites keep their existing UI.
  final bool hideZeroCount;

  /// Optional per-surface typography for the number next to the icon.
  final TextStyle? countTextStyle;

  /// Null for a display-only, non-tappable metric (e.g. view count).
  final VoidCallback? onTap;''')
replace_once(action_metric,
'''    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 6),
        Text(
          '${count ?? 0}',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );''',
'''    final countStyle =
        (widget.countTextStyle ?? Theme.of(context).textTheme.labelSmall)
            ?.copyWith(color: color);
    final showCount = !(widget.hideZeroCount && (count ?? 0) == 0);
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        if (showCount) ...[
          const SizedBox(width: 6),
          Text('${count ?? 0}', style: countStyle),
        ],
      ],
    );''')

# Home Drop card.
drop = 'app/lib/features/home/presentation/widgets/home_drop_card.dart'
replace_once(drop,
'''    this.onHide,
    this.showViewCount = true,
  });''',
'''    this.onHide,
    this.showViewCount = true,
    this.showLikedBy = true,
    this.hideZeroActionCounts = false,
  });''')
replace_once(drop,
'''  final bool showViewCount;

  bool get _isOwnDrop =>''',
'''  final bool showViewCount;

  /// Home hides the extra "ถูกใจโดย ..." row to keep each post as one
  /// compact block. Other surfaces keep the old row by default.
  final bool showLikedBy;

  /// Threads-like Home presentation: zero metrics render as icon-only.
  final bool hideZeroActionCounts;

  bool get _isOwnDrop =>''')
# Share moves back to the visible action row; Save remains in More.
replace_once(drop,
'''          ActionSheetRow(
            icon: Icons.share_outlined,
            label: 'แชร์',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _share();
            },
          ),
''', '')
replace_once(drop,
'''  Widget build(BuildContext context) {
    return Semantics(''',
'''  Widget build(BuildContext context) {
    final captionStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: 17,
          height: 1.35,
          fontWeight: FontWeight.w400,
          color: WynColors.ink,
        );
    final actionCountStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          height: 1.1,
          fontWeight: FontWeight.w400,
        );
    return Semantics(''')
replace_once(drop,
'''                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,''',
'''                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontSize: 17,
                                                height: 1.15,
                                                fontWeight: FontWeight.w700,
                                                color: WynColors.ink,
                                              ),''')
replace_once(drop,
'''                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline,
                                              ),''',
'''                                              ?.copyWith(
                                                fontSize: 15,
                                                height: 1.15,
                                                fontWeight: FontWeight.w400,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline,
                                              ),''')
# Both caption rendering branches use the same larger, tighter body type.
replace_once(drop, 'child: HashtagText(item.caption!),\n                                  )',
                  'child: HashtagText(item.caption!, style: captionStyle),\n                                  )')
replace_once(drop, ': HashtagText(item.caption!),',
                  ': HashtagText(item.caption!, style: captionStyle),')
replace_once(drop, 'if (item.likedBy.isNotEmpty)\n                          Padding(',
                  'if (showLikedBy && item.likedBy.isNotEmpty)\n                          Padding(')
# Larger action icons and tighter metric spacing.
replace_once(drop, '                                    size: 17,',
                  '                                    size: 24,')
replace_once(drop,
'''                                  onTap: onToggleLike,
                                ),
                                const SizedBox(width: WynSpacing.space5),''',
'''                                  onTap: onToggleLike,
                                  hideZeroCount: hideZeroActionCounts,
                                  countTextStyle: actionCountStyle,
                                ),
                                const SizedBox(width: WynSpacing.space4),''')
replace_once(drop,
'''                                    size: 17,
                                    color: WynColors.graphite,''',
'''                                    size: 24,
                                    color: WynColors.graphite,''')
replace_once(drop,
'''                                  semanticsLabel: 'ดูคอมเมนต์',
                                  onTap: onTap,
                                ),''',
'''                                  semanticsLabel: 'ดูคอมเมนต์',
                                  onTap: onTap,
                                  hideZeroCount: hideZeroActionCounts,
                                  countTextStyle: actionCountStyle,
                                ),''')
replace_once(drop, 'const SizedBox(width: WynSpacing.space5),\n                                  ActionMetric(\n                                    icon: Icon(\n                                      Icons.repeat,',
                  'const SizedBox(width: WynSpacing.space4),\n                                  ActionMetric(\n                                    icon: Icon(\n                                      Icons.repeat,')
replace_once(drop, '                                      size: 17,\n                                      color: item.redroppedByMe',
                  '                                      size: 24,\n                                      color: item.redroppedByMe')
replace_once(drop,
'''                                    onTap: () => _openRedropSheet(context),
                                  ),
                                ],''',
'''                                    onTap: () => _openRedropSheet(context),
                                    hideZeroCount: hideZeroActionCounts,
                                    countTextStyle: actionCountStyle,
                                  ),
                                ],
                                const SizedBox(width: WynSpacing.space4),
                                IconButton(
                                  icon: const Icon(Icons.send_outlined, size: 24),
                                  tooltip: 'แชร์',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints.tightFor(
                                    width: WynSpacing.touchTargetMin,
                                    height: WynSpacing.touchTargetMin,
                                  ),
                                  color: WynColors.graphite,
                                  onPressed: _share,
                                ),''')
# View count, when present off Home, follows the new scale and typography.
replace_once(drop, '                                  const SizedBox(width: WynSpacing.space5),\n                                  ActionMetric(\n                                    icon: const Icon(\n                                      Icons.visibility_outlined,\n                                      size: 16,',
                  '                                  const SizedBox(width: WynSpacing.space4),\n                                  ActionMetric(\n                                    icon: const Icon(\n                                      Icons.visibility_outlined,\n                                      size: 22,')
replace_once(drop,
'''                                    onTap: null,
                                  ),''',
'''                                    onTap: null,
                                    hideZeroCount: hideZeroActionCounts,
                                    countTextStyle: actionCountStyle,
                                  ),''')

# Home Pop card gets the same header typography, horizontal More, visible Share,
# action sizing, and Home-only compact switches.
pop = 'app/lib/features/home/presentation/widgets/home_pop_card.dart'
replace_once(pop,
"import '../../../../core/design/wyn_spacing.dart';\n",
"import '../../../../core/design/wyn_spacing.dart';\nimport '../../../../core/text_utils.dart';\n")
replace_once(pop,
'''    this.onHide,
    this.showViewCount = true,
  });''',
'''    this.onHide,
    this.showViewCount = true,
    this.showLikedBy = true,
    this.hideZeroActionCounts = false,
  });''')
replace_once(pop,
'''  final bool showViewCount;

  bool get _isOwnPop =>''',
'''  final bool showViewCount;
  final bool showLikedBy;
  final bool hideZeroActionCounts;

  bool get _isOwnPop =>''')
replace_once(pop,
'''        ActionSheetRow(
          icon: Icons.share_outlined,
          label: 'แชร์',
          onTap: () {
            Navigator.of(sheetContext).pop();
            _share();
          },
        ),
''', '')
replace_once(pop,
'''  Widget build(BuildContext context) {
    return Semantics(''',
'''  Widget build(BuildContext context) {
    final captionStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: 17,
          height: 1.35,
          fontWeight: FontWeight.w400,
          color: WynColors.ink,
        );
    final actionCountStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          height: 1.1,
          fontWeight: FontWeight.w400,
        );
    return Semantics(''')
replace_once(pop,
'padding: const EdgeInsets.symmetric(vertical: WynSpacing.space4),',
'padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),')
replace_once(pop,
'''                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,''',
'''                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                fontSize: 17,
                                                height: 1.15,
                                                fontWeight: FontWeight.w700,
                                                color: WynColors.ink,
                                              ),''')
# Add timestamp beside verified badge in Pop header.
replace_once(pop,
'''                                      if (item.authorIsVerified) ...[
                                        const SizedBox(
                                            width: WynSpacing.space1),
                                        const VerifiedBadge(),
                                      ],
                                    ],''',
'''                                      if (item.authorIsVerified) ...[
                                        const SizedBox(
                                            width: WynSpacing.space1),
                                        const VerifiedBadge(),
                                      ],
                                      const SizedBox(width: WynSpacing.space2),
                                      Flexible(
                                        child: Text(
                                          relativeTimeLabel(
                                            item.createdAt,
                                            now: DateTime.now(),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                fontSize: 15,
                                                height: 1.15,
                                                fontWeight: FontWeight.w400,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .outline,
                                              ),
                                        ),
                                      ),
                                    ],''')
replace_once(pop, 'icon: const Icon(Icons.more_vert),',
                  'icon: const Icon(Icons.more_horiz),')
replace_once(pop,
'''                                constraints: const BoxConstraints.tightFor(
                                  width: WynSpacing.touchTargetMin,
                                  height: WynSpacing.touchTargetMin,
                                ),''',
'''                                constraints: const BoxConstraints.tightFor(
                                  width: WynSpacing.touchTargetMin,
                                  height: homeCardAvatarDiameter,
                                ),''')
replace_once(pop, 'child: HashtagText(item.caption!),',
                  'child: HashtagText(item.caption!, style: captionStyle),')
replace_once(pop, 'if (item.likedBy.isNotEmpty)\n                          Padding(',
                  'if (showLikedBy && item.likedBy.isNotEmpty)\n                          Padding(')
replace_once(pop, '                                  size: 17,',
                  '                                  size: 24,')
replace_once(pop,
'''                                onTap: onToggleLike,
                              ),
                              const SizedBox(width: WynSpacing.space5),''',
'''                                onTap: onToggleLike,
                                hideZeroCount: hideZeroActionCounts,
                                countTextStyle: actionCountStyle,
                              ),
                              const SizedBox(width: WynSpacing.space4),''')
replace_once(pop,
'''                                icon: const Icon(Icons.mode_comment_outlined,
                                    size: 17, color: WynColors.graphite),''',
'''                                icon: const Icon(Icons.mode_comment_outlined,
                                    size: 24, color: WynColors.graphite),''')
replace_once(pop,
'''                                semanticsLabel: 'ดูคอมเมนต์',
                                onTap: onTapComment ?? onTap,
                              ),''',
'''                                semanticsLabel: 'ดูคอมเมนต์',
                                onTap: onTapComment ?? onTap,
                                hideZeroCount: hideZeroActionCounts,
                                countTextStyle: actionCountStyle,
                              ),
                              const SizedBox(width: WynSpacing.space4),
                              IconButton(
                                icon: const Icon(Icons.send_outlined, size: 24),
                                tooltip: 'แชร์',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: WynSpacing.touchTargetMin,
                                  height: WynSpacing.touchTargetMin,
                                ),
                                color: WynColors.graphite,
                                onPressed: _share,
                              ),''')
replace_once(pop, '                                const SizedBox(width: WynSpacing.space5),\n                                ActionMetric(\n                                  icon: const Icon(Icons.visibility_outlined,\n                                      size: 16,',
                  '                                const SizedBox(width: WynSpacing.space4),\n                                ActionMetric(\n                                  icon: const Icon(Icons.visibility_outlined,\n                                      size: 22,')
replace_once(pop,
'''                                  onTap: null,
                                ),''',
'''                                  onTap: null,
                                  hideZeroCount: hideZeroActionCounts,
                                  countTextStyle: actionCountStyle,
                                ),''')

# Home feed opts into the compact-only behavior; Profile/Search/Hashtag keep
# liked-by and zero counts unless they explicitly choose otherwise.
mode = 'app/lib/features/home/presentation/widgets/mode_feed_page.dart'
replace_all_checked(mode,
'''                showViewCount: false,
''',
'''                showViewCount: false,
                showLikedBy: false,
                hideZeroActionCounts: true,
''', 2)

print('Threads-like Home post polish applied')

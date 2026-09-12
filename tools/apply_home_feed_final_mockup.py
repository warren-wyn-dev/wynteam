from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one match, found {count}: {old[:100]!r}')
    path.write_text(text.replace(old, new, 1))


def replace_all_exact(path: Path, old: str, new: str, expected: int) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{path}: expected {expected} matches, found {count}: {old[:100]!r}')
    path.write_text(text.replace(old, new))


metrics = Path('app/lib/features/home/presentation/widgets/home_card_metrics.dart')
replace_once(metrics, 'const double homeCardEdgeInset = WynSpacing.space5;', 'const double homeCardEdgeInset = WynSpacing.space4;')
replace_once(metrics, 'const double homeCardAvatarDiameter = 48;', 'const double homeCardAvatarDiameter = 40;')
replace_once(
    metrics,
    "/// 20 + 48 + 12 = 80 on any width. Every section of a card lines up\n/// here, including the photo row's left edge.",
    "/// 16 + 40 + 12 = 68 on any width. Every section of a card lines up\n/// here, including the photo row's left edge. This matches the approved\n/// compact Home mockup while leaving enough room for a clear avatar.",
)


drop = Path('app/lib/features/home/presentation/widgets/home_drop_card.dart')
replace_once(drop, '      fontSize: 17,\n      height: 1.35,', '      fontSize: 17.5,\n      height: 1.32,')
replace_once(
    drop,
    '''          // Tighten the top rhythm so the author, caption and media
          // sit closer to the divider while keeping 8px below the action row.
          padding: const EdgeInsets.fromLTRB(
            0,
            WynSpacing.space1,
            0,
            WynSpacing.space2,
          ),''',
    '''          // Approved final mockup: each post gets breathing room above
          // the avatar/name, while the content inside the post stays compact.
          padding: const EdgeInsets.fromLTRB(
            0,
            WynSpacing.space3,
            0,
            WynSpacing.space2,
          ),''',
)
replace_once(
    drop,
    '''                              // Compact header: keep the More action
                              // at 40px tall even though the avatar is 48px, so
                              // the author stays top-aligned and caption/media
                              // can start 8px sooner. Width remains 44px for a
                              // forgiving horizontal target.
                              IconButton(
                                icon: const Icon(Icons.more_horiz),
                                tooltip: 'เพิ่มเติม',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: WynSpacing.touchTargetMin,
                                  height: 40,
                                ),
                                onPressed: () => _openMoreMenu(context),
                              ),''',
    '''                              // Final mockup rhythm: the visual dots sit
                              // on the same top line as name/time, and the row is
                              // only 32px tall so the caption follows immediately.
                              IconButton(
                                icon: const Icon(Icons.more_horiz, size: 22),
                                tooltip: 'เพิ่มเติม',
                                padding: const EdgeInsets.only(top: 2),
                                alignment: Alignment.topCenter,
                                constraints: const BoxConstraints.tightFor(
                                  width: WynSpacing.touchTargetMin,
                                  height: 32,
                                ),
                                onPressed: () => _openMoreMenu(context),
                              ),''',
)


pop = Path('app/lib/features/home/presentation/widgets/home_pop_card.dart')
replace_once(pop, '      fontSize: 17,\n      height: 1.35,', '      fontSize: 17.5,\n      height: 1.32,')
replace_once(
    pop,
    '''          padding: const EdgeInsets.fromLTRB(
            0,
            WynSpacing.space1,
            0,
            WynSpacing.space2,
          ),''',
    '''          padding: const EdgeInsets.fromLTRB(
            0,
            WynSpacing.space3,
            0,
            WynSpacing.space2,
          ),''',
)
replace_once(
    pop,
    '''                              IconButton(
                                icon: const Icon(Icons.more_horiz),
                                tooltip: 'เพิ่มเติม',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: WynSpacing.touchTargetMin,
                                  height: 40,
                                ),
                                onPressed: () => _openMoreMenu(context),
                              ),''',
    '''                              IconButton(
                                icon: const Icon(Icons.more_horiz, size: 22),
                                tooltip: 'เพิ่มเติม',
                                padding: const EdgeInsets.only(top: 2),
                                alignment: Alignment.topCenter,
                                constraints: const BoxConstraints.tightFor(
                                  width: WynSpacing.touchTargetMin,
                                  height: 32,
                                ),
                                onPressed: () => _openMoreMenu(context),
                              ),''',
)

# Move Pop caption above media so every Home post follows the same visual
# hierarchy approved in the mockup: name/time -> caption -> media -> actions.
pop_text = pop.read_text()
media_start = pop_text.find('                        Padding(\n                          padding: const EdgeInsets.only(\n                            right: homeCardEdgeInset,\n                          ),\n                          child: DoubleTapLike(')
if media_start == -1:
    raise SystemExit('home_pop_card.dart: media block start not found')
actions_marker = '                        if (showLikedBy && item.likedBy.isNotEmpty)'
actions_start = pop_text.find(actions_marker, media_start)
if actions_start == -1:
    raise SystemExit('home_pop_card.dart: liked-by marker not found')
new_media_caption = '''                        if (item.caption != null && item.caption!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              0,
                              0,
                              homeCardEdgeInset,
                              WynSpacing.space2,
                            ),
                            child: HashtagText(
                              item.caption!,
                              style: captionStyle,
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.only(
                            right: homeCardEdgeInset,
                          ),
                          child: DoubleTapLike(
                            onLike: onToggleLike,
                            alreadyLiked: item.likedByMe,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                WynSpacing.radiusLg,
                              ),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (item.thumbnailUrl != null)
                                      Image.network(
                                        item.thumbnailUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: networkImageErrorBuilder,
                                      )
                                    else
                                      Container(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                      ),
                                    const Center(
                                      child: Icon(
                                        Icons.play_circle_fill,
                                        color: Colors.white,
                                        size: 56,
                                      ),
                                    ),
                                    if (item.durationSeconds != null)
                                      Positioned(
                                        right: 8,
                                        bottom: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: WynColors.imageScrim,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _formatDuration(item.durationSeconds!),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: WynSpacing.space2),
'''
pop.write_text(pop_text[:media_start] + new_media_caption + pop_text[actions_start:])


mode = Path('app/lib/features/home/presentation/widgets/mode_feed_page.dart')
replace_all_exact(mode, 'hideZeroActionCounts: true,', 'hideZeroActionCounts: false,', 2)


font_loader = Path('app/lib/core/typography/looped_thai_font_loader_web.dart')
replace_once(
    font_loader,
    '''// Keep the registered family name stable so existing ThemeData/tests do not
// need a migration, but use the cleaner OFL Noto Sans Thai face. On iPhone
// Safari this is visually closer to modern iOS Thai than the traditional
// looped face while still giving Flutter Web a reliable Thai glyph fallback.
const _family = 'WYNThaiLooped';
const _fontBaseUrl =
    'https://raw.githubusercontent.com/google/fonts/main/ofl/notosansthai/';
const _fontFile = 'NotoSansThai%5Bwdth,wght%5D.ttf';''',
    '''// The approved Home mockup uses traditional headed/looped Thai glyphs.
// Keep the registered family stable, but load Google's OFL-licensed
// Noto Sans Thai Looped variable font rather than the loopless face.
const _family = 'WYNThaiLooped';
const _fontBaseUrl =
    'https://raw.githubusercontent.com/google/fonts/main/ofl/notosansthailooped/';
const _fontFile = 'NotoSansThaiLooped%5Bwdth%2Cwght%5D.ttf';''',
)

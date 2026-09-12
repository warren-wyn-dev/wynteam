from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    return text.replace(old, new, 1)


def patch_drop() -> None:
    path = Path('app/lib/features/home/presentation/widgets/home_drop_card.dart')
    text = path.read_text()

    text = replace_once(
        text,
        """          // Threads-like compact rhythm: keep 8px above the author
          // row, but only 8px after the action row before the divider.
          // The card stays easy to scan without carrying a large blank tail.
          padding: const EdgeInsets.fromLTRB(
            0,
            WynSpacing.space2,
            0,
            WynSpacing.space2,
          ),""",
        """          // Tighten the top rhythm so the author, caption and media
          // sit closer to the divider while keeping 8px below the action row.
          padding: const EdgeInsets.fromLTRB(
            0,
            WynSpacing.space1,
            0,
            WynSpacing.space2,
          ),""",
        'Drop card outer padding',
    )

    text = replace_once(
        text,
        """                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(""",
        """                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: InkWell(""",
        'Drop header top alignment',
    )

    text = replace_once(
        text,
        """                              // Compact header: keep the More action
                              // aligned to the 40px avatar so media/caption
                              // can begin closer to the author row. The button
                              // stays 44px wide for a forgiving horizontal
                              // target while its visual row is 40px tall.
                              IconButton(""",
        """                              // Compact header: keep the More action
                              // at 40px tall even though the avatar is 48px, so
                              // the author stays top-aligned and caption/media
                              // can start 8px sooner. Width remains 44px for a
                              // forgiving horizontal target.
                              IconButton(""",
        'Drop header comment',
    )

    text = replace_once(
        text,
        '                                  height: homeCardAvatarDiameter,',
        '                                  height: 40,',
        'Drop More button height',
    )

    path.write_text(text)


def patch_pop() -> None:
    path = Path('app/lib/features/home/presentation/widgets/home_pop_card.dart')
    text = path.read_text()

    text = replace_once(
        text,
        '          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),',
        """          padding: const EdgeInsets.fromLTRB(
            0,
            WynSpacing.space1,
            0,
            WynSpacing.space2,
          ),""",
        'Pop card outer padding',
    )

    text = replace_once(
        text,
        """                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(""",
        """                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: InkWell(""",
        'Pop header top alignment',
    )

    text = replace_once(
        text,
        '                                  height: homeCardAvatarDiameter,',
        '                                  height: 40,',
        'Pop More button height',
    )

    path.write_text(text)


patch_drop()
patch_pop()
print('Home author/caption/media shifted upward')

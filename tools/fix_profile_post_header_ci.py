from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected 1 match, found {count}')
    return text.replace(old, new, 1)


def switch_more_icon_in_test(text: str, anchor: str, expected: int = 1) -> str:
    start = text.find(anchor)
    if start == -1:
        raise SystemExit(f'test anchor not found: {anchor}')
    next_test = text.find('testWidgets(', start + len(anchor))
    end = next_test if next_test != -1 else len(text)
    block = text[start:end]
    old = 'Icons.more_vert'
    count = block.count(old)
    if count != expected:
        raise SystemExit(
            f'{anchor}: expected {expected} vertical More refs, found {count}'
        )
    block = block.replace(old, 'Icons.more_horiz')
    return text[:start] + block + text[end:]


# Product behavior changed intentionally: HomeDropCard now uses horizontal More.
# Keep Pop and other surfaces unchanged; only touch tests whose target is a Drop card.
test_path = Path('app/test/home_feed_screen_test.dart')
text = test_path.read_text()
for anchor, count in [
    ('renders a mix of Drop and Pop cards with type-specific UI', 1),
    ("the More menu on the viewer\\'s own ReDrop card offers", 1),
    ('tapping "ไม่สนใจโพสต์นี้" on a Drop card calls hideContent', 1),
    ('a failed hideContent call restores the card and stays', 2),
    ('WYN-079: hiding a card offers a Snackbar', 1),
    ('WYN-079: letting the Undo Snackbar time out', 1),
    ('the "..." menu is shown even on the viewer\\'s own plain Drop', 1),
    ('tapping "บันทึก" in the menu calls DropRepository.toggleSave', 1),
]:
    text = switch_more_icon_in_test(text, anchor, count)

# Keep the regression-test description consistent with the new one-line header.
text = text.replace(
    'relative post timestamp under the author name',
    'relative post timestamp beside the author name',
)
test_path.write_text(text.rstrip() + '\n')


card_path = Path('app/lib/features/home/presentation/widgets/home_drop_card.dart')
card = card_path.read_text()
card = replace_once(
    card,
    """          // WYN-107: 16 top and bottom, matching design-reference/
          // 01-home.tsx's own `pt-4 pb-4` per post -- the card is
          // wider-set now, and the old 8 left it looking cramped
          // against the extra horizontal room.
""",
    """          // Compact post header: 8px above the author row and 16px
          // below the card. The reduced top gap, one-line author/time row,
          // and tighter caption spacing pull media/caption upward without
          // changing the card's horizontal alignment.
""",
    'compact header padding comment',
)
card_path.write_text(card.rstrip() + '\n')

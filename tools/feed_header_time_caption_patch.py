from pathlib import Path


def one(path, old, new):
    p = Path(path)
    s = p.read_text()
    if s.count(old) != 1:
        raise SystemExit(f'{path}: pattern count {s.count(old)}')
    p.write_text(s.replace(old, new, 1))


for path in [
    'app/lib/features/home/presentation/widgets/home_drop_card.dart',
    'app/lib/features/home/presentation/widgets/home_pop_card.dart',
]:
    one(
        path,
        "                                      Expanded(\n                                        flex: 3,\n                                        child: Text(\n                                          item.authorNameOrUsername,\n",
        "                                      Flexible(\n                                        child: Text(\n                                          item.authorNameOrUsername,\n",
    )
    one(
        path,
        "                                      Flexible(\n                                        flex: 2,\n                                        child: Text(\n",
        "                                      ConstrainedBox(\n                                        constraints: const BoxConstraints(maxWidth: 112),\n                                        child: Text(\n",
    )

one(
    'app/lib/features/home/presentation/widgets/home_drop_card.dart',
    "                            child: !item.isPoll && item.imageUrl == null\n",
    "                            child: Transform.translate(\n                              offset: const Offset(0, -3),\n                              child: !item.isPoll && item.imageUrl == null\n",
)
one(
    'app/lib/features/home/presentation/widgets/home_drop_card.dart',
    "                                    style: captionStyle,\n                                  ),\n                          ),\n                        if (item.isPoll)\n",
    "                                    style: captionStyle,\n                                  ),\n                            ),\n                          ),\n                        if (item.isPoll)\n",
)
one(
    'app/lib/features/home/presentation/widgets/home_pop_card.dart',
    "                            child: HashtagText(\n                              item.caption!,\n                              style: captionStyle,\n                            ),\n",
    "                            child: Transform.translate(\n                              offset: const Offset(0, -3),\n                              child: HashtagText(\n                                item.caption!,\n                                style: captionStyle,\n                              ),\n                            ),\n",
)

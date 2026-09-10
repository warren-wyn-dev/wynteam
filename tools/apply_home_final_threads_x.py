from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def sub_once(text: str, pattern: str, replacement: str, label: str) -> str:
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, got {count}")
    return updated


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)


def patch_home_shell() -> None:
    path = ROOT / "app/lib/features/home/presentation/home_feed_screen.dart"
    text = path.read_text()

    new_header = r'''  Widget _buildHeader() {
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
        child: Row(
          children: [
            SizedBox(
              width: WynSpacing.touchTargetMin,
              height: WynSpacing.touchTargetMin,
              child: IconButton(
                icon: const Icon(Icons.menu_rounded,
                    size: 24, color: WynColors.ink),
                tooltip: 'เมนู',
                padding: EdgeInsets.zero,
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
            ),
            Expanded(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/wynos_logo_mark.png',
                      height: 25,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WYNOS',
                          style: WynTypography.screenTitle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.9,
                          ).copyWith(height: 0.98),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'YOUR WORLD. YOUR WAY.',
                          style: TextStyle(
                            color: WynColors.graphite,
                            fontSize: 5.5,
                            height: 1,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            _buildChatAction(),
          ],
        ),
      ),
    );
  }
'''
    text = sub_once(
        text,
        r"  Widget _buildHeader\(\) \{.*?\n  \}\n\n  // Badge shape mirrors",
        new_header + "\n  // Badge shape mirrors",
        "Home header",
    )

    new_chat = r'''  Widget _buildChatAction() {
    const icon = Icon(
      Icons.chat_bubble_outline,
      size: 26,
      color: WynColors.ink,
    );
    final count = _unreadChatCount;
    final badge = count <= 0
        ? icon
        : Stack(
            clipBehavior: Clip.none,
            children: [
              icon,
              Positioned(
                right: -2,
                top: -3,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: WynColors.paper, width: 1.5),
                  ),
                ),
              ),
            ],
          );

    return SizedBox(
      width: WynSpacing.touchTargetMin,
      height: WynSpacing.touchTargetMin,
      child: IconButton(
        icon: badge,
        tooltip: count > 0 ? 'ข้อความ, $count บทสนทนายังไม่อ่าน' : 'ข้อความ',
        padding: EdgeInsets.zero,
        onPressed: _openChatInbox,
      ),
    );
  }
'''
    text = sub_once(
        text,
        r"  Widget _buildChatAction\(\) \{.*?\n  \}\n\n  // WYN-073",
        new_chat + "\n  // WYN-073",
        "Home chat action",
    )

    marker = "  Widget _buildFeedModeToggle() {"
    index = text.find(marker)
    if index < 0:
        raise RuntimeError("Home feed tabs: start marker not found")
    tail = text[index:]
    if "Widget _buildFeedModeTab" not in tail:
        raise RuntimeError("Home feed tabs: tab method not found")

    new_tabs = r'''  Widget _buildFeedModeToggle() {
    const labels = {
      _HomeFeedMode.forYou: 'สำหรับคุณ',
      _HomeFeedMode.following: 'ติดตาม',
      _HomeFeedMode.fromYourClubs: 'Club',
    };

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WynColors.paper,
        border: Border(
          bottom: BorderSide(color: WynColors.hairline),
        ),
      ),
      child: SizedBox(
        height: 49,
        child: Row(
          children: [
            for (final mode in _feedModeOrder)
              Expanded(child: _buildFeedModeTab(mode, labels[mode]!)),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedModeTab(_HomeFeedMode mode, String label) {
    final selected = mode == _feedMode;

    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: InkWell(
        onTap: () => _selectFeedMode(mode),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? WynColors.ink : WynColors.graphite,
                    fontSize: 15,
                    height: 1,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: AnimatedContainer(
                key: selected ? const Key('active_segment_accent') : null,
                duration: WynMotion.duration(context, WynMotion.standard),
                curve: WynMotion.enter,
                height: 2.5,
                decoration: BoxDecoration(
                  color: selected ? WynColors.ink : Colors.transparent,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(WynSpacing.radiusFull),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
'''
    text = text[:index] + new_tabs + "}\n"
    path.write_text(text)


def patch_drop_card() -> None:
    path = ROOT / "app/lib/features/home/presentation/widgets/home_drop_card.dart"
    text = path.read_text()

    text = replace_once(
        text,
        "  final bool showViewCount;\n\n  bool get _isOwnDrop =>",
        "  final bool showViewCount;\n\n  // Home passes showViewCount:false. Reuse that existing surface flag to\n  // opt the Home timeline into the Founder-approved Threads + X visual\n  // treatment without changing Profile/Search/Hashtag call sites that share\n  // this card and intentionally keep their current appearance.\n  bool get _isHomeFeedSurface => !showViewCount;\n\n  bool get _isOwnDrop =>",
        "Drop Home surface flag",
    )

    text = replace_once(
        text,
        "  Future<void> _share() async {",
        r'''  Widget _captionText(String text) {
    return HashtagText(
      text,
      style: _isHomeFeedSurface
          ? const TextStyle(
              color: WynColors.ink,
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w400,
            )
          : null,
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final actionIconSize = _isHomeFeedSurface ? 20.0 : 17.0;
    final metrics = <Widget>[
      ActionMetric(
        icon: WynHeartIcon(
          filled: item.likedByMe,
          size: actionIconSize,
          color: item.likedByMe
              ? WynColors.iconLikeActive
              : WynColors.iconIdle,
        ),
        iconState: item.likedByMe,
        count: item.likeCount,
        color: item.likedByMe
            ? WynColors.iconLikeActive
            : WynColors.iconIdle,
        semanticsLabel: item.likedByMe
            ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ'
            : 'กดเพื่อถูกใจ',
        onTap: onToggleLike,
      ),
      const SizedBox(width: WynSpacing.space5),
      ActionMetric(
        icon: Icon(
          Icons.mode_comment_outlined,
          size: actionIconSize,
          color: WynColors.graphite,
        ),
        iconState: Icons.mode_comment_outlined,
        count: item.commentCount,
        color: WynColors.graphite,
        semanticsLabel: 'ดูคอมเมนต์',
        onTap: onTap,
      ),
      if (item.audience == AudienceOption.everyone) ...[
        const SizedBox(width: WynSpacing.space5),
        ActionMetric(
          icon: Icon(
            Icons.repeat,
            size: actionIconSize,
            color: item.redroppedByMe
                ? WynColors.iconActive
                : WynColors.iconIdle,
          ),
          iconState: item.redroppedByMe,
          count: item.redropCount,
          color: item.redroppedByMe ? WynColors.sapphire : WynColors.graphite,
          semanticsLabel: item.redroppedByMe
              ? 'รีโพสต์แล้ว กดเพื่อเลือกดำเนินการ'
              : 'กดเพื่อรีโพสต์',
          onTap: () => _openRedropSheet(context),
        ),
      ],
      if (showViewCount) ...[
        const SizedBox(width: WynSpacing.space5),
        ActionMetric(
          icon: const Icon(
            Icons.visibility_outlined,
            size: 16,
            color: WynColors.faint,
          ),
          iconState: Icons.visibility_outlined,
          count: item.viewCount,
          color: WynColors.faint,
          semanticsLabel: 'เข้าชมแล้ว ${item.viewCount} ครั้ง',
          onTap: null,
        ),
      ],
    ];

    final metricsRow = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: metrics),
    );

    if (!_isHomeFeedSurface) {
      return Padding(
        padding: const EdgeInsets.only(right: homeCardEdgeInset),
        child: metricsRow,
      );
    }

    // The approved Home mockup keeps Like / Comment / Repost on the left and
    // exposes Save as a first-class action at the far right. This only affects
    // Home; the overflow menu still contains Save too for feature parity.
    return Padding(
      padding: EdgeInsets.only(
        right: homeCardEdgeInset,
        top: item.likedBy.isNotEmpty ? 6 : 0,
      ),
      child: SizedBox(
        height: WynSpacing.touchTargetMin,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: metricsRow,
              ),
            ),
            const SizedBox(width: WynSpacing.space1),
            SizedBox(
              width: WynSpacing.touchTargetMin,
              height: WynSpacing.touchTargetMin,
              child: IconButton(
                tooltip: item.savedByMe ? 'เอาออกจากบันทึก' : 'บันทึก',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: WynSpacing.touchTargetMin,
                  height: WynSpacing.touchTargetMin,
                ),
                icon: Icon(
                  item.savedByMe
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 22,
                  color: WynColors.ink,
                ),
                onPressed: onToggleSave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share() async {''',
        "Drop helpers",
    )

    text = replace_once(
        text,
        "          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space4),",
        "          padding: EdgeInsets.symmetric(\n            vertical: _isHomeFeedSurface ? 12 : WynSpacing.space4,\n          ),",
        "Drop vertical rhythm",
    )

    text = replace_once(
        text,
        "                                              style: Theme.of(context)\n                                                  .textTheme\n                                                  .titleSmall,",
        "                                              style: _isHomeFeedSurface\n                                                  ? const TextStyle(\n                                                      color: WynColors.ink,\n                                                      fontSize: 15.5,\n                                                      height: 1.15,\n                                                      fontWeight: FontWeight.w700,\n                                                    )\n                                                  : Theme.of(context)\n                                                      .textTheme\n                                                      .titleSmall,",
        "Drop author typography",
    )

    if text.count("HashtagText(item.caption!)") != 2:
        raise RuntimeError(
            f"Drop caption renderer: expected 2 matches, got {text.count('HashtagText(item.caption!)')}"
        )
    text = text.replace("HashtagText(item.caption!)", "_captionText(item.caption!)")

    text = replace_once(
        text,
        "                                icon: const Icon(Icons.more_vert),",
        "                                icon: Icon(\n                                  Icons.more_vert,\n                                  size: _isHomeFeedSurface ? 22 : 24,\n                                  color: _isHomeFeedSurface\n                                      ? WynColors.graphite\n                                      : null,\n                                ),",
        "Drop more icon",
    )

    text = sub_once(
        text,
        r"\n                        Padding\(\n                          // WYN-096 aligned this row.*?\n                        \),\n                        if \(item\.topReply != null\)",
        "\n                        _buildActionBar(context),\n                        if (item.topReply != null)",
        "Drop action bar",
    )

    path.write_text(text)


def patch_pop_card() -> None:
    path = ROOT / "app/lib/features/home/presentation/widgets/home_pop_card.dart"
    text = path.read_text()

    text = replace_once(
        text,
        "  final bool showViewCount;\n\n  bool get _isOwnPop =>",
        "  final bool showViewCount;\n\n  bool get _isHomeFeedSurface => !showViewCount;\n\n  bool get _isOwnPop =>",
        "Pop Home surface flag",
    )

    text = replace_once(
        text,
        "  Future<void> _share() async {",
        r'''  Widget _buildActionBar() {
    final actionIconSize = _isHomeFeedSurface ? 20.0 : 17.0;
    final metrics = <Widget>[
      ActionMetric(
        icon: WynHeartIcon(
          filled: item.likedByMe,
          size: actionIconSize,
          color: item.likedByMe
              ? WynColors.iconLikeActive
              : WynColors.iconIdle,
        ),
        iconState: item.likedByMe,
        count: item.likeCount,
        color: item.likedByMe
            ? WynColors.iconLikeActive
            : WynColors.iconIdle,
        semanticsLabel: item.likedByMe
            ? 'ถูกใจแล้ว กดเพื่อเลิกถูกใจ'
            : 'กดเพื่อถูกใจ',
        onTap: onToggleLike,
      ),
      const SizedBox(width: WynSpacing.space5),
      ActionMetric(
        icon: Icon(
          Icons.mode_comment_outlined,
          size: actionIconSize,
          color: WynColors.graphite,
        ),
        iconState: Icons.mode_comment_outlined,
        count: item.commentCount,
        color: WynColors.graphite,
        semanticsLabel: 'ดูคอมเมนต์',
        onTap: onTapComment ?? onTap,
      ),
      if (showViewCount) ...[
        const SizedBox(width: WynSpacing.space5),
        ActionMetric(
          icon: const Icon(
            Icons.visibility_outlined,
            size: 16,
            color: WynColors.faint,
          ),
          iconState: Icons.visibility_outlined,
          count: item.viewCount,
          color: WynColors.faint,
          semanticsLabel: 'เข้าชมแล้ว ${item.viewCount} ครั้ง',
          onTap: null,
        ),
      ],
    ];

    final metricsRow = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(mainAxisSize: MainAxisSize.min, children: metrics),
    );

    if (!_isHomeFeedSurface) {
      return Padding(
        padding: const EdgeInsets.only(right: homeCardEdgeInset),
        child: metricsRow,
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        right: homeCardEdgeInset,
        top: item.likedBy.isNotEmpty ? 6 : 0,
      ),
      child: SizedBox(
        height: WynSpacing.touchTargetMin,
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: metricsRow,
              ),
            ),
            const SizedBox(width: WynSpacing.space1),
            SizedBox(
              width: WynSpacing.touchTargetMin,
              height: WynSpacing.touchTargetMin,
              child: IconButton(
                tooltip: item.savedByMe ? 'เอาออกจากบันทึก' : 'บันทึก',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: WynSpacing.touchTargetMin,
                  height: WynSpacing.touchTargetMin,
                ),
                icon: Icon(
                  item.savedByMe
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  size: 22,
                  color: WynColors.ink,
                ),
                onPressed: onToggleSave,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _share() async {''',
        "Pop action helper",
    )

    text = replace_once(
        text,
        "          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space4),",
        "          padding: EdgeInsets.symmetric(\n            vertical: _isHomeFeedSurface ? 12 : WynSpacing.space4,\n          ),",
        "Pop vertical rhythm",
    )

    text = replace_once(
        text,
        "                                icon: const Icon(Icons.more_vert),",
        "                                icon: Icon(\n                                  Icons.more_vert,\n                                  size: _isHomeFeedSurface ? 22 : 24,\n                                  color: _isHomeFeedSurface\n                                      ? WynColors.graphite\n                                      : null,\n                                ),",
        "Pop more icon",
    )

    text = sub_once(
        text,
        r"\n                        Padding\(\n                          // WYN-096 aligned this row.*?\n                        \),\n                        if \(item\.topReply != null\)",
        "\n                        _buildActionBar(),\n                        if (item.topReply != null)",
        "Pop action bar",
    )

    path.write_text(text)


if __name__ == "__main__":
    patch_home_shell()
    patch_drop_card()
    patch_pop_card()
    print("Applied approved WYNOS Home Threads + X visual pass.")

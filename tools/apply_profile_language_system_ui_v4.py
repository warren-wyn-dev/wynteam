from pathlib import Path

exec(
    compile(
        Path('tools/apply_profile_language_system_ui_v3.py').read_text(),
        'tools/apply_profile_language_system_ui_v3.py',
        'exec',
    ),
    {'__name__': '__main__'},
)

path = Path('app/lib/features/home/presentation/home_feed_screen.dart')
text = path.read_text()
start = text.index('  Widget _buildFeedModeToggle() {')
end = text.index('\n}', text.index('  Widget _buildFeedModeTab(', start))
# `end` above is the State class closing brace because _buildFeedModeTab is
# its last method after the first-pass rewrite. Replace both methods and keep
# that class brace intact.
replacement = r'''  Widget _buildFeedModeToggle() {
    const labels = {
      _HomeFeedMode.forYou: 'สำหรับคุณ',
      _HomeFeedMode.following: 'ติดตาม',
      _HomeFeedMode.fromYourClubs: 'Club',
    };

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: WynColors.paper,
        border: Border(bottom: BorderSide(color: WynColors.hairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in _feedModeOrder)
              Padding(
                padding: const EdgeInsets.only(right: WynSpacing.space6),
                child: _buildFeedModeTab(mode, labels[mode]!),
              ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? WynColors.ink : WynColors.graphite,
                  ),
                ),
                const SizedBox(height: WynSpacing.space1),
                AnimatedOpacity(
                  duration: WynMotion.duration(context, WynMotion.standard),
                  curve: WynMotion.enter,
                  opacity: selected ? 1 : 0,
                  child: Container(
                    key: selected ? const Key('active_segment_accent') : null,
                    height: 2,
                    decoration: const BoxDecoration(
                      color: WynColors.ink,
                      borderRadius: BorderRadius.all(
                        Radius.circular(WynSpacing.radiusFull),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
'''
path.write_text(text[:start] + replacement + text[end:])

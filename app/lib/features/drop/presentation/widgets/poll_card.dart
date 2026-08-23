import 'package:flutter/material.dart';

import '../../../../core/design/wyn_spacing.dart';

/// Poll display + voting widget (WYN-035, Design Screen 2) -- shared
/// verbatim between HomeDropCard and DropDetailScreen, replacing the
/// square image area for a Poll Drop. Deliberately dumb/stateless:
/// [myVoteIndex]/[totalVotes]/[optionCounts] all come from the parent
/// (which owns the optimistic-update-then-revert-on-error dance, same
/// as Like/Save/ReDrop), this widget just renders whatever it's given
/// and reports taps via [onVote].
class PollCard extends StatelessWidget {
  const PollCard({
    super.key,
    required this.options,
    required this.expiresAt,
    required this.myVoteIndex,
    required this.totalVotes,
    required this.optionCounts,
    required this.isOwnPoll,
    required this.onVote,
  });

  final List<String> options;
  final DateTime expiresAt;

  /// Index into [options] the viewer voted for, or null.
  final int? myVoteIndex;

  /// Null means results aren't visible yet (viewer hasn't voted,
  /// isn't the author, and the poll is still open) -- see
  /// `get_poll_results()` in supabase/schema.sql.
  final int? totalVotes;
  final List<int>? optionCounts;
  final bool isOwnPoll;
  final ValueChanged<int> onVote;

  bool get _isClosed => !DateTime.now().toUtc().isBefore(expiresAt);

  bool get _resultsVisible => totalVotes != null;

  bool get _canVote => !isOwnPoll && !_isClosed;

  String get _statusLabel {
    final votes = totalVotes;
    final voteCountLabel = votes == null
        ? null
        : (votes == 0 ? 'ยังไม่มีใครโหวต' : '$votes โหวต');
    final timeLabel = _isClosed ? 'โพลปิดแล้ว' : _remainingLabel();
    if (voteCountLabel == null) return timeLabel;
    return '$voteCountLabel · $timeLabel';
  }

  String _remainingLabel() {
    final remaining = expiresAt.difference(DateTime.now().toUtc());
    if (remaining.inDays >= 1) return 'เหลืออีก ${remaining.inDays} วัน';
    if (remaining.inHours >= 1) return 'เหลืออีก ${remaining.inHours} ชม.';
    return 'เหลืออีก ${remaining.inMinutes.clamp(1, 59)} นาที';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WynSpacing.space3,
        vertical: WynSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            _PollOption(
              text: options[i],
              percent: _resultsVisible && totalVotes! > 0
                  ? (optionCounts![i] / totalVotes!) * 100
                  : (_resultsVisible ? 0 : null),
              isMine: myVoteIndex == i,
              enabled: _canVote,
              onTap: () => onVote(i),
            ),
            if (i != options.length - 1)
              const SizedBox(height: WynSpacing.space2),
          ],
          const SizedBox(height: WynSpacing.space2),
          Text(
            _statusLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({
    required this.text,
    required this.percent,
    required this.isMine,
    required this.enabled,
    required this.onTap,
  });

  final String text;

  /// Null = results not visible yet (plain option row, no fill/percent).
  final double? percent;
  final bool isMine;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percentValue = percent;
    final percentLabel = percentValue == null ? '' : ', ${percentValue.round()}%';

    return Semantics(
      label: isMine
          ? 'ตัวเลือก $text$percentLabel, เลือกอยู่'
          : 'ตัวเลือก $text$percentLabel',
      button: enabled,
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
        child: Container(
          height: WynSpacing.touchTargetMin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
            border: Border.all(
              color: isMine ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              if (percent != null)
                FractionallySizedBox(
                  widthFactor: (percent! / 100).clamp(0, 1),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isMine
                          ? scheme.primary.withValues(alpha: 0.35)
                          : scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3),
                child: Row(
                  children: [
                    if (isMine) ...[
                      Icon(Icons.check_circle, size: 16, color: scheme.primary),
                      const SizedBox(width: WynSpacing.space1),
                    ],
                    Expanded(
                      child: Text(text, overflow: TextOverflow.ellipsis),
                    ),
                    if (percent != null)
                      Text(
                        '${percent!.round()}%',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

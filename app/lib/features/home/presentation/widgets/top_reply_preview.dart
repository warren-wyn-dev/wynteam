import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../data/home_top_reply.dart';

/// A one-off color from WYNOSHomeSpec.md 4.10 itself ("deliberately not
/// full graphite and not full ink") -- quieter than the post author's
/// name but still legible body text. Appears only in this one spot in
/// the reference tsx, unlike WynColors.mutedNeutral (promoted to the
/// shared design system because it recurs across multiple reference
/// screens) -- kept local rather than promoted for that reason.
const Color _replyTextColor = Color(0xFF5A5850);

/// "{replier} {comment text}" preview under a Home feed card's action
/// bar -- WYNOSHomeSpec.md 4.10. A short vertical connector (in a 24px
/// gutter) visually links down from the avatar column above; tapping
/// this navigates to the full comment thread, it is never an inline
/// reply composer.
class TopReplyPreview extends StatelessWidget {
  const TopReplyPreview({super.key, required this.reply, required this.onTap});

  final HomeTopReply reply;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${reply.authorNameOrUsername} ตอบว่า ${reply.text} '
          'กดเพื่อดูคอมเมนต์ทั้งหมด',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const VerticalDivider(
                  width: 24,
                  thickness: 1,
                  color: WynColors.hairline,
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        style: const TextStyle(fontSize: 12.5, color: _replyTextColor),
                        children: [
                          TextSpan(
                            text: reply.authorNameOrUsername,
                            style: const TextStyle(
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
}

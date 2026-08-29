import 'package:flutter/material.dart';

import '../../data/home_feed_item.dart';
import '../design/wynos_home_tokens.dart';

/// WYNOS Home reference spec 4.10 -- the top reply preview: a short
/// vertical connector line in a 24px gutter, then the replier's name
/// (bold) followed inline by their comment text. A preview only --
/// tapping it navigates to the full comment thread ([onTap]), it is
/// never an inline reply composer.
///
/// Renders nothing when [reply] is null (no top-level comment worth
/// surfacing) -- never an empty comment prompt.
///
/// The gutter is this widget's own, not fused with HomeDropCard's
/// avatar column (which still uses its pre-WYNOS layout) -- the
/// visual link to "directly under the avatar" from the reference is
/// therefore only approximate here, not pixel-fused with an
/// unconverted sibling.
class WynosTopReply extends StatelessWidget {
  const WynosTopReply({super.key, required this.reply, this.onTap});

  final HomeTopReply? reply;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reply = this.reply;
    if (reply == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12), // mt-3
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 24, // w-6 gutter
                child: Center(
                  child: Container(width: 1, color: WynosHomeColors.hairline),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: reply.authorNameOrUsername,
                        style: WynosHomeText.replyPreviewName,
                      ),
                      TextSpan(
                        text: '  ${reply.text}',
                        style: WynosHomeText.replyPreviewText,
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

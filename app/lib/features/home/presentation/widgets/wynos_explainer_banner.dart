import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../design/wynos_home_tokens.dart';

/// WYNOS Home reference spec 4.2 -- the first-time explainer banner.
/// Purely presentational: HomeFeedScreen owns whether it's currently
/// dismissed (see home_explainer_banner_preference.dart) and simply
/// stops mounting this widget once it is -- there's no internal
/// "dismissed" state here to keep in sync with that persisted value.
class WynosExplainerBanner extends StatelessWidget {
  const WynosExplainerBanner({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // px-6 pt-3 pb-1 (spec 4.2's own page padding, distinct from the
      // 24px used elsewhere -- pt-3/pb-1 gives it less vertical breathing
      // room than a full post row since it sits directly under the
      // header).
      padding: const EdgeInsets.fromLTRB(
        WynosHomeSpacing.pagePadding,
        12,
        WynosHomeSpacing.pagePadding,
        4,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: WynosHomeColors.ink,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ดู → แชร์ → ค้นพบ → ซื้อ',
                      style: WynosHomeText.bannerHeadline,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'WYNOS คือพื้นที่โซเชียลที่ต่อยอดจากสิ่งที่คุณชอบเห็น',
                      style: WynosHomeText.bannerBody,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // mt-0.5 in the reference -- aligns the X with the first
              // line's cap-height rather than the row's own top edge.
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Semantics(
                  label: 'ปิดคำแนะนำนี้ถาวร',
                  button: true,
                  child: GestureDetector(
                    onTap: onDismiss,
                    child: const Icon(
                      LucideIcons.x,
                      size: 15,
                      color: WynosHomeColors.graphite,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

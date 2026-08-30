import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';

/// The small sapphire-filled checkmark next to an author's name --
/// WYNOSHomeSpec.md 4.9/4.6. Scoped to exactly one account (the
/// official WYNOS account, per [HomeFeedItem.authorIsVerified]'s own
/// doc comment) -- callers gate rendering this on that flag, this
/// widget itself has no opinion on who earns it.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'บัญชียืนยันตัวตนแล้ว',
      excludeSemantics: true,
      child: Icon(Icons.verified, size: size, color: WynColors.sapphire),
    );
  }
}

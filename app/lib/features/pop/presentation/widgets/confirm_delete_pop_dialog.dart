import 'package:flutter/material.dart';

import '../../../../core/widgets/confirm_delete_dialog.dart';

/// Thin wrapper around the shared confirm-delete dialog (WYN-004) so Pop
/// screens get Pop-specific wording ("ลบ Popนี้?") without duplicating the
/// dialog itself. Leading/trailing spaces around "Pop" are intentional --
/// unlike a Thai word, an English loanword inline needs spacing to read
/// naturally (see confirm_delete_drop_dialog.dart, WYN-005, same reason).
Future<bool> confirmDeletePop(BuildContext context) =>
    confirmDeletePost(context, itemLabel: ' Pop ');

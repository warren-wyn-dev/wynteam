import 'package:flutter/material.dart';

import '../../../feed/presentation/widgets/confirm_delete_dialog.dart';

/// Thin wrapper around the shared confirm-delete dialog (WYN-004) so
/// DropDetailScreen gets the Drop-specific wording ("ลบ Drop นี้?")
/// without duplicating the dialog itself. Leading/trailing spaces around
/// "Drop" are intentional -- unlike a Thai word, an English loanword
/// inline needs spacing to read naturally.
Future<bool> confirmDeleteDrop(BuildContext context) =>
    confirmDeletePost(context, itemLabel: ' Drop ');

import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

import '../../data/club_channel.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/widgets/action_sheet_row.dart';

/// WYN-127/128/133 -- every dialog/action-sheet shared by the Club Chat
/// channel list and channel room screens (`club_chat_tab.dart`,
/// `club_channel_screen.dart`): create/edit a channel or a category,
/// delete either, move a channel between categories, and the "+" menu
/// that offers "ห้องใหม่"/"กลุ่มใหม่". No widget in this file renders a
/// channel/category *row* itself anymore -- that moved into the grouped
/// `ListTile`-based list per .wyn/docs/design/
/// wyn-133-club-chat-channel-navigation.md (ds-005 entity-browse list,
/// replacing this file's old horizontal chip switcher).

/// The "+" row-header action on the Channel List (Owner/Admin only) --
/// Design's User Flow: "เปิดเมนู 'ห้องใหม่ / กลุ่มใหม่'".
enum ClubChatAddAction { channel, category }

Future<ClubChatAddAction?> showClubChatAddMenu(BuildContext context) {
  return showModalBottomSheet<ClubChatAddAction>(
    context: context,
    builder: (sheetContext) => ActionSheetBody(rows: [
      ActionSheetRow(
        icon: Icons.tag,
        label: 'ห้องใหม่',
        onTap: () => Navigator.of(sheetContext).pop(ClubChatAddAction.channel),
      ),
      ActionSheetRow(
        icon: Icons.folder_outlined,
        label: 'กลุ่มใหม่',
        onTap: () => Navigator.of(sheetContext).pop(ClubChatAddAction.category),
      ),
    ]),
  );
}

/// Long-press on a channel row (Owner/Admin only) -- adds "ย้ายไปกลุ่มอื่น"
/// alongside the original edit/delete rows now that there's no chip
/// left to long-press for the same actions.
enum ClubChannelManageAction { edit, delete, move }

Future<ClubChannelManageAction?> showClubChannelManageSheet(
    BuildContext context) {
  return showModalBottomSheet<ClubChannelManageAction>(
    context: context,
    builder: (sheetContext) => ActionSheetBody(rows: [
      ActionSheetRow(
        icon: Icons.edit_outlined,
        label: 'แก้ไขชื่อห้อง',
        onTap: () =>
            Navigator.of(sheetContext).pop(ClubChannelManageAction.edit),
      ),
      ActionSheetRow(
        icon: Icons.drive_file_move_outline,
        label: 'ย้ายไปกลุ่มอื่น',
        onTap: () =>
            Navigator.of(sheetContext).pop(ClubChannelManageAction.move),
      ),
      ActionSheetRow(
        icon: Icons.delete_outline,
        label: 'ลบห้อง',
        onTap: () =>
            Navigator.of(sheetContext).pop(ClubChannelManageAction.delete),
      ),
    ]),
  );
}

/// Long-press on a category header (Owner/Admin only) -- WYN-133
/// (requirement 7).
enum ClubCategoryManageAction { edit, delete }

Future<ClubCategoryManageAction?> showClubCategoryManageSheet(
    BuildContext context) {
  return showModalBottomSheet<ClubCategoryManageAction>(
    context: context,
    builder: (sheetContext) => ActionSheetBody(rows: [
      ActionSheetRow(
        icon: Icons.edit_outlined,
        label: 'แก้ไขชื่อกลุ่ม',
        onTap: () =>
            Navigator.of(sheetContext).pop(ClubCategoryManageAction.edit),
      ),
      ActionSheetRow(
        icon: Icons.delete_outline,
        label: 'ลบกลุ่ม',
        onTap: () =>
            Navigator.of(sheetContext).pop(ClubCategoryManageAction.delete),
      ),
    ]),
  );
}

List<DropdownMenuItem<String?>> _categoryDropdownItems(
        List<ClubChannelCategory> categories) =>
    [
      const DropdownMenuItem<String?>(
          value: null, child: BrowserSystemText('ไม่มีกลุ่ม')),
      for (final category in categories)
        DropdownMenuItem<String?>(
            value: category.id, child: BrowserSystemText(category.name)),
    ];

/// Create/edit channel dialog -- Design's Components: "ช่องกรอกชื่อ
/// (จำกัดความยาว, กันชื่อว่าง/ซ้ำ), ปุ่มยืนยัน/ยกเลิกมาตรฐาน" plus (WYN-133,
/// requirement 7) a category picker below it, defaulting to "ไม่มีกลุ่ม".
/// [isNameTaken] is a client-side, case-insensitive dupe check against
/// the already-loaded channel list (the real, authoritative check is the
/// DB's own `club_channels_club_id_lower_name_key` unique index -- this
/// is just immediate feedback, not the security boundary). Returns the
/// trimmed name + chosen category id, or null if cancelled.
Future<({String name, String? categoryId})?> showClubChannelNameDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
  String? initialCategoryId,
  required List<ClubChannelCategory> categories,
  required bool Function(String name) isNameTaken,
}) {
  return showDialog<({String name, String? categoryId})>(
    context: context,
    builder: (dialogContext) => _ClubChannelNameDialog(
      title: title,
      initialName: initialName,
      initialCategoryId: initialCategoryId,
      categories: categories,
      isNameTaken: isNameTaken,
    ),
  );
}

/// A dedicated `StatefulWidget` (not a bare `TextEditingController` owned
/// by the function above + `StatefulBuilder`) so the controller's
/// lifecycle is tied to this element's own -- Flutter disposes it
/// automatically once this widget leaves the tree, *after* the dialog's
/// exit transition finishes rather than the instant `showDialog`'s
/// Future resolves. Disposing it manually right after `await
/// showDialog(...)` (the first version of this function) raced that
/// transition and threw "A TextEditingController was used after being
/// disposed" -- reproduced by
/// club_posts_tab_test.dart's "creating a channel selects it" case.
class _ClubChannelNameDialog extends StatefulWidget {
  const _ClubChannelNameDialog({
    required this.title,
    required this.initialName,
    required this.initialCategoryId,
    required this.categories,
    required this.isNameTaken,
  });

  final String title;
  final String initialName;
  final String? initialCategoryId;
  final List<ClubChannelCategory> categories;
  final bool Function(String name) isNameTaken;

  @override
  State<_ClubChannelNameDialog> createState() => _ClubChannelNameDialogState();
}

class _ClubChannelNameDialogState extends State<_ClubChannelNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);
  late String? _categoryId = widget.initialCategoryId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _controller.text.trim();
    final isEmpty = trimmed.isEmpty;
    final isDuplicate = !isEmpty && widget.isNameTaken(trimmed);
    final isValid = !isEmpty && trimmed.length <= 50 && !isDuplicate;
    return AlertDialog(
      title: BrowserSystemText(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BrowserSystemTextField(
            controller: _controller,
            autofocus: true,
            maxLength: 50,
            decoration: InputDecoration(
              hint: const BrowserSystemText('ชื่อห้อง'),
              error: BrowserSystemText(
                  isDuplicate ? 'มีห้องชื่อนี้อยู่แล้ว' : null),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => isValid
                ? Navigator.of(context)
                    .pop((name: trimmed, categoryId: _categoryId))
                : null,
          ),
          DropdownButtonFormField<String?>(
            initialValue: _categoryId,
            decoration:
                const InputDecoration(label: BrowserSystemText('กลุ่ม')),
            items: _categoryDropdownItems(widget.categories),
            onChanged: (value) => setState(() => _categoryId = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const BrowserSystemText('ยกเลิก'),
        ),
        TextButton(
          onPressed: isValid
              ? () => Navigator.of(context)
                  .pop((name: trimmed, categoryId: _categoryId))
              : null,
          child: const BrowserSystemText('บันทึก'),
        ),
      ],
    );
  }
}

/// Delete-channel confirmation -- Design's Components: "ข้อความเตือนชัดเจน
/// ว่าโพสต์ในห้องนี้จะหายไปถาวร ... ปุ่มลบใช้สี error", States: "กำลังลบห้อง
/// -> loading state บน dialog". [onConfirm] performs the actual delete
/// (`ClubRepository.deleteChannel`) from inside the dialog itself so the
/// spinner reflects the real network round-trip, not just a local flag.
/// Returns true only once [onConfirm] has actually succeeded.
Future<bool> showDeleteClubChannelDialog(
  BuildContext context, {
  required String channelName,
  required Future<void> Function() onConfirm,
}) {
  return _showDestructiveConfirmDialog(
    context,
    title: 'ลบห้อง #$channelName?',
    message: 'ข้อความแชททั้งหมดในห้องนี้จะถูกลบทิ้งถาวรและไม่สามารถกู้คืนได้',
    confirmLabel: 'ลบห้อง',
    onConfirm: onConfirm,
  );
}

/// Create/edit category name dialog -- same shape as the channel one
/// (single text field, 50-char limit, blocks empty/duplicate
/// case-insensitive name within the Club) but for
/// `club_channel_categories` -- a different entity, kept as its own
/// sibling function rather than a parameter on the channel dialog.
Future<String?> showClubCategoryNameDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
  required bool Function(String name) isNameTaken,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _ClubCategoryNameDialog(
      title: title,
      initialName: initialName,
      isNameTaken: isNameTaken,
    ),
  );
}

class _ClubCategoryNameDialog extends StatefulWidget {
  const _ClubCategoryNameDialog({
    required this.title,
    required this.initialName,
    required this.isNameTaken,
  });

  final String title;
  final String initialName;
  final bool Function(String name) isNameTaken;

  @override
  State<_ClubCategoryNameDialog> createState() =>
      _ClubCategoryNameDialogState();
}

class _ClubCategoryNameDialogState extends State<_ClubCategoryNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimmed = _controller.text.trim();
    final isEmpty = trimmed.isEmpty;
    final isDuplicate = !isEmpty && widget.isNameTaken(trimmed);
    final isValid = !isEmpty && trimmed.length <= 50 && !isDuplicate;
    return AlertDialog(
      title: BrowserSystemText(widget.title),
      content: BrowserSystemTextField(
        controller: _controller,
        autofocus: true,
        maxLength: 50,
        decoration: InputDecoration(
          hint: const BrowserSystemText('ชื่อกลุ่ม'),
          error:
              BrowserSystemText(isDuplicate ? 'มีกลุ่มชื่อนี้อยู่แล้ว' : null),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => isValid ? Navigator.of(context).pop(trimmed) : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const BrowserSystemText('ยกเลิก'),
        ),
        TextButton(
          onPressed: isValid ? () => Navigator.of(context).pop(trimmed) : null,
          child: const BrowserSystemText('บันทึก'),
        ),
      ],
    );
  }
}

/// Delete-category confirmation -- deliberately different copy from
/// [showDeleteClubChannelDialog]: deleting a category is non-destructive
/// to messages (its channels just fall back to "ไม่มีกลุ่ม", per
/// `category_id`'s `on delete set null`), so the two dialogs must never
/// share the "ถูกลบทิ้งถาวร" warning.
Future<bool> showDeleteClubCategoryDialog(
  BuildContext context, {
  required String categoryName,
  required Future<void> Function() onConfirm,
}) {
  return _showDestructiveConfirmDialog(
    context,
    title: 'ลบกลุ่ม $categoryName?',
    message: 'ห้องแชทในกลุ่มนี้จะไม่ถูกลบ แค่ย้ายกลับไปเป็น "ไม่มีกลุ่ม"',
    confirmLabel: 'ลบกลุ่ม',
    onConfirm: onConfirm,
  );
}

Future<bool> _showDestructiveConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required Future<void> Function() onConfirm,
}) async {
  var succeeded = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      // Declared here, not inside StatefulBuilder's own `builder`
      // callback -- that callback re-runs on every setState it's given,
      // which would reset a `var` declared directly inside it back to
      // its initial value on every rebuild instead of preserving it.
      var isDeleting = false;
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          return AlertDialog(
            title: BrowserSystemText(title),
            content: BrowserSystemText(message,
                style: const TextStyle(color: WynColors.graphite)),
            actions: [
              TextButton(
                onPressed:
                    isDeleting ? null : () => Navigator.of(dialogContext).pop(),
                child: const BrowserSystemText('ยกเลิก'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: isDeleting
                    ? null
                    : () async {
                        setState(() => isDeleting = true);
                        try {
                          await onConfirm();
                          succeeded = true;
                          if (dialogContext.mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        } catch (_) {
                          setState(() => isDeleting = false);
                        }
                      },
                child: isDeleting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(dialogContext).colorScheme.error,
                        ),
                      )
                    : BrowserSystemText(confirmLabel),
              ),
            ],
          );
        },
      );
    },
  );
  return succeeded;
}

/// Lightweight "ย้ายไปกลุ่มอื่น" picker -- just the category dropdown from
/// [showClubChannelNameDialog], alone, for the common case of only
/// changing a channel's group. `.categoryId` on the returned wrapper is
/// the newly chosen category (`null` = "ไม่มีกลุ่ม"); the wrapper itself
/// being null means the dialog was cancelled -- a bare nullable
/// `String?` return can't distinguish "cancelled" from "chose ไม่มีกลุ่ม",
/// hence this small wrapper class instead.
class ClubCategorySelection {
  const ClubCategorySelection(this.categoryId);
  final String? categoryId;
}

Future<ClubCategorySelection?> showMoveChannelToCategoryDialog(
  BuildContext context, {
  required List<ClubChannelCategory> categories,
  required String? currentCategoryId,
}) {
  return showDialog<ClubCategorySelection>(
    context: context,
    builder: (dialogContext) => _MoveChannelToCategoryDialog(
      categories: categories,
      currentCategoryId: currentCategoryId,
    ),
  );
}

class _MoveChannelToCategoryDialog extends StatefulWidget {
  const _MoveChannelToCategoryDialog({
    required this.categories,
    required this.currentCategoryId,
  });

  final List<ClubChannelCategory> categories;
  final String? currentCategoryId;

  @override
  State<_MoveChannelToCategoryDialog> createState() =>
      _MoveChannelToCategoryDialogState();
}

class _MoveChannelToCategoryDialogState
    extends State<_MoveChannelToCategoryDialog> {
  late String? _categoryId = widget.currentCategoryId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const BrowserSystemText('ย้ายไปกลุ่มอื่น'),
      content: DropdownButtonFormField<String?>(
        initialValue: _categoryId,
        decoration: const InputDecoration(label: BrowserSystemText('กลุ่ม')),
        items: _categoryDropdownItems(widget.categories),
        onChanged: (value) => setState(() => _categoryId = value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const BrowserSystemText('ยกเลิก'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(ClubCategorySelection(_categoryId)),
          child: const BrowserSystemText('บันทึก'),
        ),
      ],
    );
  }
}

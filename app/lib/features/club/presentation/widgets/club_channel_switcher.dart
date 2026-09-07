import 'package:flutter/material.dart';

import '../../data/club_channel.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/action_sheet_row.dart';

/// WYN-127/128 -- the channel chip row above a Club's group chat
/// (ClubChatTab). Channels stopped being a Posts-tab concept once the
/// Founder's post-restructuring decision (2026-09-07) unified the feed
/// club-wide -- this switcher now only ever appears above Chat. See
/// .wyn/tasks/backlog/WYN-127-club-channels.md, AI Design Output
/// Components: horizontal `ListView`, `radiusFull` pill chips, active =
/// sapphire fill + white *bold* text (bold, not just color, per the
/// spec's Accessibility note -- color alone must never be the only
/// signal), inactive = hairline border + graphite text. The "+ ห้องใหม่"
/// chip is only ever built (not just disabled) for Owner/Admin -- the
/// spec explicitly prefers hiding it outright over a dead tap target for
/// everyone else.
class ClubChannelSwitcher extends StatelessWidget {
  const ClubChannelSwitcher({
    super.key,
    required this.channels,
    required this.selectedChannelId,
    required this.canManage,
    required this.onSelect,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    this.unreadChannelIds = const {},
  });

  final List<ClubChannel> channels;
  final String? selectedChannelId;

  /// Owner/Admin only (`ClubMemberRolePermissions.canManageClub`) --
  /// gates both the "+ ห้องใหม่" chip and the long-press manage sheet.
  final bool canManage;

  /// WYN-128, moved here once Chat became its own top-level tab (no more
  /// single "แชท" toggle segment to badge instead) -- channel ids with
  /// at least 1 unread message, rendered as a small dot on that chip,
  /// Discord-style.
  final Set<String> unreadChannelIds;

  final ValueChanged<String> onSelect;
  final VoidCallback onCreate;
  final ValueChanged<ClubChannel> onEdit;
  final ValueChanged<ClubChannel> onDelete;

  Future<void> _showManageSheet(BuildContext context, ClubChannel channel) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        ActionSheetRow(
          icon: Icons.edit_outlined,
          label: 'แก้ไขชื่อห้อง',
          onTap: () {
            Navigator.of(sheetContext).pop();
            onEdit(channel);
          },
        ),
        ActionSheetRow(
          icon: Icons.delete_outline,
          label: 'ลบห้อง',
          onTap: () {
            Navigator.of(sheetContext).pop();
            onDelete(channel);
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Design's States: "ห้องเดียว ... แถบ channel ยังโชว์อยู่" -- this
    // widget is always built by the caller regardless of channels.length,
    // never conditionally hidden for a single-channel Club.
    return SizedBox(
      height: WynSpacing.touchTargetMin + WynSpacing.space2 * 2,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space4,
          vertical: WynSpacing.space2,
        ),
        children: [
          for (final channel in channels) ...[
            _ChannelChip(
              key: ValueKey('club_channel_chip_${channel.id}'),
              label: '#${channel.name}',
              selected: channel.id == selectedChannelId,
              hasUnread: unreadChannelIds.contains(channel.id),
              onTap: () => onSelect(channel.id),
              onLongPress: canManage ? () => _showManageSheet(context, channel) : null,
            ),
            const SizedBox(width: WynSpacing.space2),
          ],
          if (canManage)
            _NewChannelChip(key: const Key('club_channel_new_chip'), onTap: onCreate),
        ],
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  const _ChannelChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.hasUnread = false,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final bool hasUnread;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: hasUnread ? '$label มีข้อความใหม่' : label,
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
        child: Container(
          constraints: const BoxConstraints(minHeight: WynSpacing.touchTargetMin),
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? WynColors.sapphire : WynColors.paper,
            borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
            border: selected ? null : Border.all(color: WynColors.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  // Bold on the selected chip too, not just a color swap --
                  // Design's Accessibility note: "ห้องที่เลือกอยู่ต้องสื่อสารได้
                  // ทั้งสี+ตัวหนา".
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  color: selected ? WynColors.paper : WynColors.graphite,
                ),
              ),
              if (hasUnread) ...[
                const SizedBox(width: 6),
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? WynColors.paper : WynColors.sapphire,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewChannelChip extends StatelessWidget {
  const _NewChannelChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'สร้างห้องใหม่',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
        child: Container(
          constraints: const BoxConstraints(minHeight: WynSpacing.touchTargetMin),
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
            border: Border.all(color: WynColors.mutedNeutral),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: WynColors.mutedNeutral),
              SizedBox(width: 4),
              Text(
                'ห้องใหม่',
                style: TextStyle(fontSize: 14, color: WynColors.mutedNeutral),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create/edit channel dialog -- Design's Components: "ช่องกรอกชื่อ
/// (จำกัดความยาว, กันชื่อว่าง/ซ้ำ), ปุ่มยืนยัน/ยกเลิกมาตรฐาน". [isNameTaken]
/// is a client-side, case-insensitive dupe check against the already-
/// loaded channel list (the real, authoritative check is the DB's own
/// `club_channels_club_id_lower_name_key` unique index -- this is just
/// immediate feedback, not the security boundary). Returns the trimmed
/// name, or null if cancelled.
Future<String?> showClubChannelNameDialog(
  BuildContext context, {
  required String title,
  String initialName = '',
  required bool Function(String name) isNameTaken,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => _ClubChannelNameDialog(
      title: title,
      initialName: initialName,
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
    required this.isNameTaken,
  });

  final String title;
  final String initialName;
  final bool Function(String name) isNameTaken;

  @override
  State<_ClubChannelNameDialog> createState() => _ClubChannelNameDialogState();
}

class _ClubChannelNameDialogState extends State<_ClubChannelNameDialog> {
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
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 50,
        decoration: InputDecoration(
          hintText: 'ชื่อห้อง',
          errorText: isDuplicate ? 'มีห้องชื่อนี้อยู่แล้ว' : null,
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => isValid ? Navigator.of(context).pop(trimmed) : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        TextButton(
          onPressed: isValid ? () => Navigator.of(context).pop(trimmed) : null,
          child: const Text('บันทึก'),
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
            title: Text('ลบห้อง #$channelName?'),
            content: const Text(
              'ข้อความแชททั้งหมดในห้องนี้จะถูกลบทิ้งถาวรและไม่สามารถกู้คืนได้',
              style: TextStyle(color: WynColors.graphite),
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.of(dialogContext).pop(),
                child: const Text('ยกเลิก'),
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
                          if (dialogContext.mounted) Navigator.of(dialogContext).pop();
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
                    : const Text('ลบห้อง'),
              ),
            ],
          );
        },
      );
    },
  );
  return succeeded;
}

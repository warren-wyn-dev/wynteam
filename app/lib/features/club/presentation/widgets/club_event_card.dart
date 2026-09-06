import 'package:flutter/material.dart';

import '../../data/club_event.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/action_sheet_row.dart';
import '../../../profile/presentation/widgets/avatar_circle.dart';

/// WYN-118, Design's "3 ปุ่มตรงในการ์ด" decision -- RSVP happens right
/// on the card (same "vote without opening a new screen" posture as
/// Poll, WYN-115), no separate Event Detail screen. Staff
/// (`canManage`, same tier as pin/unpin) get an edit/delete menu; a
/// tap on the "X ไป" summary opens the attendee list.
class ClubEventCard extends StatelessWidget {
  const ClubEventCard({
    super.key,
    required this.event,
    required this.canManage,
    required this.onRsvp,
    required this.onShowAttendees,
    required this.onEdit,
    required this.onDelete,
  });

  final ClubEvent event;
  final bool canManage;
  final ValueChanged<RsvpStatus> onRsvp;
  final ValueChanged<RsvpStatus> onShowAttendees;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Future<void> _openMoreMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => ActionSheetBody(rows: [
        ActionSheetRow(
          icon: Icons.edit_outlined,
          label: 'แก้ไขกิจกรรม',
          onTap: () {
            Navigator.of(sheetContext).pop();
            onEdit();
          },
        ),
        ActionSheetRow(
          icon: Icons.delete_outline,
          label: 'ลบกิจกรรม',
          onTap: () {
            Navigator.of(sheetContext).pop();
            onDelete();
          },
        ),
      ]),
    );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
      padding: const EdgeInsets.all(WynSpacing.space3),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (canManage)
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'เพิ่มเติม',
                  onPressed: () => _openMoreMenu(context),
                ),
            ],
          ),
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: WynSpacing.space1),
            Text(event.description!),
          ],
          const SizedBox(height: WynSpacing.space2),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16),
              const SizedBox(width: 6),
              Text(_formatDateTime(event.startsAt)),
            ],
          ),
          const SizedBox(height: WynSpacing.space1),
          Row(
            children: [
              Icon(
                event.locationType == ClubEventLocationType.online
                    ? Icons.link
                    : Icons.location_on_outlined,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(event.location, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: WynSpacing.space2),
          Row(
            children: [
              InkWell(
                onTap: () => onShowAttendees(RsvpStatus.going),
                child: Text(
                  '${event.goingCount} ไป',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: WynSpacing.space3),
              InkWell(
                onTap: () => onShowAttendees(RsvpStatus.maybe),
                child: Text(
                  '${event.maybeCount} อาจจะไป',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                ),
              ),
            ],
          ),
          if (!event.isPast) ...[
            const SizedBox(height: WynSpacing.space2),
            Row(
              children: [
                Expanded(
                  child: _RsvpButton(
                    label: 'ไปแน่นอน',
                    selected: event.myRsvpStatus == RsvpStatus.going,
                    onTap: () => onRsvp(RsvpStatus.going),
                  ),
                ),
                const SizedBox(width: WynSpacing.space2),
                Expanded(
                  child: _RsvpButton(
                    label: 'อาจจะไป',
                    selected: event.myRsvpStatus == RsvpStatus.maybe,
                    onTap: () => onRsvp(RsvpStatus.maybe),
                  ),
                ),
                const SizedBox(width: WynSpacing.space2),
                Expanded(
                  child: _RsvpButton(
                    label: 'ไม่ไป',
                    selected: event.myRsvpStatus == RsvpStatus.notGoing,
                    onTap: () => onRsvp(RsvpStatus.notGoing),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _RsvpButton extends StatelessWidget {
  const _RsvpButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? scheme.primary : null,
        foregroundColor: selected ? scheme.onPrimary : scheme.onSurface,
        side: BorderSide(color: selected ? scheme.primary : scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center),
    );
  }
}

/// The attendee bottom sheet -- one status at a time (see
/// [ClubEventCard]'s tap targets), backing the Requirements' "เห็น...
/// รายชื่อคนที่ตอบรับ".
class ClubEventAttendeesSheet extends StatelessWidget {
  const ClubEventAttendeesSheet({
    super.key,
    required this.title,
    required this.attendees,
  });

  final String title;
  final List<ClubEventAttendee> attendees;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(WynSpacing.space4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: WynSpacing.space3),
            if (attendees.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: WynSpacing.space4),
                child: Center(child: Text('ยังไม่มีใครตอบรับ')),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: attendees.length,
                  itemBuilder: (context, index) {
                    final attendee = attendees[index];
                    return ListTile(
                      leading: AvatarCircle(
                        imageUrl: attendee.avatarUrl,
                        fallbackText: attendee.username,
                        radius: 18,
                      ),
                      title: Text(attendee.nameOrUsername),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

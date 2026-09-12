import 'package:wyn/core/typography/browser_system_picker.dart';
import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

import '../data/club_event.dart';
import '../data/club_event_repository.dart';
import '../../../core/design/wyn_spacing.dart';

/// Create (or, when [existingEvent] is set, edit) a Club Event -- Screen
/// 1 of WYN-118. Same permission tier as pin/unpin (owner/admin/
/// moderator); the caller (ClubEventsTab) is responsible for only
/// reaching this screen when `canManage` is true -- RLS is the real
/// enforcement either way.
class CreateClubEventScreen extends StatefulWidget {
  const CreateClubEventScreen({
    super.key,
    required this.clubEventRepository,
    required this.clubId,
    this.existingEvent,
  });

  final ClubEventRepository clubEventRepository;
  final String clubId;

  /// Non-null when editing an existing event instead of creating a new
  /// one -- the form pre-fills from it and saves via `updateEvent`
  /// instead of `createEvent`.
  final ClubEvent? existingEvent;

  @override
  State<CreateClubEventScreen> createState() => _CreateClubEventScreenState();
}

class _CreateClubEventScreenState extends State<CreateClubEventScreen> {
  static const _titleMaxLength = 200;
  static const _descriptionMaxLength = 2000;
  static const _locationMaxLength = 500;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late DateTime _startsAt;
  late ClubEventLocationType _locationType;

  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.existingEvent != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingEvent;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descriptionController = TextEditingController(text: existing?.description ?? '');
    _locationController = TextEditingController(text: existing?.location ?? '');
    _startsAt = existing?.startsAt ??
        DateTime.now().add(const Duration(days: 1, hours: 1));
    _locationType = existing?.locationType ?? ClubEventLocationType.offline;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await pickBrowserSystemDate(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      _startsAt = DateTime(
        picked.year, picked.month, picked.day, _startsAt.hour, _startsAt.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await pickBrowserSystemTime(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (picked == null) return;
    setState(() {
      _startsAt = DateTime(
        _startsAt.year, _startsAt.month, _startsAt.day, picked.hour, picked.minute,
      );
    });
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _locationController.text.trim().isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final existing = widget.existingEvent;
      if (existing != null) {
        await widget.clubEventRepository.updateEvent(
          eventId: existing.id,
          title: _titleController.text,
          description: _descriptionController.text,
          startsAt: _startsAt,
          locationType: _locationType,
          location: _locationController.text,
        );
      } else {
        await widget.clubEventRepository.createEvent(
          clubId: widget.clubId,
          title: _titleController.text,
          description: _descriptionController.text,
          startsAt: _startsAt,
          locationType: _locationType,
          location: _locationController.text,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDateTime(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} · $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_isSaving &&
        _titleController.text.trim().isNotEmpty &&
        _locationController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: BrowserSystemText(_isEditing ? 'แก้ไขกิจกรรม' : 'สร้างกิจกรรม')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WynSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrowserSystemTextField(
                controller: _titleController,
                maxLength: _titleMaxLength,
                enabled: !_isSaving,
                decoration: const InputDecoration(label: BrowserSystemText('ชื่อกิจกรรม')),
                onChanged: (_) => setState(() {}),
              ),
              BrowserSystemTextField(
                controller: _descriptionController,
                maxLength: _descriptionMaxLength,
                maxLines: 4,
                enabled: !_isSaving,
                decoration: const InputDecoration(label: BrowserSystemText('รายละเอียด (ไม่บังคับ)')),
              ),
              const SizedBox(height: WynSpacing.space3),
              BrowserSystemText('วันเวลา', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: WynSpacing.space1),
              OutlinedButton.icon(
                onPressed: _isSaving ? null : () async {
                  await _pickDate();
                  if (!mounted) return;
                  await _pickTime();
                },
                icon: const Icon(Icons.schedule),
                label: BrowserSystemText(_formatDateTime(_startsAt)),
              ),
              const SizedBox(height: WynSpacing.space3),
              BrowserSystemText('สถานที่', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: WynSpacing.space1),
              SegmentedButton<ClubEventLocationType>(
                segments: const [
                  ButtonSegment(
                    value: ClubEventLocationType.offline,
                    label: BrowserSystemText('ออฟไลน์'),
                    icon: Icon(Icons.location_on_outlined),
                  ),
                  ButtonSegment(
                    value: ClubEventLocationType.online,
                    label: BrowserSystemText('ออนไลน์'),
                    icon: Icon(Icons.link),
                  ),
                ],
                selected: {_locationType},
                onSelectionChanged: _isSaving
                    ? null
                    : (selection) => setState(() => _locationType = selection.first),
              ),
              const SizedBox(height: WynSpacing.space2),
              BrowserSystemTextField(
                controller: _locationController,
                maxLength: _locationMaxLength,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  label: BrowserSystemText(_locationType == ClubEventLocationType.online ? 'ลิงก์' : 'ที่อยู่'),
                  hint: BrowserSystemText(_locationType == ClubEventLocationType.online
                      ? 'https://...'
                      : 'สถานที่จัดกิจกรรม'),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: WynSpacing.space4),
              if (_errorMessage != null) ...[
                BrowserSystemText(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: WynSpacing.space3),
              ],
              FilledButton(
                onPressed: canSave ? _save : null,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : BrowserSystemText(_isEditing ? 'บันทึก' : 'สร้างกิจกรรม'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

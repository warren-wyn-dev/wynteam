import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../data/drop_repository.dart';

/// WYN-037 -- edits a Drop's caption (or a Poll Drop's question, same
/// field) within the 30-minute edit window `edit_drop()` enforces
/// server-side. Nothing else about the Drop is editable here on
/// purpose: not the image, not a Poll's options/duration -- see
/// .wyn/docs/design/wyn-037-edit-delete-drop.md's Screen 2 for why
/// (changing either after people have already seen/voted would be
/// misleading).
///
/// Deliberately a plain [TextField], not `MentionInput` -- using
/// MentionInput here would imply new @mentions typed during an edit
/// get resolved into `drop_mentions`/trigger a notification, which
/// `editDrop()` never does (it only ever touches `caption`/`edited_at`
/// -- see the Design doc's own scope note on this).
class EditDropCaptionScreen extends StatefulWidget {
  const EditDropCaptionScreen({
    super.key,
    required this.dropRepository,
    required this.dropId,
    required this.initialCaption,
    this.isPollQuestion = false,
    this.hasImage = true,
  });

  final DropRepository dropRepository;
  final String dropId;
  final String? initialCaption;

  /// True when this Drop is a Poll -- [initialCaption] is then its
  /// question, not an optional caption, so (unlike an image-mode
  /// Drop) it can never be saved empty: a Poll with no visible
  /// question but live options/votes would be confusing for anyone
  /// looking at it, including people who already voted.
  final bool isPollQuestion;

  /// WYNOS V1.0.0 Beta requirement 2: a text-only Drop (no image, not a
  /// Poll) can no longer be saved with an empty caption either -- unlike
  /// an image-mode Drop, that would leave nothing at all (violates the
  /// `drops_has_content` DB constraint, and more importantly would just
  /// be an empty post). Defaults to `true` (the historical "every Drop
  /// has an image" assumption) so this stays opt-in only for the one
  /// caller that can actually produce a false value.
  final bool hasImage;

  @override
  State<EditDropCaptionScreen> createState() => _EditDropCaptionScreenState();
}

class _EditDropCaptionScreenState extends State<EditDropCaptionScreen> {
  static const _maxLength = 500;

  late final _captionController =
      TextEditingController(text: widget.initialCaption ?? '');
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  bool get _canSave {
    if (_isSaving) return false;
    final trimmed = _captionController.text.trim();
    if ((widget.isPollQuestion || !widget.hasImage) && trimmed.isEmpty) {
      return false;
    }
    return trimmed != (widget.initialCaption ?? '').trim();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await widget.dropRepository.editDrop(
        dropId: widget.dropId,
        caption: _captionController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(_captionController.text.trim());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('แก้ไข Drop'),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('บันทึก'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(WynSpacing.space4),
        children: [
          TextField(
            controller: _captionController,
            maxLength: _maxLength,
            maxLines: 6,
            minLines: 3,
            autofocus: true,
            decoration: InputDecoration(
              hintText: widget.isPollQuestion ? 'คำถามโพล...' : 'เขียนแคปชัน...',
              border: InputBorder.none,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: WynSpacing.space2),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

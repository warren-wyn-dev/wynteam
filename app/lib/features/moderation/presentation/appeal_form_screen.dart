import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/wyn_spacing.dart';
import '../data/appeal_repository.dart';

/// Screen 1 of .wyn/docs/design/wyn-030-appeal-system.md -- one form
/// reused by all 5 appealable action types (Warning/Remove Content/
/// Restrict/Suspend/Ban). A full screen, not a bottom sheet, because it
/// has more going on (a long text field + up to 3 images) than
/// ReportSheet/ModerationActionSheet -- closer in shape to
/// CreateClubPostScreen, whose image picker this reuses.
class AppealFormScreen extends StatefulWidget {
  const AppealFormScreen({
    super.key,
    required this.appealRepository,
    required this.actionId,
    required this.actionLabel,
  });

  final AppealRepository appealRepository;
  final String actionId;
  final String actionLabel;

  @override
  State<AppealFormScreen> createState() => _AppealFormScreenState();
}

class _AppealFormScreenState extends State<AppealFormScreen> {
  static const _maxImages = 3;

  final _reasonController = TextEditingController();
  final List<Uint8List> _images = [];
  final List<String> _imageExtensions = [];

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _canSubmit => !_isSubmitting && _reasonController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) return;

    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      limit: remaining,
    );
    if (picked.isEmpty) return;

    for (final file in picked.take(remaining)) {
      final bytes = await file.readAsBytes();
      final extension =
          file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
      _images.add(bytes);
      _imageExtensions.add(extension);
    }
    if (!mounted) return;
    setState(() {});
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      _imageExtensions.removeAt(index);
    });
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await widget.appealRepository.submitAppeal(
        actionId: widget.actionId,
        reason: _reasonController.text.trim(),
        evidenceImages: _images.isEmpty ? null : _images,
        evidenceExtensions: _images.isEmpty ? null : _imageExtensions,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'ส่งอุทธรณ์ไม่สำเร็จ ลองอีกครั้ง');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text('อุทธรณ์: ${widget.actionLabel}'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WynSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _reasonController,
                enabled: !_isSubmitting,
                minLines: 4,
                maxLines: 8,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'เหตุผลที่คุณคิดว่าคำตัดสินนี้ไม่ถูกต้อง (จำเป็น)',
                ),
              ),
              const SizedBox(height: WynSpacing.space4),
              if (_images.isNotEmpty) ...[
                _buildImageRow(),
                const SizedBox(height: WynSpacing.space2),
              ],
              OutlinedButton.icon(
                onPressed: (_isSubmitting || _images.length >= _maxImages) ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('แนบรูปหลักฐาน (ไม่บังคับ, สูงสุด 3 รูป)'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: WynSpacing.space4),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: WynSpacing.space6),
              FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ส่งอุทธรณ์'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageRow() {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _images.length,
        separatorBuilder: (context, index) => const SizedBox(width: WynSpacing.space2),
        itemBuilder: (context, index) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                child: Image.memory(
                  _images[index],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              // 44x44 hit target -- CreateClubPostScreen's equivalent
              // button is only 18px, which fails DS-008's touch-target
              // minimum. Not copied here on purpose; see the design
              // doc's Screen 1 accessibility note.
              Positioned(
                right: -8,
                top: -8,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Semantics(
                    label: 'ลบรูปหลักฐานที่ ${index + 1}',
                    button: true,
                    excludeSemantics: true,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isSubmitting ? null : () => _removeImage(index),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

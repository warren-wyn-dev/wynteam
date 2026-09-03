import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/design/wyn_colors.dart';
import '../../../../../core/design/wyn_spacing.dart';
import '../../../../../core/widgets/labeled_field.dart';
import '../../../../profile/presentation/widgets/avatar_circle.dart';
import '../onboarding_scaffold.dart';

/// Screen 7 -- Profile Optional. Both avatar and bio are genuinely
/// optional -- "ข้าม" (Skip) always works, unconditionally, matching the
/// design spec's "ห้ามบังคับกรอก Bio" / "ผู้ใช้สามารถ Skip ได้".
class ProfileOptionalStep extends StatefulWidget {
  const ProfileOptionalStep({
    super.key,
    required this.onContinue,
    required this.onBack,
    required this.stepIndex,
    required this.stepCount,
    required this.uploadAvatar,
    this.fallbackAvatarText = '',
    this.initialAvatarUrl,
    this.isLoading = false,
    this.errorText,
  });

  /// Called with (avatarUrl, bio) -- both nullable, either or both may be
  /// left untouched. Used for both "ต่อไป" (with whatever was
  /// picked/typed) and "ข้าม" (called with the untouched initial values,
  /// or null/null if none).
  final Future<void> Function(String? avatarUrl, String? bio) onContinue;
  final VoidCallback onBack;
  final int stepIndex;
  final int stepCount;
  final bool isLoading;
  final String? errorText;

  /// Uploads picked image bytes and returns the new public URL --
  /// injected so this screen doesn't need to know about ProfileRepository
  /// directly (kept swappable/testable the same way every other
  /// repository-backed screen in this app is).
  final Future<String> Function(Uint8List bytes, String fileExtension)
      uploadAvatar;

  final String fallbackAvatarText;

  /// Prefilled from the Google account's photo, if any (design spec:
  /// "ถ้า Google มี profile image สามารถใช้เป็น default avatar ได้") --
  /// used as-is unless the user picks a different image.
  final String? initialAvatarUrl;

  @override
  State<ProfileOptionalStep> createState() => _ProfileOptionalStepState();
}

class _ProfileOptionalStepState extends State<ProfileOptionalStep> {
  final _bioController = TextEditingController();
  Uint8List? _pickedBytes;
  String? _pickedExtension;
  bool _isUploading = false;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extension =
        picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';

    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _pickedExtension = extension;
    });
  }

  Future<void> _showImageSourceSheet() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('ถ่ายรูปใหม่'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากคลังภาพ'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _continue({required bool skip}) async {
    if (skip) {
      await widget.onContinue(widget.initialAvatarUrl, null);
      return;
    }

    var avatarUrl = widget.initialAvatarUrl;
    if (_pickedBytes != null) {
      if (!mounted) return;
      setState(() => _isUploading = true);
      try {
        avatarUrl = await widget.uploadAvatar(
            _pickedBytes!, _pickedExtension ?? 'jpg');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
    final bio = _bioController.text.trim();
    await widget.onContinue(avatarUrl, bio.isEmpty ? null : bio);
  }

  @override
  Widget build(BuildContext context) {
    final busy = widget.isLoading || _isUploading;
    return OnboardingScaffold(
      title: 'เติมเต็มโปรไฟล์ของคุณ',
      description: 'ขั้นตอนนี้ไม่บังคับ ข้ามไปก่อนแล้วค่อยกลับมาแก้ทีหลังได้เสมอ',
      stepIndex: widget.stepIndex,
      stepCount: widget.stepCount,
      primaryLabel: 'ต่อไป',
      isLoading: busy,
      onBack: widget.onBack,
      errorText: widget.errorText,
      onPrimaryPressed: busy ? null : () => _continue(skip: false),
      footer: TextButton(
        onPressed: busy ? null : () => _continue(skip: true),
        child: const Text('ข้ามขั้นตอนนี้',
            style: TextStyle(color: WynColors.graphite)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: GestureDetector(
              key: const Key('onboarding_avatar_edit_button'),
              onTap: busy ? null : _showImageSourceSheet,
              child: Stack(
                children: [
                  _pickedBytes != null
                      ? CircleAvatar(
                          radius: 46,
                          backgroundImage: MemoryImage(_pickedBytes!),
                        )
                      : AvatarCircle(
                          imageUrl: widget.initialAvatarUrl,
                          fallbackText: widget.fallbackAvatarText,
                          radius: 46,
                          ring: true,
                        ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: WynColors.sapphire,
                        border: Border.fromBorderSide(
                          BorderSide(color: WynColors.paper, width: 2),
                        ),
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 14, color: WynColors.paper),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: WynSpacing.space6),
          LabeledField(
            key: const Key('onboarding_bio_field'),
            label: 'Bio (ไม่บังคับ)',
            controller: _bioController,
            maxLength: 160,
            helper: 'บอกเล่าเกี่ยวกับตัวคุณสั้น ๆ',
            multiline: true,
            enabled: !busy,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}

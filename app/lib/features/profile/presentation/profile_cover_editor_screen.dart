import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile.dart';
import '../data/profile_repository.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';

/// Small, focused Beta5 editor for the wide profile cover. Basic identity
/// editing stays in EditProfileScreen; this screen exists so tapping the
/// cover itself does exactly what the user expects without restoring a
/// large edit button under the profile stats.
class ProfileCoverEditorScreen extends StatefulWidget {
  const ProfileCoverEditorScreen({
    super.key,
    required this.profileRepository,
    required this.profile,
  });

  final ProfileRepository profileRepository;
  final Profile profile;

  @override
  State<ProfileCoverEditorScreen> createState() =>
      _ProfileCoverEditorScreenState();
}

class _ProfileCoverEditorScreenState extends State<ProfileCoverEditorScreen> {
  Uint8List? _bytes;
  String _extension = 'jpg';
  bool _saving = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1800,
      maxHeight: 1000,
      imageQuality: 88,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    final name = image.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : 'jpg';
    setState(() {
      _bytes = bytes;
      _extension = {'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ? ext : 'jpg';
      _error = null;
    });
  }

  Future<void> _chooseSource() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกรูปจากคลัง'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ถ่ายรูป'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.profileRepository.uploadCover(
        userId: widget.profile.id,
        bytes: bytes,
        fileExtension: _extension,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'อัปโหลดรูปปกไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _bytes == null
        ? (widget.profile.coverUrl == null
              ? Container(color: WynColors.surfaceTint)
              : Image.network(
                  widget.profile.coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      Container(color: WynColors.surfaceTint),
                ))
        : Image.memory(_bytes!, fit: BoxFit.cover);

    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        title: const Text('รูปปกโปรไฟล์'),
        actions: [
          TextButton(
            onPressed: _bytes == null || _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('บันทึก'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(WynSpacing.space5),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
            child: AspectRatio(aspectRatio: 16 / 7, child: preview),
          ),
          const SizedBox(height: WynSpacing.space4),
          OutlinedButton.icon(
            onPressed: _saving ? null : _chooseSource,
            icon: const Icon(Icons.image_outlined),
            label: const Text('เลือกรูปปก'),
          ),
          const SizedBox(height: WynSpacing.space2),
          Text(
            'รูปแนวนอนจะดูดีที่สุด และ WYNOS จะครอปให้พอดีกับพื้นที่ปกอัตโนมัติ',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: WynColors.mutedNeutral),
          ),
          if (_error != null) ...[
            const SizedBox(height: WynSpacing.space3),
            Text(_error!, style: const TextStyle(color: WynColors.iconLikeActive)),
          ],
        ],
      ),
    );
  }
}

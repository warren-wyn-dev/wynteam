import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile.dart';
import '../data/profile_repository.dart';
import 'widgets/avatar_circle.dart';

/// Screen 2 — Edit Profile.
/// See .wyn/docs/design/wyn-003-user-profile.md
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profileRepository,
    required this.profile,
  });

  final ProfileRepository profileRepository;
  final Profile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _bioMaxLength = 160;

  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;

  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.profile.displayName ?? '');
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    // Resized/compressed client-side per WYN-003's Risks (upload speed,
    // storage footprint) -- not uploaded yet, just previewed locally
    // until "บันทึก" is pressed.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extension = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';

    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageExtension = extension;
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

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      var avatarUrl = widget.profile.avatarUrl;
      if (_pickedImageBytes != null) {
        avatarUrl = await widget.profileRepository.uploadAvatar(
          userId: widget.profile.id,
          bytes: _pickedImageBytes!,
          fileExtension: _pickedImageExtension ?? 'jpg',
        );
      }

      final displayName = _displayNameController.text.trim();
      final bio = _bioController.text.trim();

      await widget.profileRepository.updateProfile(
        userId: widget.profile.id,
        displayName: displayName,
        bio: bio,
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        Profile(
          id: widget.profile.id,
          username: widget.profile.username,
          displayName: displayName,
          bio: bio,
          avatarUrl: avatarUrl,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bioLength = _bioController.text.length;
    final bioRemaining = _bioMaxLength - bioLength;

    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขโปรไฟล์')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _isSaving ? null : _showImageSourceSheet,
                  child: Stack(
                    children: [
                      _pickedImageBytes != null
                          ? CircleAvatar(
                              radius: 40,
                              backgroundImage: MemoryImage(_pickedImageBytes!),
                            )
                          : AvatarCircle(
                              imageUrl: widget.profile.avatarUrl,
                              fallbackText: widget.profile.username,
                            ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          child: const Icon(Icons.camera_alt, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _displayNameController,
                maxLength: 50,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'ชื่อแสดง',
                  helperText: '1-50 ตัวอักษร',
                ),
              ),
              TextField(
                controller: _bioController,
                maxLength: _bioMaxLength,
                maxLines: 4,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  labelText: 'Bio',
                  helperText: 'คำอธิบายสั้น ๆ เกี่ยวกับตัวคุณ',
                  counterText: '$bioLength/$_bioMaxLength',
                  counterStyle: TextStyle(
                    color: bioRemaining < 20
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('บันทึก'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

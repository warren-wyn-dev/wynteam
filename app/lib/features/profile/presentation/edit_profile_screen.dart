import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile.dart';
import '../data/profile_repository.dart';
import 'widgets/avatar_circle.dart';
import '../../../core/design/wyn_spacing.dart';

/// Same shape as onboarding's UsernameSetupScreen (WYN-002) -- ASCII
/// alphanumeric/underscore, 3-20 characters. Duplicated rather than
/// shared since Profile and Auth are deliberately independent features
/// in this codebase.
enum _UsernameStatus { unchanged, checking, available, taken, invalid }

/// Screen 2 — Edit Profile.
/// See .wyn/docs/design/wyn-003-user-profile.md,
/// WYNOS V1.0.0 Beta requirement 5 (editable @username).
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
  static final _usernameRegExp = RegExp(r'^[a-z0-9_]{3,20}$');

  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _usernameController;

  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;

  _UsernameStatus _usernameStatus = _UsernameStatus.unchanged;
  Timer? _usernameDebounce;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.profile.displayName ?? '');
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _usernameController =
        TextEditingController(text: widget.profile.username);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  /// Same debounce-then-check shape as UsernameSetupScreen's onChanged
  /// (WYN-002), plus one extra case: typing back the exact username this
  /// profile already has is "unchanged", not a fresh availability check
  /// (there's nothing to look up -- it's trivially fine).
  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();

    if (value == widget.profile.username) {
      setState(() => _usernameStatus = _UsernameStatus.unchanged);
      return;
    }

    if (!_usernameRegExp.hasMatch(value)) {
      setState(() => _usernameStatus = _UsernameStatus.invalid);
      return;
    }

    setState(() => _usernameStatus = _UsernameStatus.checking);
    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      final available = await widget.profileRepository.isUsernameAvailable(
        value,
        currentUserId: widget.profile.id,
      );
      if (!mounted) return;
      setState(() {
        _usernameStatus =
            available ? _UsernameStatus.available : _UsernameStatus.taken;
      });
    });
  }

  bool get _canSave =>
      !_isSaving &&
      _usernameStatus != _UsernameStatus.checking &&
      _usernameStatus != _UsernameStatus.taken &&
      _usernameStatus != _UsernameStatus.invalid;

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
      final username = _usernameController.text.trim();

      await widget.profileRepository.updateProfile(
        userId: widget.profile.id,
        displayName: displayName,
        bio: bio,
      );

      // Only touches the DB when the username actually changed -- typing
      // back the original value is _UsernameStatus.unchanged, which
      // _canSave already allows through without a redundant write.
      if (username != widget.profile.username) {
        await widget.profileRepository.updateUsername(
          userId: widget.profile.id,
          username: username,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(
        Profile(
          id: widget.profile.id,
          username: username,
          displayName: displayName,
          bio: bio,
          avatarUrl: avatarUrl,
        ),
      );
    } on UsernameTakenException {
      if (!mounted) return;
      setState(() {
        _usernameStatus = _UsernameStatus.taken;
        _errorMessage = 'ชื่อผู้ใช้นี้ถูกใช้แล้ว';
      });
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
          padding: const EdgeInsets.all(WynSpacing.space6),
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
              const SizedBox(height: WynSpacing.space6),
              TextField(
                controller: _usernameController,
                maxLength: 20,
                enabled: !_isSaving,
                decoration: InputDecoration(
                  prefixText: '@',
                  labelText: 'ชื่อผู้ใช้',
                  helperText:
                      'ใช้ตัวอักษร a-z, 0-9 และ _ เท่านั้น (3-20 ตัวอักษร)',
                  errorText: switch (_usernameStatus) {
                    _UsernameStatus.taken => 'ชื่อผู้ใช้นี้ถูกใช้แล้ว',
                    _UsernameStatus.invalid => 'รูปแบบไม่ถูกต้อง',
                    _ => null,
                  },
                  suffixIcon: switch (_usernameStatus) {
                    _UsernameStatus.checking => const Padding(
                        padding: EdgeInsets.all(WynSpacing.space3),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    _UsernameStatus.available =>
                      const Icon(Icons.check_circle, color: Colors.green),
                    _ => null,
                  },
                ),
                onChanged: _onUsernameChanged,
              ),
              const SizedBox(height: WynSpacing.space4),
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
              const SizedBox(height: WynSpacing.space6),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: WynSpacing.space3),
              ],
              FilledButton(
                onPressed: _canSave ? _save : null,
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

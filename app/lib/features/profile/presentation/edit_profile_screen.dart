import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile.dart';
import '../data/profile_repository.dart';
import 'widgets/avatar_circle.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/widgets/labeled_field.dart';

/// Same shape as onboarding's UsernameSetupScreen (WYN-002) -- ASCII
/// alphanumeric/underscore, 3-20 characters. Duplicated rather than
/// shared since Profile and Auth are deliberately independent features
/// in this codebase.
enum _UsernameStatus { unchanged, checking, available, taken, invalid }

/// Screen 2 — Edit Profile, restyled to 06-edit-profile.tsx.
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
  static const _displayNameMaxLength = 50;
  static const _usernameMaxLength = 20;
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

  /// 06-edit-profile.tsx: "บันทึก" is disabled (faint) until something
  /// has actually changed from the original values -- same
  /// disabled/enabled-until-dirty pattern as Drop/Create Club, so a
  /// no-op save is never possible. A freshly-picked (not yet uploaded)
  /// avatar counts as a change too, even though the reference's own
  /// static mockup has no real avatar upload wired up to compare
  /// against.
  bool get _hasChanges =>
      _usernameController.text != widget.profile.username ||
      _displayNameController.text != (widget.profile.displayName ?? '') ||
      _bioController.text != (widget.profile.bio ?? '') ||
      _pickedImageBytes != null;

  bool get _canSave =>
      !_isSaving &&
      _hasChanges &&
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
    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 22, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'แก้ไขโปรไฟล์',
          style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: WynSpacing.space6),
              Center(
                child: GestureDetector(
                  key: const Key('avatar_edit_button'),
                  onTap: _isSaving ? null : _showImageSourceSheet,
                  child: Stack(
                    children: [
                      _pickedImageBytes != null
                          ? Container(
                              width: 98,
                              height: 98,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.fromBorderSide(
                                  BorderSide(color: WynColors.sapphireRing),
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundImage: MemoryImage(_pickedImageBytes!),
                              ),
                            )
                          : AvatarCircle(
                              imageUrl: widget.profile.avatarUrl,
                              fallbackText: widget.profile.username,
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
                          child: const Icon(
                            Icons.camera_alt,
                            size: 14,
                            color: WynColors.paper,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: WynSpacing.space4),
                padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space5),
                decoration: BoxDecoration(
                  border: Border.all(color: WynColors.hairline),
                  borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
                ),
                child: Column(
                  children: [
                    LabeledField(
                      key: const Key('username_field'),
                      label: 'ชื่อผู้ใช้',
                      controller: _usernameController,
                      maxLength: _usernameMaxLength,
                      helper: 'ใช้ตัวอักษร a-z, 0-9 และ _ เท่านั้น (3-20 ตัวอักษร)',
                      prefix: '@',
                      enabled: !_isSaving,
                      errorText: switch (_usernameStatus) {
                        _UsernameStatus.taken => 'ชื่อผู้ใช้นี้ถูกใช้แล้ว',
                        _UsernameStatus.invalid => 'รูปแบบไม่ถูกต้อง',
                        _ => null,
                      },
                      suffix: switch (_usernameStatus) {
                        _UsernameStatus.checking => const Padding(
                            padding: EdgeInsets.only(left: WynSpacing.space2),
                            child: SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        _UsernameStatus.available => const Padding(
                            padding: EdgeInsets.only(left: WynSpacing.space2),
                            child: Icon(Icons.check_circle,
                                size: 18, color: WynColors.sapphire),
                          ),
                        _ => null,
                      },
                      onChanged: _onUsernameChanged,
                    ),
                    const Divider(height: 1, color: WynColors.hairline),
                    LabeledField(
                      key: const Key('display_name_field'),
                      label: 'ชื่อแสดง',
                      controller: _displayNameController,
                      maxLength: _displayNameMaxLength,
                      helper: '1-50 ตัวอักษร',
                      enabled: !_isSaving,
                      onChanged: (_) => setState(() {}),
                    ),
                    const Divider(height: 1, color: WynColors.hairline),
                    LabeledField(
                      key: const Key('bio_field'),
                      label: 'Bio',
                      controller: _bioController,
                      maxLength: _bioMaxLength,
                      helper: 'คำอธิบายสั้น ๆ เกี่ยวกับตัวคุณ',
                      multiline: true,
                      enabled: !_isSaving,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: WynSpacing.space4),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: WynColors.errorLight),
                ),
              ],
              const SizedBox(height: WynSpacing.space6),
              FilledButton(
                style: FilledButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                      vertical: WynSpacing.space3 + 2),
                  backgroundColor: WynColors.sapphire,
                  foregroundColor: WynColors.paper,
                  disabledBackgroundColor: WynColors.hairline,
                  disabledForegroundColor: WynColors.mutedNeutral,
                  textStyle: _textStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onPressed: _canSave ? _save : null,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: WynColors.paper),
                      )
                    : const Text('บันทึก'),
              ),
              const SizedBox(height: WynSpacing.space8),
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
}) =>
    TextStyle(fontSize: fontSize, fontWeight: fontWeight, color: color);

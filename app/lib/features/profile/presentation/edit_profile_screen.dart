import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/data/auth_repository.dart';
import '../data/profile.dart';
import '../data/profile_repository.dart';
import 'widgets/profile_cover_avatar.dart';
import '../../../core/design/wyn_spacing.dart';

enum _UsernameStatus { idle, checking, available, taken, invalid }

/// Screen 2 — Edit Profile.
/// See .wyn/docs/design/wyn-003-user-profile.md,
/// .wyn/docs/design/wyn-024-profile-identity-fields.md (Cover/Website/
/// Username edit).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.profileRepository,
    required this.authRepository,
    required this.profile,
  });

  final ProfileRepository profileRepository;

  /// Reused directly from onboarding (WYN-002) for the Username field's
  /// availability check/save -- see .wyn/docs/design/
  /// wyn-024-profile-identity-fields.md, R3.
  final AuthRepository authRepository;
  final Profile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _bioMaxLength = 160;
  static const _websiteMaxLength = 200;

  // Mirrors username_setup_screen.dart's own regex exactly -- WYN-024's
  // design spec requires the same pattern, not a re-derived one.
  final _usernameRegExp = RegExp(r'^[a-z0-9_]{3,20}$');

  // Deliberately lenient -- accepts a domain with or without an
  // `http(s)://` scheme, an optional port, and an optional path/query.
  // Per the Product task: "ไม่ต้องเข้มงวดเกินไป".
  final _websiteRegExp =
      RegExp(r'^(https?:\/\/)?([\w-]+\.)+[a-zA-Z]{2,}(:\d+)?(\/\S*)?$');

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _websiteController;

  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;
  Uint8List? _pickedCoverBytes;
  String? _pickedCoverExtension;

  // Starts as `available` (not `idle`) -- the field is pre-filled with the
  // user's own current, already-valid username, so there's nothing to
  // block "บันทึก" on until they actually change it. See the design
  // spec's R3 States section.
  _UsernameStatus _usernameStatus = _UsernameStatus.available;
  Timer? _usernameDebounce;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.profile.displayName ?? '');
    _usernameController = TextEditingController(text: widget.profile.username);
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _websiteController = TextEditingController(text: widget.profile.website ?? '');
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  // `AuthRepository.isUsernameAvailable` has no self-exclusion built in
  // (see the design spec's R3 "จุดที่ต้องระวังเป็นพิเศษ" section) -- a
  // debounced check against the profile's own unedited username would
  // otherwise always report "ถูกใช้แล้ว". Short-circuiting here (instead
  // of touching AuthRepository, which the Product task says to reuse
  // as-is) is what fixes that without a network round-trip at all for the
  // common case of "didn't touch this field".
  void _onUsernameChanged(String value) {
    _usernameDebounce?.cancel();

    if (value == widget.profile.username) {
      setState(() => _usernameStatus = _UsernameStatus.available);
      return;
    }

    if (!_usernameRegExp.hasMatch(value)) {
      setState(() => _usernameStatus = _UsernameStatus.invalid);
      return;
    }

    setState(() => _usernameStatus = _UsernameStatus.checking);
    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      final available = await widget.authRepository.isUsernameAvailable(value);
      if (!mounted) return;
      setState(() {
        _usernameStatus =
            available ? _UsernameStatus.available : _UsernameStatus.taken;
      });
    });
  }

  String? _validateUsername(String? value) {
    switch (_usernameStatus) {
      case _UsernameStatus.taken:
        return 'ชื่อผู้ใช้นี้ถูกใช้แล้ว';
      case _UsernameStatus.invalid:
        return 'รูปแบบไม่ถูกต้อง';
      case _UsernameStatus.idle:
      case _UsernameStatus.checking:
      case _UsernameStatus.available:
        return null;
    }
  }

  String? _validateWebsite(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (!_websiteRegExp.hasMatch(value.trim())) {
      return 'ลิงก์เว็บไซต์รูปแบบไม่ถูกต้อง';
    }
    return null;
  }

  /// The website field's raw text, normalized to always carry a scheme
  /// (empty stays empty -- [ProfileRepository.updateProfile] turns that
  /// into `null`). Done once here, at save time, so View Profile never
  /// has to guess/re-add a scheme when rendering. See the design spec's
  /// R2 Interactions section.
  String _normalizedWebsite() {
    final raw = _websiteController.text.trim();
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://$raw';
  }

  Future<void> _pickImage(ImageSource source, {required bool isCover}) async {
    // Resized/compressed client-side per WYN-003's Risks (upload speed,
    // storage footprint) -- not uploaded yet, just previewed locally
    // until "บันทึก" is pressed. Cover uses the wider 16:9-ish bounds
    // EditClubInfoScreen's own cover picker uses (WYN-014) -- a cover is a
    // landscape image, not a square like the avatar.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: isCover ? 1600 : 1024,
      maxHeight: isCover ? 900 : 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extension = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';

    setState(() {
      if (isCover) {
        _pickedCoverBytes = bytes;
        _pickedCoverExtension = extension;
      } else {
        _pickedImageBytes = bytes;
        _pickedImageExtension = extension;
      }
    });
  }

  Future<void> _showImageSourceSheet({required bool isCover}) {
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
                _pickImage(ImageSource.camera, isCover: isCover);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากคลังภาพ'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.gallery, isCover: isCover);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final newUsername = _usernameController.text.trim();
    final usernameChanged = newUsername != widget.profile.username;

    try {
      // Username first, before any other write -- if it's taken (a race
      // with someone else grabbing it between this screen loading and
      // "บันทึก" being pressed), nothing else must have been written yet,
      // so the user isn't left in a half-saved state. See the design
      // spec's R3 "ลำดับการบันทึก" section.
      if (usernameChanged) {
        try {
          await widget.authRepository.setUsername(widget.profile.id, newUsername);
        } on UsernameTakenException {
          if (!mounted) return;
          setState(() {
            _usernameStatus = _UsernameStatus.taken;
            _isSaving = false;
          });
          return;
        }
      }

      var avatarUrl = widget.profile.avatarUrl;
      if (_pickedImageBytes != null) {
        avatarUrl = await widget.profileRepository.uploadAvatar(
          userId: widget.profile.id,
          bytes: _pickedImageBytes!,
          fileExtension: _pickedImageExtension ?? 'jpg',
        );
      }

      var coverUrl = widget.profile.coverUrl;
      if (_pickedCoverBytes != null) {
        coverUrl = await widget.profileRepository.uploadCover(
          userId: widget.profile.id,
          bytes: _pickedCoverBytes!,
          fileExtension: _pickedCoverExtension ?? 'jpg',
        );
      }

      final displayName = _displayNameController.text.trim();
      final bio = _bioController.text.trim();
      final normalizedWebsite = _normalizedWebsite();

      await widget.profileRepository.updateProfile(
        userId: widget.profile.id,
        displayName: displayName,
        bio: bio,
        website: normalizedWebsite,
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        Profile(
          id: widget.profile.id,
          username: usernameChanged ? newUsername : widget.profile.username,
          displayName: displayName,
          bio: bio,
          avatarUrl: avatarUrl,
          coverUrl: coverUrl,
          website: normalizedWebsite.isEmpty ? null : normalizedWebsite,
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
          padding: const EdgeInsets.all(WynSpacing.space6),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileCoverAvatar(
                  coverUrl: widget.profile.coverUrl,
                  coverBytes: _pickedCoverBytes,
                  avatarUrl: widget.profile.avatarUrl,
                  avatarBytes: _pickedImageBytes,
                  fallbackText: widget.profile.username,
                  onTapCover:
                      _isSaving ? null : () => _showImageSourceSheet(isCover: true),
                  onTapAvatar:
                      _isSaving ? null : () => _showImageSourceSheet(isCover: false),
                ),
                const SizedBox(height: WynSpacing.space6),
                TextFormField(
                  controller: _displayNameController,
                  maxLength: 50,
                  enabled: !_isSaving,
                  decoration: const InputDecoration(
                    labelText: 'ชื่อแสดง',
                    helperText: '1-50 ตัวอักษร',
                  ),
                ),
                TextFormField(
                  controller: _usernameController,
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
                  validator: _validateUsername,
                ),
                TextFormField(
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
                TextFormField(
                  controller: _websiteController,
                  maxLength: _websiteMaxLength,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.link),
                    labelText: 'เว็บไซต์',
                    helperText: 'ลิงก์เว็บไซต์หรือโซเชียลของคุณ (ไม่บังคับ)',
                  ),
                  validator: _validateWebsite,
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
      ),
    );
  }
}

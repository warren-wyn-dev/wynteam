import 'package:wyn/core/typography/browser_system_text.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile.dart';
import '../data/profile_repository.dart';
import 'profile_photo_crop_screen.dart';
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
  static const _bioMaxLength = 150;
  static const _displayNameMaxLength = 50;
  static const _usernameMaxLength = 20;
  static final _usernameRegExp = RegExp(r'^[a-z0-9_]{3,20}$');

  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _usernameController;
  late final TextEditingController _instagramController;
  late final TextEditingController _twitterController;
  late final TextEditingController _youtubeController;

  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;
  Uint8List? _pickedCoverBytes;
  String? _pickedCoverExtension;

  _UsernameStatus _usernameStatus = _UsernameStatus.unchanged;
  Timer? _usernameDebounce;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController(
      text: widget.profile.displayName ?? '',
    );
    _bioController = TextEditingController(text: widget.profile.bio ?? '');
    _usernameController = TextEditingController(text: widget.profile.username);
    _instagramController = TextEditingController(
      text: widget.profile.socialLinks['instagram'] ?? '',
    );
    _twitterController = TextEditingController(
      text: widget.profile.socialLinks['twitter'] ?? '',
    );
    _youtubeController = TextEditingController(
      text: widget.profile.socialLinks['youtube'] ?? '',
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    _youtubeController.dispose();
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
      _instagramController.text !=
          (widget.profile.socialLinks['instagram'] ?? '') ||
      _twitterController.text !=
          (widget.profile.socialLinks['twitter'] ?? '') ||
      _youtubeController.text !=
          (widget.profile.socialLinks['youtube'] ?? '') ||
      _pickedImageBytes != null ||
      _pickedCoverBytes != null;

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
    if (!mounted) return;

    // WYN-104: crop happens here, before this screen ever shows the
    // picked image as a preview -- see ProfilePhotoCropScreen's own doc
    // comment. Cancelling the crop screen (pops null) leaves this
    // screen's avatar exactly as it was, as if nothing had been picked
    // at all (Product spec Edge Case 1).
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ProfilePhotoCropScreen(imageBytes: bytes),
      ),
    );
    if (cropped == null || !mounted) return;

    setState(() {
      _pickedImageBytes = cropped;
      // cropToCircleSquare always encodes PNG (profile_photo_crop.dart) --
      // the originally-picked file's own extension no longer applies to
      // what's actually being uploaded.
      _pickedImageExtension = 'png';
    });
  }

  Future<void> _pickCoverImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1800,
      maxHeight: 1000,
      imageQuality: 88,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
    setState(() {
      _pickedCoverBytes = bytes;
      _pickedCoverExtension = ext == 'png' ? 'png' : 'jpg';
    });
  }

  Future<void> _showCoverImageSourceSheet() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const BrowserSystemText('ถ่ายภาพหน้าปก'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickCoverImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const BrowserSystemText('เลือกภาพหน้าปกจากคลังภาพ'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickCoverImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImageSourceSheet() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const BrowserSystemText('ถ่ายรูปใหม่'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const BrowserSystemText('เลือกจากคลังภาพ'),
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

  Future<void> _editSocialLink({
    required String label,
    required TextEditingController controller,
  }) async {
    final editor = TextEditingController(text: controller.text);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: WynColors.paper,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: BrowserSystemText(
          label,
          style: _textStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: BrowserSystemTextField(
          controller: editor,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hint: BrowserSystemText('https://'),
            filled: true,
            fillColor: WynColors.surfaceTint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const BrowserSystemText('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: WynColors.ink,
              foregroundColor: WynColors.paper,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(editor.text),
            child: const BrowserSystemText('บันทึก'),
          ),
        ],
      ),
    );
    editor.dispose();
    if (result == null || !mounted) return;
    setState(() => controller.text = result.trim());
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
      final username = _usernameController.text.trim();
      final socialLinks = <String, String>{
        if (_instagramController.text.trim().isNotEmpty)
          'instagram': _instagramController.text.trim(),
        if (_twitterController.text.trim().isNotEmpty)
          'twitter': _twitterController.text.trim(),
        if (_youtubeController.text.trim().isNotEmpty)
          'youtube': _youtubeController.text.trim(),
      };

      await widget.profileRepository.updateProfile(
        userId: widget.profile.id,
        displayName: displayName,
        bio: bio,
        socialLinks: socialLinks,
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
          coverUrl: coverUrl,
          socialLinks: socialLinks,
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
        surfaceTintColor: WynColors.paper,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 64,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 26, color: WynColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: BrowserSystemText(
          'แก้ไขโปรไฟล์',
          style: WynTypography.screenTitle(fontSize: 17, color: WynColors.ink),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(72, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  backgroundColor: WynColors.ink,
                  foregroundColor: WynColors.paper,
                  disabledBackgroundColor: WynColors.hairline,
                  disabledForegroundColor: WynColors.mutedNeutral,
                  shape: const StadiumBorder(),
                  textStyle: _textStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: _canSave ? _save : null,
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: WynColors.paper,
                        ),
                      )
                    : const BrowserSystemText('บันทึก'),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                key: const Key('cover_edit_button'),
                onTap: _isSaving ? null : _showCoverImageSourceSheet,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 158,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_pickedCoverBytes != null)
                          Image.memory(_pickedCoverBytes!, fit: BoxFit.cover)
                        else if (widget.profile.coverUrl != null &&
                            widget.profile.coverUrl!.isNotEmpty)
                          Image.network(
                            widget.profile.coverUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: WynColors.surfaceTint),
                          )
                        else
                          const ColoredBox(color: WynColors.surfaceTint),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xE612120F),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.photo_camera_outlined,
                                    size: 16,
                                    color: WynColors.paper,
                                  ),
                                  SizedBox(width: 6),
                                  BrowserSystemText(
                                    'เปลี่ยนรูปปก',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: WynColors.paper,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      key: const Key('avatar_edit_button'),
                      onTap: _isSaving ? null : _showImageSourceSheet,
                      child: Stack(
                        children: [
                          _pickedImageBytes != null
                              ? Container(
                                  width: 100,
                                  height: 100,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.fromBorderSide(
                                      BorderSide(color: WynColors.hairline),
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 47,
                                    backgroundImage: MemoryImage(
                                      _pickedImageBytes!,
                                    ),
                                  ),
                                )
                              : AvatarCircle(
                                  imageUrl: widget.profile.avatarUrl,
                                  fallbackText: widget.profile.username,
                                  radius: 47,
                                ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 31,
                              height: 31,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: WynColors.ink,
                                border: Border.fromBorderSide(
                                  BorderSide(color: WynColors.paper, width: 2),
                                ),
                              ),
                              child: const Icon(
                                Icons.photo_camera_outlined,
                                size: 15,
                                color: WynColors.paper,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: _isSaving ? null : _showImageSourceSheet,
                      style: TextButton.styleFrom(
                        foregroundColor: WynColors.ink,
                        textStyle: _textStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const BrowserSystemText('เปลี่ยนรูปโปรไฟล์'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              BrowserSystemText(
                'ข้อมูลโปรไฟล์',
                style: _textStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                decoration: BoxDecoration(
                  border: Border.all(color: WynColors.hairline),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    LabeledField(
                      key: const Key('display_name_field'),
                      label: 'ชื่อที่แสดง',
                      controller: _displayNameController,
                      maxLength: _displayNameMaxLength,
                      helper: '1-50 ตัวอักษร',
                      enabled: !_isSaving,
                      onChanged: (_) => setState(() {}),
                    ),
                    LabeledField(
                      key: const Key('username_field'),
                      label: 'ชื่อผู้ใช้',
                      controller: _usernameController,
                      maxLength: _usernameMaxLength,
                      helper:
                          'ใช้ตัวอักษร a-z, 0-9 และ _ เท่านั้น (3-20 ตัวอักษร)',
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
                            child: Icon(
                              Icons.check_circle,
                              size: 18,
                              color: WynColors.ink,
                            ),
                          ),
                        _ => null,
                      },
                      onChanged: _onUsernameChanged,
                    ),
                    LabeledField(
                      key: const Key('bio_field'),
                      label: 'แนะนำตัว',
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
              const SizedBox(height: 24),
              BrowserSystemText(
                'ลิงก์',
                style: _textStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Container(
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: WynColors.hairline),
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    _SocialLinkRow(
                      label: 'Instagram',
                      value: _instagramController.text,
                      onTap: _isSaving
                          ? null
                          : () => _editSocialLink(
                                label: 'Instagram',
                                controller: _instagramController,
                              ),
                    ),
                    const Divider(height: 1, color: WynColors.hairline),
                    _SocialLinkRow(
                      label: 'Twitter (X)',
                      value: _twitterController.text,
                      onTap: _isSaving
                          ? null
                          : () => _editSocialLink(
                                label: 'Twitter (X)',
                                controller: _twitterController,
                              ),
                    ),
                    const Divider(height: 1, color: WynColors.hairline),
                    _SocialLinkRow(
                      label: 'YouTube',
                      value: _youtubeController.text,
                      onTap: _isSaving
                          ? null
                          : () => _editSocialLink(
                                label: 'YouTube',
                                controller: _youtubeController,
                              ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                BrowserSystemText(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: WynColors.errorLight),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialLinkRow extends StatelessWidget {
  const _SocialLinkRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trimmed = value.trim();
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: BrowserSystemText(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: WynColors.ink,
                  ),
                ),
              ),
              Flexible(
                child: BrowserSystemText(
                  trimmed.isEmpty ? 'เพิ่มลิงก์' : trimmed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    color: trimmed.isEmpty ? WynColors.graphite : WynColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: WynColors.graphite,
              ),
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

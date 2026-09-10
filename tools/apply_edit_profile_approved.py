from pathlib import Path


def read(path: str) -> str:
    return Path(path).read_text()


def write(path: str, text: str) -> None:
    Path(path).write_text(text)


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{path}: expected exactly one match, found {count}: {old[:120]!r}")
    write(path, text.replace(old, new, 1))


# ---------------------------------------------------------------------------
# Profile model: persist the approved social-link rows without changing the
# existing public Profile layout. The edit screen owns the UI; other profile
# surfaces simply keep the data available for future use.
# ---------------------------------------------------------------------------
profile_path = "app/lib/features/profile/data/profile.dart"
replace_once(
    profile_path,
    "    this.coverUrl,\n    this.platformRole = PlatformRole.user,\n",
    "    this.coverUrl,\n    this.socialLinks = const {},\n    this.platformRole = PlatformRole.user,\n",
)
replace_once(
    profile_path,
    "        coverUrl: map['cover_url'] as String?,\n        platformRole: platformRoleFromString(map['platform_role'] as String?),\n",
    "        coverUrl: map['cover_url'] as String?,\n        socialLinks: _parseSocialLinks(map['social_links']),\n        platformRole: platformRoleFromString(map['platform_role'] as String?),\n",
)
replace_once(
    profile_path,
    "  final String? coverUrl;\n  final PlatformRole platformRole;\n",
    "  final String? coverUrl;\n  final Map<String, String> socialLinks;\n  final PlatformRole platformRole;\n",
)
replace_once(
    profile_path,
    "/// A WYN user profile row. See supabase/schema.sql (WYN-003 section,\n",
    "Map<String, String> _parseSocialLinks(Object? value) {\n"
    "  if (value is! Map) return const {};\n"
    "  final result = <String, String>{};\n"
    "  for (final entry in value.entries) {\n"
    "    final key = entry.key.toString();\n"
    "    final link = entry.value?.toString().trim() ?? '';\n"
    "    if (key.isNotEmpty && link.isNotEmpty) result[key] = link;\n"
    "  }\n"
    "  return result;\n"
    "}\n\n"
    "/// A WYN user profile row. See supabase/schema.sql (WYN-003 section,\n",
)

# ---------------------------------------------------------------------------
# Repository: load/save social_links with the rest of the editable profile.
# Existing callers remain source-compatible because the new argument is
# optional.
# ---------------------------------------------------------------------------
repo_path = "app/lib/features/profile/data/profile_repository.dart"
replace_once(
    repo_path,
    "id, username, display_name, bio, avatar_url, cover_url, platform_role, is_private, is_verified, dm_permission, mention_permission, comment_permission, likes_visibility",
    "id, username, display_name, bio, avatar_url, cover_url, social_links, platform_role, is_private, is_verified, dm_permission, mention_permission, comment_permission, likes_visibility",
)
replace_once(
    repo_path,
    "  Future<void> updateProfile({\n    required String userId,\n    required String displayName,\n    required String bio,\n  }) {\n",
    "  Future<void> updateProfile({\n    required String userId,\n    required String displayName,\n    required String bio,\n    Map<String, String>? socialLinks,\n  }) {\n",
)
replace_once(
    repo_path,
    "      'display_name': normalizeOptionalText(displayName),\n      'bio': bio,\n    }).eq('id', userId);\n",
    "      'display_name': normalizeOptionalText(displayName),\n      'bio': bio,\n      if (socialLinks != null) 'social_links': socialLinks,\n    }).eq('id', userId);\n",
)

# ---------------------------------------------------------------------------
# Edit Profile state + persistence.
# ---------------------------------------------------------------------------
edit_path = "app/lib/features/profile/presentation/edit_profile_screen.dart"
replace_once(edit_path, "  static const _bioMaxLength = 160;\n", "  static const _bioMaxLength = 150;\n")
replace_once(
    edit_path,
    "  late final TextEditingController _usernameController;\n\n  Uint8List? _pickedImageBytes;\n",
    "  late final TextEditingController _usernameController;\n"
    "  late final TextEditingController _instagramController;\n"
    "  late final TextEditingController _twitterController;\n"
    "  late final TextEditingController _youtubeController;\n\n"
    "  Uint8List? _pickedImageBytes;\n",
)
replace_once(
    edit_path,
    "    _usernameController =\n        TextEditingController(text: widget.profile.username);\n  }\n",
    "    _usernameController =\n"
    "        TextEditingController(text: widget.profile.username);\n"
    "    _instagramController = TextEditingController(\n"
    "      text: widget.profile.socialLinks['instagram'] ?? '',\n"
    "    );\n"
    "    _twitterController = TextEditingController(\n"
    "      text: widget.profile.socialLinks['twitter'] ?? '',\n"
    "    );\n"
    "    _youtubeController = TextEditingController(\n"
    "      text: widget.profile.socialLinks['youtube'] ?? '',\n"
    "    );\n"
    "  }\n",
)
replace_once(
    edit_path,
    "    _usernameController.dispose();\n    _usernameDebounce?.cancel();\n",
    "    _usernameController.dispose();\n"
    "    _instagramController.dispose();\n"
    "    _twitterController.dispose();\n"
    "    _youtubeController.dispose();\n"
    "    _usernameDebounce?.cancel();\n",
)
replace_once(
    edit_path,
    "      _bioController.text != (widget.profile.bio ?? '') ||\n      _pickedImageBytes != null ||\n",
    "      _bioController.text != (widget.profile.bio ?? '') ||\n"
    "      _instagramController.text !=\n"
    "          (widget.profile.socialLinks['instagram'] ?? '') ||\n"
    "      _twitterController.text !=\n"
    "          (widget.profile.socialLinks['twitter'] ?? '') ||\n"
    "      _youtubeController.text !=\n"
    "          (widget.profile.socialLinks['youtube'] ?? '') ||\n"
    "      _pickedImageBytes != null ||\n",
)

link_editor = r'''  Future<void> _editSocialLink({
    required String label,
    required TextEditingController controller,
  }) async {
    final editor = TextEditingController(text: controller.text);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: WynColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          label,
          style: _textStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: editor,
          autofocus: true,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'https://',
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
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: WynColors.ink,
              foregroundColor: WynColors.paper,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(editor.text),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
    editor.dispose();
    if (result == null || !mounted) return;
    setState(() => controller.text = result.trim());
  }

'''
replace_once(edit_path, "  Future<void> _save() async {\n", link_editor + "  Future<void> _save() async {\n")
replace_once(
    edit_path,
    "      final username = _usernameController.text.trim();\n\n      await widget.profileRepository.updateProfile(\n        userId: widget.profile.id,\n        displayName: displayName,\n        bio: bio,\n      );\n",
    "      final username = _usernameController.text.trim();\n"
    "      final socialLinks = <String, String>{\n"
    "        if (_instagramController.text.trim().isNotEmpty)\n"
    "          'instagram': _instagramController.text.trim(),\n"
    "        if (_twitterController.text.trim().isNotEmpty)\n"
    "          'twitter': _twitterController.text.trim(),\n"
    "        if (_youtubeController.text.trim().isNotEmpty)\n"
    "          'youtube': _youtubeController.text.trim(),\n"
    "      };\n\n"
    "      await widget.profileRepository.updateProfile(\n"
    "        userId: widget.profile.id,\n"
    "        displayName: displayName,\n"
    "        bio: bio,\n"
    "        socialLinks: socialLinks,\n"
    "      );\n",
)
replace_once(
    edit_path,
    "          coverUrl: coverUrl,\n        ),\n",
    "          coverUrl: coverUrl,\n          socialLinks: socialLinks,\n        ),\n",
)

text = read(edit_path)
start = text.find("  @override\n  Widget build(BuildContext context) {")
end = text.find("TextStyle _textStyle", start)
if start < 0 or end < 0:
    raise RuntimeError("edit_profile_screen.dart: build replacement anchors missing")
new_build = r'''  @override
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
        title: Text(
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
                    : const Text('บันทึก'),
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
                                  Text(
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
                                    backgroundImage:
                                        MemoryImage(_pickedImageBytes!),
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
                      child: const Text('เปลี่ยนรูปโปรไฟล์'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
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
              Text(
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
                Text(
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
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: WynColors.ink,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  trimmed.isEmpty ? 'เพิ่มลิงก์' : trimmed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13,
                    color: trimmed.isEmpty
                        ? WynColors.graphite
                        : WynColors.ink,
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

'''
write(edit_path, text[:start] + new_build + text[end:])

# ---------------------------------------------------------------------------
# Recording repo keeps EditProfile widget tests network-free.
# ---------------------------------------------------------------------------
recording_path = "app/test/support/recording_profile_repository.dart"
replace_once(
    recording_path,
    "  Future<void> updateProfile({\n    required String userId,\n    required String displayName,\n    required String bio,\n  }) async {\n",
    "  Future<void> updateProfile({\n    required String userId,\n    required String displayName,\n    required String bio,\n    Map<String, String>? socialLinks,\n  }) async {\n",
)

# Approved mockup uses a 150-character self-description counter.
test_path = "app/test/edit_profile_screen_test.dart"
test = read(test_path)
test = test.replace("/160", "/150")
write(test_path, test)

# ---------------------------------------------------------------------------
# Executable schema baseline + migration source-of-truth.
# ---------------------------------------------------------------------------
schema_path = "supabase/schema.sql"
replace_once(
    schema_path,
    "  add column if not exists avatar_url text,\n  add column if not exists cover_url text;\n",
    "  add column if not exists avatar_url text,\n"
    "  add column if not exists cover_url text,\n"
    "  add column if not exists social_links jsonb not null default '{}'::jsonb;\n",
)

Path("supabase/migrations_edit_profile_social_links.sql").write_text(
    """-- Founder-approved Edit Profile: persist Instagram / Twitter (X) / YouTube links.\n"
    "-- Additive only; the existing profile page layout is intentionally unchanged.\n\n"
    "begin;\n\n"
    "alter table public.profiles\n"
    "  add column if not exists social_links jsonb not null default '{}'::jsonb;\n\n"
    "commit;\n"
    """
)

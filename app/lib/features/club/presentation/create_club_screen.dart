import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/club.dart';
import '../data/club_post_repository.dart';
import '../data/club_repository.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../moderation/data/appeal_status.dart';
import '../../moderation/data/moderation_repository.dart';
import '../../moderation/presentation/appeal_form_screen.dart';
import 'club_page.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../core/widgets/restriction_banner.dart';

/// Screen 2 — Create Club. Reuses Edit Profile's form/upload pattern
/// (WYN-003) for Name/Description/Cover per the Design spec (icon
/// upload removed per Founder decision, 2026-08-24 -- cover image
/// alone is enough; see .wyn/company/DECISIONS.md).
/// See .wyn/docs/design/wyn-014-club-core.md, Screen 2.
class CreateClubScreen extends StatefulWidget {
  const CreateClubScreen({
    super.key,
    required this.clubRepository,
    required this.clubPostRepository,
    this.moderationRepository,
    this.appealRepository,
  });

  final ClubRepository clubRepository;
  final ClubPostRepository clubPostRepository;

  // Optional -- see DropDetailScreen.moderationRepository's identical
  // doc comment. WYN-029.
  final ModerationRepository? moderationRepository;

  // Same shape again -- WYN-030's appeal entry point on the Restrict banner.
  final AppealRepository? appealRepository;

  @override
  State<CreateClubScreen> createState() => _CreateClubScreenState();
}

class _CreateClubScreenState extends State<CreateClubScreen> {
  static const _nameMaxLength = 50;
  static const _descriptionMaxLength = 500;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _category;
  ClubPrivacy? _privacy;

  Uint8List? _coverBytes;
  String? _coverExtension;

  bool _isCreating = false;
  String? _errorMessage;

  late final ModerationRepository _moderationRepository =
      widget.moderationRepository ?? ModerationRepository(Supabase.instance.client);
  late final AppealRepository _appealRepository =
      widget.appealRepository ?? AppealRepository(Supabase.instance.client);

  // WYN-029 (Restrict) -- see CreateDropScreen's identical fields/doc
  // comment for why this is loaded once, not re-polled.
  String? _restrictReason;
  DateTime? _restrictExpiresAt;
  String? _restrictActionId;
  AppealStatus _restrictAppealStatus = AppealStatus.none;
  bool get _isRestricted => _restrictExpiresAt != null;

  bool get _canCreate =>
      !_isCreating &&
      _nameController.text.trim().isNotEmpty &&
      _privacy != null &&
      !_isRestricted;

  @override
  void initState() {
    super.initState();
    _loadModerationStatus();
  }

  Future<void> _loadModerationStatus() async {
    try {
      final status = await _moderationRepository.fetchMyStatus();
      if (!mounted) return;
      if (status.isRestricted) {
        setState(() {
          _restrictReason = status.restrictReason;
          _restrictExpiresAt = status.restrictExpiresAt;
          _restrictActionId = status.restrictActionId;
          _restrictAppealStatus = status.restrictAppealStatus;
        });
      }
    } catch (_) {
      // Silent -- see CreateDropScreen's identical method.
    }
  }

  // WYN-030 -- see CreateDropScreen's identical method.
  Future<void> _openAppeal() async {
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AppealFormScreen(
          appealRepository: _appealRepository,
          actionId: _restrictActionId!,
          actionLabel: 'จำกัดสิทธิ์ (Restrict)',
        ),
      ),
    );
    if (submitted == true) _loadModerationStatus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extension = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';

    if (!mounted) return;
    setState(() {
      _coverBytes = bytes;
      _coverExtension = extension;
    });
  }

  Future<void> _create() async {
    final privacy = _privacy;
    if (privacy == null) return;

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final club = await widget.clubRepository.createClub(
        name: _nameController.text,
        description: _descriptionController.text,
        category: _category,
        privacy: privacy,
        coverBytes: _coverBytes,
        coverExtension: _coverExtension,
      );
      if (!mounted) return;
      // The creator is the Owner automatically (clubs_add_owner_membership
      // trigger) -- open the new Club's page immediately, replacing this
      // screen so "back" doesn't return to an already-submitted form.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ClubPage(
            clubRepository: widget.clubRepository,
            clubPostRepository: widget.clubPostRepository,
            clubId: club.id,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'สร้าง Club ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  Future<void> _pickCategory() async {
    if (_isCreating) return;
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            for (final category in clubCategories)
              ListTile(
                title: Text(category),
                trailing: category == _category
                    ? const Icon(Icons.check, color: WynColors.sapphire)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(category),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _category = selected);
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
          'สร้าง Club',
          style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: WynColors.hairline),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            WynSpacing.space6, WynSpacing.space5, WynSpacing.space6, WynSpacing.space6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isRestricted)
                RestrictionBanner(
                  reason: _restrictReason,
                  expiresAt: _restrictExpiresAt,
                  actionId: _restrictActionId,
                  appealStatus: _restrictAppealStatus,
                  onAppeal: _openAppeal,
                ),
              // 08-club.tsx: cover picker, name, description, category, and
              // privacy all sit inside one bordered card instead of loose
              // full-width sections -- the card is what gives this screen
              // its "contained, tidy" feel.
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: WynColors.hairline),
                  borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCoverPicker(),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LabeledField(
                            key: const Key('club_name_field'),
                            label: 'ชื่อ Club',
                            controller: _nameController,
                            maxLength: _nameMaxLength,
                            helper: '1-$_nameMaxLength ตัวอักษร',
                            enabled: !_isCreating,
                            alwaysShowHelper: true,
                            onChanged: (_) => setState(() {}),
                          ),
                          const Divider(height: 1, color: WynColors.hairline),
                          LabeledField(
                            key: const Key('club_description_field'),
                            label: 'คำอธิบาย',
                            controller: _descriptionController,
                            maxLength: _descriptionMaxLength,
                            helper: 'อธิบาย Club นี้สั้น ๆ (ไม่บังคับ)',
                            multiline: true,
                            enabled: !_isCreating,
                            alwaysShowHelper: true,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: WynColors.hairline),
                    // Not in 08-club.tsx's own mockup (it doesn't have a
                    // category field at all), but real, existing
                    // functionality -- kept in the same card, same
                    // label-above field language as the name/description
                    // fields above it.
                    InkWell(
                      onTap: _pickCategory,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          WynSpacing.space5, WynSpacing.space4, WynSpacing.space5, WynSpacing.space4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'หมวดหมู่',
                                    style: _textStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: WynColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: WynSpacing.space1),
                                  Text(
                                    _category ?? 'ไม่บังคับ',
                                    style: _textStyle(
                                      fontSize: 15,
                                      color: _category == null
                                          ? WynColors.faint
                                          : WynColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                size: 18, color: WynColors.faint),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: WynColors.hairline),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        WynSpacing.space5, WynSpacing.space4, WynSpacing.space5, WynSpacing.space4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ความเป็นส่วนตัว',
                            style: _textStyle(
                                fontSize: 13, fontWeight: FontWeight.w500, color: WynColors.ink),
                          ),
                          const SizedBox(height: WynSpacing.space3),
                          _buildPrivacyToggle(),
                          if (_privacy != null) ...[
                            const SizedBox(height: WynSpacing.space2),
                            Text(
                              _privacy == ClubPrivacy.public
                                  ? 'ทุกคนค้นหาและเข้าร่วมได้ทันที'
                                  : 'ต้องส่งคำขอ ผู้ดูแลต้องอนุมัติก่อน',
                              style: _textStyle(fontSize: 13, color: WynColors.graphite),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: WynSpacing.space6),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: WynColors.errorLight),
                ),
                const SizedBox(height: WynSpacing.space3),
              ],
              Semantics(
                label: _isRestricted ? 'สร้าง Club ปิดใช้งานเนื่องจากบัญชีถูกจำกัดการโพสต์ชั่วคราว' : null,
                excludeSemantics: _isRestricted,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: WynSpacing.space3 + 2),
                    backgroundColor: WynColors.sapphire,
                    foregroundColor: WynColors.paper,
                    disabledBackgroundColor: WynColors.hairline,
                    disabledForegroundColor: WynColors.mutedNeutral,
                    textStyle: _textStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  onPressed: _canCreate ? _create : null,
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: WynColors.paper),
                        )
                      : const Text('สร้าง Club'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 08-club.tsx's rounded pill privacy toggle -- a hairline-filled pill
  /// container with the active segment raised on a paper background,
  /// replacing the old `SegmentedButton`. `ClubPrivacy` stays 2 values
  /// (public/private), so this is still a 2-segment control, just
  /// restyled.
  Widget _buildPrivacyToggle() {
    Widget segment(ClubPrivacy value, String label) {
      final selected = _privacy == value;
      return Expanded(
        child: GestureDetector(
          onTap: _isCreating ? null : () => setState(() => _privacy = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2 + 2),
            decoration: BoxDecoration(
              color: selected ? WynColors.paper : Colors.transparent,
              borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: WynColors.ink.withValues(alpha: 0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: _textStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? WynColors.ink : WynColors.graphite,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: WynColors.hairline,
        borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
        border: Border.all(color: WynColors.hairline),
      ),
      child: Row(
        children: [
          segment(ClubPrivacy.public, 'สาธารณะ'),
          segment(ClubPrivacy.private, 'ส่วนตัว'),
        ],
      ),
    );
  }

  Widget _buildCoverPicker() {
    return GestureDetector(
      onTap: _isCreating ? null : _pickCover,
      child: Semantics(
        label: _coverBytes == null ? 'แตะเพื่อเลือกรูปปก' : 'รูปปกที่เลือก',
        button: true,
        child: _coverBytes != null
            ? SizedBox(
                height: 110,
                width: double.infinity,
                child: Image.memory(_coverBytes!, fit: BoxFit.cover),
              )
            : Container(
                height: 110,
                width: double.infinity,
                color: WynColors.hairline,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: WynColors.sapphireRing,
                        ),
                        child: const Icon(
                          Icons.image_outlined,
                          size: 16,
                          color: WynColors.sapphire,
                        ),
                      ),
                      const SizedBox(height: WynSpacing.space2),
                      Text(
                        'แตะเพื่อเลือกรูปปก',
                        style: _textStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: WynColors.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'แนะนำอัตราส่วน 16:9',
                        style: _textStyle(fontSize: 13, color: WynColors.faint),
                      ),
                    ],
                  ),
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

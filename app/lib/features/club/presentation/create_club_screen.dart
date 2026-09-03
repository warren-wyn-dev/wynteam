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
/// (WYN-003) for Name/Description/Image per the Design spec.
/// See .wyn/docs/design/wyn-014-club-core.md, Screen 2.
///
/// ## Beta4 §8.2 -- the order of the questions
///
/// §8.2 asks the flow to follow: ชื่อ Club → คำอธิบาย → เลือกรูป Club →
/// ตั้งค่า → ตรวจสอบข้อมูล → สร้าง Club. This screen used to open with
/// the image picker, before the name field: a 110px grey slab asking
/// for a picture of a thing that did not have a name yet. Nobody
/// chooses a Club's photo before deciding what the Club is. The card's
/// contents are now in §8.2's order, with the picker demoted from
/// full-bleed banner to a labelled row like every other optional field
/// beside it, and a review summary added above the button so the last
/// thing before "สร้าง Club" is what you are about to create.
///
/// Deliberately still **one screen**, not a 6-step wizard. §8.2's own
/// words are "จัด Flow ให้ใกล้เคียงแนวคิด" -- arrange the flow to
/// approximate it -- and a Club has exactly two required answers (name,
/// privacy). Paginating two required fields across six screens would
/// make a 30-second task feel like an application form, and it is the
/// kind of "Rewrite Architecture" §0 rules out. The order is what §8.2
/// is about, and the order is now right.
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

  // Beta4 §8.1: one image, not a cover *and* an icon.
  Uint8List? _imageBytes;
  String? _imageExtension;

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

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      // Beta4 §8.1: square bounds, not the old 1600x900. This is now
      // the Club's identity image -- it appears as a round avatar on
      // the Club page, in "Club ของฉัน" and in every mini card, and as
      // the page banner. A 16:9 source guaranteed that every circular
      // rendering cropped the sides off whatever the owner framed.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extension = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';

    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageExtension = extension;
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
        imageBytes: _imageBytes,
        imageExtension: _imageExtension,
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
                    // Beta4 §8.2, step 1-2: name, then description --
                    // first, where they belong. The image picker used to
                    // sit above these.
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
                    // Beta4 §8.2, step 3: the one Club image.
                    _buildImagePicker(),
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
              // Beta4 §8.2, step 5: "ตรวจสอบข้อมูล". A summary of what
              // is about to be created, immediately above the button
              // that creates it -- the fields are spread down a
              // scrolling card, so by the time the button is on screen
              // the name usually is not. Appears only once the two
              // required answers exist, so it is a confirmation rather
              // than a checklist of what is still missing (the button's
              // own disabled state already says that).
              if (_canCreate) ...[
                const SizedBox(height: WynSpacing.space5),
                _buildReviewSummary(),
              ],
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

  /// Beta4 §8.1/§8.2, step 3 -- "เลือกรูป Club 1 รูป".
  ///
  /// A labelled row with a square 56px thumbnail, not the 110px
  /// full-bleed grey banner this screen used to open with. Two reasons
  /// it changed shape, not just position:
  ///
  /// * It is no longer a *cover*. §8.1 makes this the Club's single
  ///   identity image, and the shape it is shown in most often is a
  ///   circle (the Club page header, "Club ของฉัน", every mini card).
  ///   A wide 16:9 preview promised a framing the product never uses.
  /// * As a banner it dominated the form -- the largest, most colourful
  ///   element on a screen whose only required answers are a name and a
  ///   privacy setting, for a field that is optional.
  ///
  /// Same row shape as "หมวดหมู่" directly below it, so the three
  /// optional settings read as one group.
  Widget _buildImagePicker() {
    final hasImage = _imageBytes != null;
    return Semantics(
      label: hasImage ? 'รูป Club ที่เลือก แตะเพื่อเปลี่ยน' : 'แตะเพื่อเลือกรูป Club',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        key: const Key('club_image_picker'),
        onTap: _isCreating ? null : _pickImage,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            WynSpacing.space5, WynSpacing.space4, WynSpacing.space5, WynSpacing.space4,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: hasImage
                      ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                      : Container(
                          color: WynColors.hairline,
                          child: const Icon(
                            Icons.image_outlined,
                            size: 20,
                            color: WynColors.sapphire,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: WynSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รูป Club',
                      style: _textStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: WynColors.ink,
                      ),
                    ),
                    const SizedBox(height: WynSpacing.space1),
                    Text(
                      hasImage ? 'เลือกรูปแล้ว — แตะเพื่อเปลี่ยน' : 'ไม่บังคับ',
                      style: _textStyle(
                        fontSize: 15,
                        color: hasImage ? WynColors.ink : WynColors.faint,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: WynColors.faint),
            ],
          ),
        ),
      ),
    );
  }

  /// Beta4 §8.2, step 5 -- "ตรวจสอบข้อมูล".
  ///
  /// Deliberately plain text on the page background rather than another
  /// bordered card: a second card would read as more form to fill in,
  /// when the point is that there is nothing left to fill in. Says only
  /// what a person can still get wrong -- the name they typed, whether
  /// the Club will be public, and whether it has a picture.
  Widget _buildReviewSummary() {
    final name = _nameController.text.trim();
    final isPublic = _privacy == ClubPrivacy.public;
    return Container(
      key: const Key('club_review_summary'),
      padding: const EdgeInsets.all(WynSpacing.space4),
      decoration: BoxDecoration(
        color: WynColors.hairline,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ตรวจสอบข้อมูล',
            style: _textStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: WynColors.graphite,
            ),
          ),
          const SizedBox(height: WynSpacing.space2),
          _ReviewLine(icon: Icons.groups_outlined, text: name),
          _ReviewLine(
            icon: isPublic ? Icons.public : Icons.lock_outline,
            text: isPublic
                ? 'สาธารณะ — ทุกคนค้นหาและเข้าร่วมได้ทันที'
                : 'ส่วนตัว — ต้องส่งคำขอ ผู้ดูแลต้องอนุมัติก่อน',
          ),
          if (_category != null)
            _ReviewLine(icon: Icons.sell_outlined, text: _category!),
          _ReviewLine(
            icon: _imageBytes != null
                ? Icons.image_outlined
                : Icons.hide_image_outlined,
            text: _imageBytes != null ? 'มีรูป Club' : 'ยังไม่ได้เลือกรูป Club',
          ),
        ],
      ),
    );
  }
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: WynColors.graphite),
          const SizedBox(width: WynSpacing.space2),
          Expanded(
            child: Text(
              text,
              style: _textStyle(fontSize: 13, color: WynColors.ink),
            ),
          ),
        ],
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

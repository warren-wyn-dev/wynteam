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
import '../../../core/design/wyn_spacing.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สร้าง Club')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WynSpacing.space4),
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
              _buildCoverPicker(),
              const SizedBox(height: WynSpacing.space4),
              TextField(
                controller: _nameController,
                maxLength: _nameMaxLength,
                enabled: !_isCreating,
                decoration: const InputDecoration(
                  labelText: 'ชื่อ Club',
                  helperText: '1-50 ตัวอักษร',
                ),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _descriptionController,
                maxLength: _descriptionMaxLength,
                maxLines: 4,
                enabled: !_isCreating,
                decoration: const InputDecoration(
                  labelText: 'คำอธิบาย',
                  helperText: 'อธิบาย Club นี้สั้น ๆ (ไม่บังคับ)',
                ),
              ),
              const SizedBox(height: WynSpacing.space2),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                items: clubCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: _isCreating
                    ? null
                    : (value) => setState(() => _category = value),
              ),
              const SizedBox(height: WynSpacing.space4),
              Text('ความเป็นส่วนตัว', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: WynSpacing.space2),
              SegmentedButton<ClubPrivacy>(
                segments: const [
                  ButtonSegment(value: ClubPrivacy.public, label: Text('สาธารณะ')),
                  ButtonSegment(value: ClubPrivacy.private, label: Text('ส่วนตัว')),
                ],
                selected: _privacy == null ? const {} : {_privacy!},
                emptySelectionAllowed: true,
                onSelectionChanged: _isCreating
                    ? null
                    : (selection) =>
                        setState(() => _privacy = selection.isEmpty ? null : selection.first),
              ),
              if (_privacy != null) ...[
                const SizedBox(height: WynSpacing.space1),
                Text(
                  _privacy == ClubPrivacy.public
                      ? 'ทุกคนค้นหาและเข้าร่วมได้ทันที'
                      : 'ต้องส่งคำขอ ผู้ดูแลต้องอนุมัติก่อน',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
              const SizedBox(height: WynSpacing.space4),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: WynSpacing.space3),
              ],
              Semantics(
                label: _isRestricted ? 'สร้าง Club ปิดใช้งานเนื่องจากบัญชีถูกจำกัดการโพสต์ชั่วคราว' : null,
                excludeSemantics: _isRestricted,
                child: FilledButton(
                  onPressed: _canCreate ? _create : null,
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
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

  Widget _buildCoverPicker() {
    return GestureDetector(
      onTap: _isCreating ? null : _pickCover,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Semantics(
          label: _coverBytes == null ? 'แตะเพื่อเลือกรูปปก' : 'รูปปกที่เลือก',
          button: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: _coverBytes == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 32),
                          SizedBox(height: WynSpacing.space1),
                          Text('แตะเพื่อเลือกรูปปก'),
                        ],
                      ),
                    )
                  : Image.memory(_coverBytes!, fit: BoxFit.cover),
            ),
          ),
        ),
      ),
    );
  }

}

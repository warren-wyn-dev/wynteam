import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/club.dart';
import '../data/club_repository.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/widgets/network_thumbnail.dart';

/// Owner/Admin "แก้ไขข้อมูล Club" -- reuses CreateClubScreen's form shape
/// for Name/Description/Cover/Category, pre-filled with the current
/// values (icon editing removed per Founder decision, 2026-08-24 -- see
/// .wyn/company/DECISIONS.md). Privacy is a separate More-menu action
/// (ClubPage), not part of this form, per the Design spec's Screen 3
/// menu breakdown.
class EditClubInfoScreen extends StatefulWidget {
  const EditClubInfoScreen({
    super.key,
    required this.clubRepository,
    required this.club,
  });

  final ClubRepository clubRepository;
  final Club club;

  @override
  State<EditClubInfoScreen> createState() => _EditClubInfoScreenState();
}

class _EditClubInfoScreenState extends State<EditClubInfoScreen> {
  static const _nameMaxLength = 50;
  static const _descriptionMaxLength = 500;

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String? _category;

  // Beta4 §8.1: one image per Club -- see [Club.identityImageUrl].
  Uint8List? _imageBytes;
  String? _imageExtension;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.club.name);
    _descriptionController = TextEditingController(text: widget.club.description ?? '');
    _category = widget.club.category;
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
      // Square bounds, matching CreateClubScreen's own picker -- see
      // its `_pickImage` for why the old 16:9 was wrong for an image
      // that is rendered as a circle on most surfaces.
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final extension =
        picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageExtension = extension;
    });
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_imageBytes != null && _imageExtension != null) {
        await widget.clubRepository.uploadClubIdentityImage(
          clubId: widget.club.id,
          bytes: _imageBytes!,
          fileExtension: _imageExtension!,
        );
      }
      await widget.clubRepository.updateClubInfo(
        clubId: widget.club.id,
        name: _nameController.text,
        description: _descriptionController.text,
        category: _category,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'บันทึกไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSave = !_isSaving && _nameController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('แก้ไขข้อมูล Club')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WynSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImagePicker(),
              const SizedBox(height: WynSpacing.space4),
              TextField(
                controller: _nameController,
                maxLength: _nameMaxLength,
                enabled: !_isSaving,
                decoration: const InputDecoration(labelText: 'ชื่อ Club'),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _descriptionController,
                maxLength: _descriptionMaxLength,
                maxLines: 4,
                enabled: !_isSaving,
                decoration: const InputDecoration(labelText: 'คำอธิบาย'),
              ),
              const SizedBox(height: WynSpacing.space2),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                items: clubCategories
                    .map((category) => DropdownMenuItem(value: category, child: Text(category)))
                    .toList(),
                onChanged: _isSaving ? null : (value) => setState(() => _category = value),
              ),
              const SizedBox(height: WynSpacing.space4),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: WynSpacing.space3),
              ],
              FilledButton(
                onPressed: canSave ? _save : null,
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

  /// Beta4 §8.1: the Club's one identity image, previewed square and
  /// centred at the size it is actually used -- not the old full-width
  /// 16:9 slab, which showed a framing no Club surface ever renders.
  ///
  /// Reads [Club.identityImageUrl], so a Club created before Beta4
  /// (whose picture lives in `cover_url`) still shows the image its
  /// owner chose rather than an empty "add a photo" box that would
  /// imply it had none.
  Widget _buildImagePicker() {
    final existingUrl = widget.club.identityImageUrl;
    return Center(
      child: Semantics(
        label: 'รูป Club แตะเพื่อเปลี่ยน',
        button: true,
        excludeSemantics: true,
        child: GestureDetector(
          key: const Key('club_image_picker'),
          onTap: _isSaving ? null : _pickImage,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: _imageBytes != null
                        ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                        : existingUrl != null
                            // NetworkThumbnail, not a bare Image.network:
                            // decodes at the 96px this box paints instead
                            // of the full 1600px upload (Beta4 §7).
                            ? NetworkThumbnail(imageUrl: existingUrl)
                            : const Center(
                                child: Icon(Icons.add_photo_alternate_outlined,
                                    size: 32),
                              ),
                  ),
                ),
              ),
              const SizedBox(height: WynSpacing.space2),
              Text(
                'รูป Club',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

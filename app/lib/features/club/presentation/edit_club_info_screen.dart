import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/club.dart';
import '../data/club_repository.dart';
import '../../../core/design/wyn_spacing.dart';

/// Owner/Admin "แก้ไขข้อมูล Club" -- reuses CreateClubScreen's form shape
/// for Name/Description/Cover/Icon/Category, pre-filled with the current
/// values. Privacy is a separate More-menu action (ClubPage), not part
/// of this form, per the Design spec's Screen 3 menu breakdown.
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

  Uint8List? _coverBytes;
  String? _coverExtension;
  Uint8List? _iconBytes;
  String? _iconExtension;

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

  Future<void> _pickCover() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final extension =
        picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
    if (!mounted) return;
    setState(() {
      _coverBytes = bytes;
      _coverExtension = extension;
    });
  }

  Future<void> _pickIcon() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final extension =
        picked.name.contains('.') ? picked.name.split('.').last.toLowerCase() : 'jpg';
    if (!mounted) return;
    setState(() {
      _iconBytes = bytes;
      _iconExtension = extension;
    });
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (_coverBytes != null && _coverExtension != null) {
        await widget.clubRepository.uploadClubCover(
          clubId: widget.club.id,
          bytes: _coverBytes!,
          fileExtension: _coverExtension!,
        );
      }
      if (_iconBytes != null && _iconExtension != null) {
        await widget.clubRepository.uploadClubIcon(
          clubId: widget.club.id,
          bytes: _iconBytes!,
          fileExtension: _iconExtension!,
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
              _buildCoverPicker(),
              const SizedBox(height: WynSpacing.space3),
              _buildIconPicker(),
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

  Widget _buildCoverPicker() {
    return GestureDetector(
      onTap: _isSaving ? null : _pickCover,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: _coverBytes != null
                ? Image.memory(_coverBytes!, fit: BoxFit.cover)
                : widget.club.coverUrl != null
                    ? Image.network(widget.club.coverUrl!, fit: BoxFit.cover)
                    : const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 32)),
          ),
        ),
      ),
    );
  }

  Widget _buildIconPicker() {
    return Center(
      child: GestureDetector(
        onTap: _isSaving ? null : _pickIcon,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              backgroundImage: _iconBytes != null
                  ? MemoryImage(_iconBytes!)
                  : (widget.club.iconUrl != null
                      ? NetworkImage(widget.club.iconUrl!)
                      : null) as ImageProvider?,
              child: _iconBytes == null && widget.club.iconUrl == null
                  ? const Icon(Icons.add_photo_alternate_outlined)
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.surface,
                child: const Icon(Icons.camera_alt, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

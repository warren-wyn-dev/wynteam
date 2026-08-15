import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/seller_repository.dart';
import '../data/store.dart';

/// "ร้านค้า" tab -- lets a seller edit every field of their own store in
/// one always-editable form (no separate view mode). Mirrors
/// `app/lib/features/club/presentation/edit_club_info_screen.dart`'s
/// banner(16:9)+logo(circle) picker shape almost exactly -- see
/// .wyn/docs/design/seller-004-store-management.md, Screen:
/// SellerStoreScreen.
///
/// Unlike `EditClubInfoScreen`, this screen is a tab body inside
/// `SellerHomeShell`'s `IndexedStack`, not a pushed route -- it must
/// never call `Navigator.pop()` after saving, only show a SnackBar and
/// stay put.
class SellerStoreScreen extends StatefulWidget {
  const SellerStoreScreen({
    super.key,
    required this.store,
    required this.sellerRepository,
    required this.onStoreUpdated,
  });

  final Store store;
  final SellerRepository sellerRepository;

  /// Called with the freshest `Store` row after a successful save, so
  /// `SellerHomeShell` can rebuild every other tab with it. Same
  /// callback-to-parent-rebuild pattern as `CreateStoreScreen.
  /// onStoreCreated`/`UsernameSetupScreen.onUsernameSet` -- see
  /// .wyn/learning/PATTERNS.md.
  final ValueChanged<Store> onStoreUpdated;

  @override
  State<SellerStoreScreen> createState() => _SellerStoreScreenState();
}

class _SellerStoreScreenState extends State<SellerStoreScreen> {
  static const _nameMaxLength = 100;
  static const _descriptionMaxLength = 500;
  static const _addressMaxLength = 300;
  static const _contactPhoneMaxLength = 50;
  static const _businessHoursMaxLength = 200;

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _addressController;
  late final TextEditingController _contactPhoneController;
  late final TextEditingController _businessHoursController;

  Uint8List? _bannerBytes;
  String? _bannerExtension;
  Uint8List? _logoBytes;
  String? _logoExtension;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.store.name);
    _descriptionController =
        TextEditingController(text: widget.store.description ?? '');
    _addressController = TextEditingController(text: widget.store.address ?? '');
    _contactPhoneController =
        TextEditingController(text: widget.store.contactPhone ?? '');
    _businessHoursController =
        TextEditingController(text: widget.store.businessHours ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _contactPhoneController.dispose();
    _businessHoursController.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
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
      _bannerBytes = bytes;
      _bannerExtension = extension;
    });
  }

  Future<void> _pickLogo() async {
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
      _logoBytes = bytes;
      _logoExtension = extension;
    });
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updated = await widget.sellerRepository.updateStoreInfo(
        storeId: widget.store.id,
        name: _nameController.text,
        description: _descriptionController.text,
        address: _addressController.text,
        contactPhone: _contactPhoneController.text,
        businessHours: _businessHoursController.text,
        newLogoBytes: _logoBytes,
        newLogoExtension: _logoExtension,
        newBannerBytes: _bannerBytes,
        newBannerExtension: _bannerExtension,
      );
      if (!mounted) return;
      widget.onStoreUpdated(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกข้อมูลร้านสำเร็จ')),
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
    final canSave = !_isSaving && _nameController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('ร้านค้า')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBannerPicker(),
              const SizedBox(height: 12),
              _buildLogoPicker(),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                maxLength: _nameMaxLength,
                enabled: !_isSaving,
                decoration: const InputDecoration(labelText: 'ชื่อร้าน'),
                onChanged: (_) => setState(() {}),
              ),
              TextField(
                controller: _descriptionController,
                maxLength: _descriptionMaxLength,
                maxLines: 4,
                enabled: !_isSaving,
                decoration: const InputDecoration(labelText: 'คำอธิบาย'),
              ),
              TextField(
                controller: _addressController,
                maxLength: _addressMaxLength,
                maxLines: 3,
                enabled: !_isSaving,
                decoration: const InputDecoration(labelText: 'ที่อยู่ (ไม่บังคับ)'),
              ),
              TextField(
                controller: _contactPhoneController,
                maxLength: _contactPhoneMaxLength,
                enabled: !_isSaving,
                decoration: const InputDecoration(labelText: 'เบอร์ติดต่อ (ไม่บังคับ)'),
              ),
              TextField(
                controller: _businessHoursController,
                maxLength: _businessHoursMaxLength,
                maxLines: 2,
                enabled: !_isSaving,
                decoration: const InputDecoration(
                  labelText: 'เวลาทำการ (ไม่บังคับ)',
                  hintText: 'เช่น จันทร์-ศุกร์ 9:00-18:00 น.',
                ),
              ),
              const SizedBox(height: 8),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
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

  Widget _buildBannerPicker() {
    return Semantics(
      label: 'แตะเพื่อเปลี่ยนรูปแบนเนอร์ร้าน',
      child: GestureDetector(
        onTap: _isSaving ? null : _pickBanner,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: _bannerBytes != null
                  ? Image.memory(_bannerBytes!, fit: BoxFit.cover)
                  : widget.store.bannerUrl != null
                      ? Image.network(widget.store.bannerUrl!, fit: BoxFit.cover)
                      : const Center(child: Icon(Icons.add_photo_alternate_outlined, size: 32)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoPicker() {
    return Center(
      child: Semantics(
        label: 'แตะเพื่อเปลี่ยนโลโก้ร้าน',
        child: GestureDetector(
          onTap: _isSaving ? null : _pickLogo,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                backgroundImage: _logoBytes != null
                    ? MemoryImage(_logoBytes!)
                    : (widget.store.logoUrl != null
                        ? NetworkImage(widget.store.logoUrl!)
                        : null) as ImageProvider?,
                child: _logoBytes == null && widget.store.logoUrl == null
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
      ),
    );
  }
}

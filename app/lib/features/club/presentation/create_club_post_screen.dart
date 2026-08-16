import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/data/profile_repository.dart';
import '../data/club.dart';
import '../data/club_post_repository.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/widgets/mention_input.dart';

/// `CreateClubPostScreen` (Screen 5). Always locked to the Club it was
/// opened from -- creating a Club post from anywhere else isn't in scope
/// this round, per the Product spec. See
/// .wyn/docs/design/wyn-014-club-core.md, Screen 5.
class CreateClubPostScreen extends StatefulWidget {
  const CreateClubPostScreen({
    super.key,
    required this.clubPostRepository,
    required this.club,
    ProfileRepository? profileRepository,
  }) : _profileRepository = profileRepository;

  final ClubPostRepository clubPostRepository;
  final Club club;

  // Optional -- same reasoning as CreateDropScreen's identical field:
  // defaults to a real Supabase-backed instance so existing call sites
  // don't need to thread one through just for MentionInput.
  final ProfileRepository? _profileRepository;

  @override
  State<CreateClubPostScreen> createState() => _CreateClubPostScreenState();
}

class _CreateClubPostScreenState extends State<CreateClubPostScreen> {
  static const _maxImages = 10;

  final _contentController = TextEditingController();
  final _linkController = TextEditingController();
  late final ProfileRepository _profileRepository =
      widget._profileRepository ?? ProfileRepository(Supabase.instance.client);
  Set<String> _mentionedUserIds = {};
  final List<Uint8List> _images = [];
  final List<String> _imageExtensions = [];

  bool _isPosting = false;
  String? _errorMessage;

  bool get _canPost =>
      !_isPosting &&
      (_contentController.text.trim().isNotEmpty ||
          _images.isNotEmpty ||
          _linkController.text.trim().isNotEmpty);

  @override
  void dispose() {
    _contentController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) return;

    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      limit: remaining,
    );
    if (picked.isEmpty) return;

    for (final file in picked.take(remaining)) {
      final bytes = await file.readAsBytes();
      final extension =
          file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
      _images.add(bytes);
      _imageExtensions.add(extension);
    }
    if (!mounted) return;
    setState(() {});
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      _imageExtensions.removeAt(index);
    });
  }

  Future<void> _post() async {
    setState(() {
      _isPosting = true;
      _errorMessage = null;
    });

    try {
      await widget.clubPostRepository.createPost(
        clubId: widget.club.id,
        content: _contentController.text,
        images: _images.isEmpty ? null : _images,
        imageExtensions: _images.isEmpty ? null : _imageExtensions,
        linkUrl: _linkController.text,
        mentionedUserIds: _mentionedUserIds,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'โพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text('โพสต์ใน ${widget.club.name}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: WynSpacing.space2),
            child: Center(
              child: TextButton(
                onPressed: _canPost ? _post : null,
                child: _isPosting
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('โพสต์'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WynSpacing.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MentionInput(
                controller: _contentController,
                profileRepository: _profileRepository,
                onMentionedUsersChanged: (ids) => setState(() => _mentionedUserIds = ids),
                maxLength: 2000,
                maxLines: 6,
                minLines: 3,
                enabled: !_isPosting,
                decoration: const InputDecoration(hintText: 'มีอะไรอยากบอก Club นี้บ้าง?'),
                onChanged: (_) => setState(() {}),
              ),
              if (_images.isNotEmpty) _buildImageRow(),
              const SizedBox(height: WynSpacing.space2),
              OutlinedButton.icon(
                onPressed: (_isPosting || _images.length >= _maxImages) ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('แนบรูป'),
              ),
              const SizedBox(height: WynSpacing.space4),
              TextField(
                controller: _linkController,
                enabled: !_isPosting,
                decoration: const InputDecoration(
                  labelText: 'ลิงก์ (ไม่บังคับ)',
                  hintText: 'https://...',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: WynSpacing.space4),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageRow() {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),
        itemCount: _images.length,
        separatorBuilder: (context, index) => const SizedBox(width: WynSpacing.space2),
        itemBuilder: (context, index) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                child: Image.memory(
                  _images[index],
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: GestureDetector(
                  onTap: _isPosting ? null : () => _removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

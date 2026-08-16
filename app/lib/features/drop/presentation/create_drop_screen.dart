import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/data/profile_repository.dart';
import '../data/drop_repository.dart';
import '../data/square_crop.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/widgets/mention_input.dart';

/// Screen 2 — Create Drop.
/// See .wyn/docs/design/wyn-005-drop.md
class CreateDropScreen extends StatefulWidget {
  const CreateDropScreen({
    super.key,
    required this.dropRepository,
    ProfileRepository? profileRepository,
  }) : _profileRepository = profileRepository;

  final DropRepository dropRepository;

  // Optional -- defaults to a real Supabase-backed instance (see
  // _CreateDropScreenState's late final below) so existing call sites
  // don't need to thread one through just for MentionInput. Tests
  // inject a Recording* fake here instead of touching
  // Supabase.instance. See .wyn/learning/PATTERNS.md.
  final ProfileRepository? _profileRepository;

  @override
  State<CreateDropScreen> createState() => _CreateDropScreenState();
}

class _CreateDropScreenState extends State<CreateDropScreen> {
  static const _captionMaxLength = 500;

  final _captionController = TextEditingController();
  late final ProfileRepository _profileRepository =
      widget._profileRepository ?? ProfileRepository(Supabase.instance.client);
  Set<String> _mentionedUserIds = {};
  Uint8List? _imageBytes;
  String _imageExtension = 'jpg';
  bool _isCropping = false;

  bool _isSharing = false;
  String? _errorMessage;

  bool get _canShare => !_isSharing && !_isCropping && _imageBytes != null;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    // Guards the same race the "แชร์" button guards against (see
    // .wyn/tasks/bugs/WYN-004-feed-and-post.md, QA round 1): without
    // this, the image area's onTap could reopen the picker sheet while
    // the previous pick is still being cropped.
    if (_isCropping) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isCropping = true);
    try {
      final rawBytes = await picked.readAsBytes();
      // Cropped to a fresh PNG, so the original extension no longer
      // reflects the actual encoded bytes.
      final cropped = await centerCropToSquare(rawBytes);
      if (!mounted) return;
      setState(() {
        _imageBytes = cropped;
        _imageExtension = 'png';
      });
    } catch (_) {
      // e.g. a corrupted file or a format decodeImageFromList can't
      // handle -- rare, but silently doing nothing would leave the user
      // tapping a placeholder that never responds.
      if (!mounted) return;
      setState(() => _errorMessage = 'เลือกรูปไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  Future<void> _showImageSourceSheet() {
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
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากคลังภาพ'),
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

  Future<void> _share() async {
    // The "แชร์" button's onPressed is only disabled on the *next*
    // rebuild (setState schedules it, it doesn't happen synchronously),
    // so a rapid double-tap before that rebuild would otherwise still
    // reach this method a second time. See .wyn/tasks/bugs/WYN-004-feed-and-post.md
    // (QA round 1) for the bug class this guards against.
    if (_isSharing) return;
    final imageBytes = _imageBytes;
    if (imageBytes == null) return;

    setState(() {
      _isSharing = true;
      _errorMessage = null;
    });

    try {
      await widget.dropRepository.createDrop(
        imageBytes: imageBytes,
        imageExtension: _imageExtension,
        caption: _captionController.text,
        mentionedUserIds: _mentionedUserIds,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isSharing = false);
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
        title: const Text('Drop ใหม่'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: WynSpacing.space2),
            child: Center(
              child: TextButton(
                onPressed: _canShare ? _share : null,
                child: _isSharing
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('แชร์'),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImageArea(),
              Padding(
                padding: const EdgeInsets.all(WynSpacing.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MentionInput(
                      controller: _captionController,
                      profileRepository: _profileRepository,
                      onMentionedUsersChanged: (ids) =>
                          setState(() => _mentionedUserIds = ids),
                      maxLength: _captionMaxLength,
                      maxLines: 4,
                      minLines: 2,
                      enabled: !_isSharing,
                      decoration: const InputDecoration(
                        hintText: 'เขียนแคปชัน... ใส่ #hashtag หรือ @mention ได้',
                        border: InputBorder.none,
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: WynSpacing.space2),
                      Text(
                        _errorMessage!,
                        style:
                            TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea() {
    final imageBytes = _imageBytes;

    return GestureDetector(
      onTap: (_isSharing || _isCropping) ? null : _showImageSourceSheet,
      child: AspectRatio(
        aspectRatio: 1,
        child: Semantics(
          label: imageBytes == null ? 'แตะเพื่อเลือกหรือถ่ายรูป' : 'รูปที่เลือก',
          button: imageBytes == null,
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: _isCropping
                ? const Center(child: CircularProgressIndicator())
                : imageBytes == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 40),
                            SizedBox(height: WynSpacing.space2),
                            Text('แตะเพื่อเลือกรูป'),
                          ],
                        ),
                      )
                    : Image.memory(imageBytes, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

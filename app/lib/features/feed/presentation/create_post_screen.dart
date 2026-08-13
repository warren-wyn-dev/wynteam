import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/post_repository.dart';

/// Screen 2 — Create Post.
/// See .wyn/docs/design/wyn-004-feed-and-post.md
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key, required this.postRepository});

  final PostRepository postRepository;

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  static const _textMaxLength = 500;

  final _textController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageExtension;

  bool _isPosting = false;
  String? _errorMessage;

  bool get _canPost =>
      !_isPosting &&
      (_textController.text.trim().isNotEmpty || _imageBytes != null);

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final extension = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';

    setState(() {
      _imageBytes = bytes;
      _imageExtension = extension;
    });
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

  Future<void> _post() async {
    setState(() {
      _isPosting = true;
      _errorMessage = null;
    });

    try {
      await widget.postRepository.createPost(
        textContent: _textController.text,
        imageBytes: _imageBytes,
        imageExtension: _imageExtension,
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
        title: const Text('สร้างโพสต์'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _textController,
                maxLength: _textMaxLength,
                maxLines: 8,
                minLines: 3,
                enabled: !_isPosting,
                decoration: const InputDecoration(
                  hintText: 'มีอะไรอยากเล่าไหม?',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_imageBytes != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: IconButton.filled(
                        icon: const Icon(Icons.close),
                        tooltip: 'เอารูปออก',
                        onPressed: _isPosting
                            ? null
                            : () => setState(() {
                                  _imageBytes = null;
                                  _imageExtension = null;
                                }),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isPosting ? null : _showImageSourceSheet,
                icon: const Icon(Icons.image_outlined),
                label: const Text('แนบรูปภาพ'),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

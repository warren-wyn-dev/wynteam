import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../data/pop_repository.dart';

const _maxDurationSeconds = 60;

/// Formats a duration in seconds as "m:ss" (e.g. 45 -> "0:45", 60 -> "1:00").
String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Screen 2 — Create Pop.
/// See .wyn/docs/design/wyn-006-pop.md
class CreatePopScreen extends StatefulWidget {
  const CreatePopScreen({super.key, required this.popRepository});

  final PopRepository popRepository;

  @override
  State<CreatePopScreen> createState() => _CreatePopScreenState();
}

class _CreatePopScreenState extends State<CreatePopScreen> {
  static const _captionMaxLength = 500;

  final _captionController = TextEditingController();
  String? _videoPath;
  VideoPlayerController? _previewController;
  int _durationSeconds = 0;
  bool _isLoadingVideo = false;

  bool _isSharing = false;
  String? _errorMessage;

  bool get _canShare =>
      !_isSharing && !_isLoadingVideo && _videoPath != null;

  @override
  void dispose() {
    _captionController.dispose();
    _previewController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(ImageSource source) async {
    // Guards the same race the "แชร์" button guards against (see
    // .wyn/tasks/bugs/WYN-004-feed-and-post.md, QA round 1): without
    // this, the picker area's onTap could reopen the picker sheet while
    // the previous pick is still loading.
    if (_isLoadingVideo) return;

    final picked = await ImagePicker().pickVideo(source: source);
    if (picked == null) return;

    setState(() {
      _isLoadingVideo = true;
      _errorMessage = null;
    });

    final previousController = _previewController;
    try {
      final controller = VideoPlayerController.file(File(picked.path));
      await controller.initialize();
      final duration = controller.value.duration.inSeconds;

      if (duration > _maxDurationSeconds) {
        await controller.dispose();
        if (!mounted) return;
        setState(() {
          _errorMessage =
              'วิดีโอยาวเกิน $_maxDurationSeconds วินาที เลือกคลิปสั้นกว่านี้';
        });
        return;
      }

      await controller.setLooping(true);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _videoPath = picked.path;
        _previewController = controller;
        _durationSeconds = duration;
      });
      await previousController?.dispose();
    } catch (_) {
      // e.g. a corrupted file or an unsupported codec -- rare, but
      // silently doing nothing would leave the user tapping a
      // placeholder that never responds.
      if (!mounted) return;
      setState(() => _errorMessage = 'เลือกวิดีโอไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isLoadingVideo = false);
    }
  }

  Future<void> _showVideoSourceSheet() {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('ถ่ายวิดีโอใหม่'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickVideo(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: const Text('เลือกจากคลังวิดีโอ'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickVideo(ImageSource.gallery);
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
    final videoPath = _videoPath;
    if (videoPath == null) return;

    setState(() {
      _isSharing = true;
      _errorMessage = null;
    });

    try {
      final videoFile = File(videoPath);
      final videoBytes = await videoFile.readAsBytes();

      // Thumbnail generation can fail on some source videos -- treated
      // as optional (see PopRepository.createPop), not a blocking error.
      Uint8List? thumbnailBytes;
      try {
        thumbnailBytes = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          quality: 75,
        );
      } catch (_) {
        thumbnailBytes = null;
      }

      await widget.popRepository.createPop(
        videoBytes: videoBytes,
        videoExtension: videoPath.split('.').last,
        thumbnailBytes: thumbnailBytes,
        durationSeconds: _durationSeconds,
        caption: _captionController.text,
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
        title: const Text('Pop ใหม่'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
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
              _buildVideoArea(),
              if (_previewController != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      '${_formatDuration(_durationSeconds)} / ${_formatDuration(_maxDurationSeconds)}',
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _captionController,
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
                      const SizedBox(height: 8),
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

  Widget _buildVideoArea() {
    final controller = _previewController;

    return GestureDetector(
      onTap: (_isSharing || _isLoadingVideo) ? null : _showVideoSourceSheet,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Semantics(
          label: controller == null ? 'แตะเพื่อเลือกหรือถ่ายวิดีโอ' : 'วิดีโอที่เลือก',
          button: controller == null,
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: _isLoadingVideo
                ? const Center(child: CircularProgressIndicator())
                : controller == null
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.video_call_outlined, size: 40),
                            SizedBox(height: 8),
                            Text('แตะเพื่อเลือกวิดีโอ'),
                          ],
                        ),
                      )
                    : GestureDetector(
                        onTap: () => setState(
                          () => controller.value.isPlaying
                              ? controller.pause()
                              : controller.play(),
                        ),
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
          ),
        ),
      ),
    );
  }
}

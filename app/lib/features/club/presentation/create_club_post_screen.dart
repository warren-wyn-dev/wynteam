import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/interaction/wyn_feedback.dart';
import '../../hashtag/data/hashtag_repository.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/club.dart';
import '../data/club_post_repository.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/widgets/mention_input.dart';

/// `CreateClubPostScreen` (Screen 5). Always locked to the Club it was
/// opened from -- creating a Club post from anywhere else isn't in scope
/// this round, per the Product spec. See
/// .wyn/docs/design/wyn-014-club-core.md, Screen 5.
///
/// Restyled onto the same shell CreateDropScreen uses (04-drop.tsx --
/// plain "ยกเลิก"/"โพสต์" header row instead of an AppBar, own-avatar +
/// borderless composer body) so posting into a Club and posting a normal
/// Drop feel like the same product action, per Founder request: "ปุ่มโพส
/// กดเข้าไปแล้ว ต้องเป็นหน้าโพสต์เหมือนหน้าโพสต์ปกติใช้อยู่". The locked
/// destination ("โพสต์ใน [ชื่อ Club]") takes the exact slot Drop's own
/// (tappable) audience chip sits in, styled as a plain, non-tappable
/// chip -- there is no destination picker here, only Drop composing
/// keeps that choice.
class CreateClubPostScreen extends StatefulWidget {
  const CreateClubPostScreen({
    super.key,
    required this.clubPostRepository,
    required this.club,
    ProfileRepository? profileRepository,
    HashtagRepository? hashtagRepository,
    @visibleForTesting this.debugInitialImagesBytes,
  })  : _profileRepository = profileRepository,
        _hashtagRepository = hashtagRepository;

  final ClubPostRepository clubPostRepository;
  final Club club;

  // Optional -- same reasoning as CreateDropScreen's identical field:
  // defaults to a real Supabase-backed instance so existing call sites
  // don't need to thread one through just for MentionInput.
  final ProfileRepository? _profileRepository;

  // Same optional/defaulted shape -- WYNOS V1.0.0 Beta requirement 7.
  final HashtagRepository? _hashtagRepository;

  /// WYN-103 (test-only escape hatch, same reasoning/posture as
  /// CreateDropScreen's identically named field -- see its doc comment
  /// for the full story on why real image_picker can't be widget-tested
  /// in this sandbox). Never read outside tests.
  @visibleForTesting
  final List<Uint8List>? debugInitialImagesBytes;

  @override
  State<CreateClubPostScreen> createState() => _CreateClubPostScreenState();
}

class _CreateClubPostScreenState extends State<CreateClubPostScreen> {
  // WYN-103: was 10 -- Founder's "สูงสุด 9 รูป ห้ามเกิน" (item 15/28)
  // applies to every place a post can carry images, Club posts included,
  // not just CreateDropScreen (which already used 9).
  static const _maxImages = 9;

  final _contentController = TextEditingController();
  final _linkController = TextEditingController();
  late final ProfileRepository _profileRepository =
      widget._profileRepository ?? ProfileRepository(Supabase.instance.client);
  Set<String> _mentionedUserIds = {};
  final List<Uint8List> _images = [];
  final List<String> _imageExtensions = [];

  // Same fail-open, best-effort fetch as CreateDropScreen's own
  // _ownProfile -- a failed fetch just leaves the header avatar on its
  // fallback-letter state rather than blocking the composer.
  Profile? _ownProfile;

  bool _isPosting = false;
  String? _errorMessage;

  bool get _canPost =>
      !_isPosting &&
      (_contentController.text.trim().isNotEmpty ||
          _images.isNotEmpty ||
          _linkController.text.trim().isNotEmpty);

  @override
  void initState() {
    super.initState();
    final debugBytes = widget.debugInitialImagesBytes;
    if (debugBytes != null) {
      _images.addAll(debugBytes);
      _imageExtensions.addAll(List.filled(debugBytes.length, 'jpg'));
    }
    _loadOwnProfile();
  }

  Future<void> _loadOwnProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final profile = await _profileRepository.fetchProfile(userId);
      if (!mounted) return;
      setState(() => _ownProfile = profile);
    } catch (_) {
      // Silent -- see the field's own doc comment.
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) {
      // WYN-103: the "+" button stays tappable at 9/9 (see its
      // `onPressed:` below -- it no longer disables on image count) so
      // this is reachable, rather than the button just going inert.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เพิ่มรูปได้สูงสุด 9 รูปต่อโพสต์')),
      );
      return;
    }

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
    // Same synchronous double-submit guard CreateDropScreen._share and
    // CreatePopScreen._share already have, and the only composer that
    // was missing it: `onPressed: _canPost ? _post : null` only stops
    // the *second* tap once the rebuild setState schedules has actually
    // run, so a fast double-tap reaches this method twice and posts
    // twice. See .wyn/tasks/bugs/WYN-004-feed-and-post.md (QA round 1)
    // for the original bug of this class.
    if (!_canPost) return;

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
      WynFeedback.completed();
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      WynFeedback.failed();
      setState(() => _errorMessage = 'โพสต์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _handleClose() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WynColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: WynColors.hairline),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(WynSpacing.space4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AvatarCircle(
                      imageUrl: _ownProfile?.avatarUrl,
                      fallbackText: _ownProfile?.username ?? '',
                      radius: 20,
                      ring: true,
                    ),
                    const SizedBox(width: WynSpacing.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LockedClubChip(clubName: widget.club.name),
                          const SizedBox(height: WynSpacing.space3),
                          MentionInput(
                            controller: _contentController,
                            profileRepository: _profileRepository,
                            hashtagRepository: widget._hashtagRepository,
                            onMentionedUsersChanged: (ids) =>
                                setState(() => _mentionedUserIds = ids),
                            maxLength: 2000,
                            maxLines: null,
                            minLines: 3,
                            enabled: !_isPosting,
                            style: const TextStyle(
                                fontSize: 20, color: WynColors.ink, height: 1.4),
                            decoration: const InputDecoration(
                              hintText: 'มีอะไรอยากบอก Club นี้บ้าง?',
                              hintStyle: TextStyle(
                                  fontSize: 20, color: WynColors.faint, height: 1.4),
                              border: InputBorder.none,
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          if (_images.isNotEmpty) _buildImageStrip(),
                          const SizedBox(height: WynSpacing.space3),
                          OutlinedButton.icon(
                            // WYN-103: stays tappable at 9/9 -- _pickImages()
                            // itself shows a SnackBar in that case, clearer
                            // than a disabled button the user can't tell
                            // apart from "posting".
                            onPressed: _isPosting ? null : _pickImages,
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
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Same "ยกเลิก" (left, plain text) / filled pill "โพสต์" (right) header
  // CreateDropScreen's own _buildHeader draws -- see that method's doc
  // comment for the exact 04-drop.tsx reference this mirrors.
  Widget _buildHeader() {
    final canPost = _canPost;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          WynSpacing.space4, WynSpacing.space2, WynSpacing.space4, WynSpacing.space3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: _isPosting ? null : _handleClose,
            style: TextButton.styleFrom(
              foregroundColor: WynColors.ink,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('ยกเลิก', style: TextStyle(fontSize: 15, color: WynColors.ink)),
          ),
          TextButton(
            onPressed: canPost ? _post : null,
            style: TextButton.styleFrom(
              backgroundColor: canPost ? WynColors.sapphire : WynColors.hairline,
              foregroundColor: canPost ? WynColors.paper : WynColors.mutedNeutral,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              shape: const StadiumBorder(),
            ),
            child: _isPosting
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: canPost ? WynColors.paper : WynColors.mutedNeutral,
                    ),
                  )
                : const Text('โพสต์', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // Same rounded-box strip + circular remove button CreateDropScreen's
  // own _buildImageStrip draws for a freshly-picked photo (128x160,
  // radiusLg) -- Club posts don't get the aspect-ratio picker/cropper a
  // Drop's images do (`club_posts` has no image_width/image_height
  // columns to lay a real ratio out from, same reasoning ClubPostImages'
  // own doc comment already gives), so this stays a plain preview strip.
  Widget _buildImageStrip() {
    return Padding(
      padding: const EdgeInsets.only(top: WynSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _images.length,
              separatorBuilder: (_, __) => const SizedBox(width: WynSpacing.space2),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
                child: SizedBox(
                  width: 128,
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(_images[index], fit: BoxFit.cover),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Semantics(
                          label: 'ลบรูปนี้',
                          button: true,
                          excludeSemantics: true,
                          child: InkWell(
                            onTap: _isPosting ? null : () => _removeImage(index),
                            customBorder: const CircleBorder(),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: WynColors.imageScrimStrong,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(Icons.close, size: 13, color: WynColors.paper),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: WynSpacing.space1),
            child: Text(
              '${_images.length}/$_maxImages',
              style: const TextStyle(fontSize: 13, color: WynColors.faint),
            ),
          ),
        ],
      ),
    );
  }
}

/// The locked "โพสต์ใน [ชื่อ Club]" chip -- takes the same slot
/// CreateDropScreen's own (tappable) `_AudienceChip` sits in, styled as
/// plain and non-interactive since there is no destination to pick here.
class _LockedClubChip extends StatelessWidget {
  const _LockedClubChip({required this.clubName});

  final String clubName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: 6),
      decoration: BoxDecoration(
        color: WynColors.hairline,
        borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_outlined, size: 14, color: WynColors.graphite),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'โพสต์ใน $clubName',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: WynColors.graphite),
            ),
          ),
        ],
      ),
    );
  }
}

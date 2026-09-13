import 'package:wyn/core/typography/browser_system_text.dart';
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

/// WYN-115, Design Screen 1 -- which of the two mutually-exclusive media
/// areas this composer is showing. Mirrors Drop's own `_ComposeMode`
/// (WYN-035) in create_drop_screen.dart.
enum _ComposeMode { image, poll }

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
    required this.channelId,
    required this.channelName,
    ProfileRepository? profileRepository,
    HashtagRepository? hashtagRepository,
    @visibleForTesting this.debugInitialImagesBytes,
  })  : _profileRepository = profileRepository,
        _hashtagRepository = hashtagRepository;

  final ClubPostRepository clubPostRepository;
  final Club club;

  /// WYN-127: locked to whichever channel this composer was opened from
  /// -- Requirement 2 ("default = channel ที่กำลังเปิดดูอยู่"). There is
  /// no channel picker here, same as there is no Club picker: the
  /// destination is fixed by where "สร้างโพสต์" was tapped from.
  final String channelId;
  final String channelName;

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

  // WYN-115: Poll composer state -- same shape/limits as
  // CreateDropScreen's own (WYN-035), see that file's identical fields.
  _ComposeMode _mode = _ComposeMode.image;
  static const _maxPollOptions = 4;
  static const _minPollOptions = 2;
  static const _pollOptionMaxLength = 80;
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _pollDurationDays = 1;

  // Same fail-open, best-effort fetch as CreateDropScreen's own
  // _ownProfile -- a failed fetch just leaves the header avatar on its
  // fallback-letter state rather than blocking the composer.
  Profile? _ownProfile;

  bool _isPosting = false;
  String? _errorMessage;

  /// WYN-115: in poll mode this replaces the ordinary "content, or an
  /// image, or a link" condition entirely (not OR'd with it) -- a
  /// question with invalid/duplicate/empty options isn't postable even
  /// if a stray image or link is also sitting in state from before the
  /// mode was switched. See create_poll_club_post()'s own validation in
  /// supabase/schema.sql.
  bool get _canPost {
    if (_isPosting) return false;
    if (_mode == _ComposeMode.poll) {
      return _contentController.text.trim().isNotEmpty && _pollOptionsValid;
    }
    return _contentController.text.trim().isNotEmpty ||
        _images.isNotEmpty ||
        _linkController.text.trim().isNotEmpty;
  }

  /// Every option non-empty (after trim) and within
  /// [_pollOptionMaxLength], and no two options equal
  /// case-insensitively after trim -- mirrors `valid_poll_options()` in
  /// supabase/schema.sql and CreateDropScreen's identical getter.
  bool get _pollOptionsValid {
    final trimmed = _pollOptionControllers
        .map((c) => c.text.trim())
        .toList(growable: false);
    if (trimmed.any((t) => t.isEmpty || t.length > _pollOptionMaxLength)) {
      return false;
    }
    final lowercased = trimmed.map((t) => t.toLowerCase()).toSet();
    return lowercased.length == trimmed.length;
  }

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
    for (final controller in _pollOptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addPollOption() {
    if (_pollOptionControllers.length >= _maxPollOptions) return;
    setState(() => _pollOptionControllers.add(TextEditingController()));
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length <= _minPollOptions) return;
    setState(() => _pollOptionControllers.removeAt(index).dispose());
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) {
      // WYN-103: the "+" button stays tappable at 9/9 (see its
      // `onPressed:` below -- it no longer disables on image count) so
      // this is reachable, rather than the button just going inert.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: BrowserSystemText('เพิ่มรูปได้สูงสุด 9 รูปต่อโพสต์')),
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
      final extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : 'jpg';
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
      if (_mode == _ComposeMode.poll) {
        await widget.clubPostRepository.createPollClubPost(
          clubId: widget.club.id,
          channelId: widget.channelId,
          question: _contentController.text,
          options: _pollOptionControllers.map((c) => c.text.trim()).toList(),
          durationDays: _pollDurationDays,
          mentionedUserIds: _mentionedUserIds,
        );
      } else {
        await widget.clubPostRepository.createPost(
          clubId: widget.club.id,
          channelId: widget.channelId,
          content: _contentController.text,
          images: _images.isEmpty ? null : _images,
          imageExtensions: _images.isEmpty ? null : _imageExtensions,
          linkUrl: _linkController.text,
          mentionedUserIds: _mentionedUserIds,
        );
      }
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
                          _LockedClubChip(
                            clubName: widget.club.name,
                            channelName: widget.channelName,
                          ),
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
                                fontSize: 20,
                                color: WynColors.ink,
                                height: 1.4),
                            decoration: InputDecoration(
                              hint: BrowserSystemText(_mode == _ComposeMode.poll
                                  ? 'ตั้งคำถามโพล...'
                                  : 'มีอะไรอยากบอก Club นี้บ้าง?'),
                              hintStyle: const TextStyle(
                                  fontSize: 20,
                                  color: WynColors.faint,
                                  height: 1.4),
                              border: InputBorder.none,
                              counter: const SizedBox.shrink(),
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: WynSpacing.space3),
                          _buildModeToggle(),
                          const SizedBox(height: WynSpacing.space3),
                          if (_mode == _ComposeMode.poll)
                            _buildPollComposer()
                          else ...[
                            if (_images.isNotEmpty) _buildImageStrip(),
                            const SizedBox(height: WynSpacing.space3),
                            OutlinedButton.icon(
                              // WYN-103: stays tappable at 9/9 -- _pickImages()
                              // itself shows a SnackBar in that case, clearer
                              // than a disabled button the user can't tell
                              // apart from "posting".
                              onPressed: _isPosting ? null : _pickImages,
                              icon: const Icon(
                                  Icons.add_photo_alternate_outlined),
                              label: const BrowserSystemText('แนบรูป'),
                            ),
                            const SizedBox(height: WynSpacing.space4),
                            BrowserSystemTextField(
                              controller: _linkController,
                              enabled: !_isPosting,
                              decoration: const InputDecoration(
                                label: BrowserSystemText('ลิงก์ (ไม่บังคับ)'),
                                hint: BrowserSystemText('https://...'),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: WynSpacing.space4),
                            BrowserSystemText(
                              _errorMessage!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error),
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
      padding: const EdgeInsets.fromLTRB(WynSpacing.space4, WynSpacing.space2,
          WynSpacing.space4, WynSpacing.space3),
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
            child: const BrowserSystemText('ยกเลิก',
                style: TextStyle(fontSize: 15, color: WynColors.ink)),
          ),
          TextButton(
            onPressed: canPost ? _post : null,
            style: TextButton.styleFrom(
              backgroundColor:
                  canPost ? WynColors.sapphire : WynColors.hairline,
              foregroundColor:
                  canPost ? WynColors.paper : WynColors.mutedNeutral,
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
                : const BrowserSystemText('โพสต์',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // WYN-115, Design Screen 1 -- "แถบปุ่มเล็กเหนือปุ่ม 'แนบรูป' เดิม 2 ปุ่ม
  // toggle" that switches the media area between image mode (default)
  // and poll mode. Switching never clears the other mode's state (images
  // picked, link typed, poll options filled in) -- only "โพสต์" actually
  // commits to one.
  Widget _buildModeToggle() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isPosting
                ? null
                : () => setState(() => _mode = _ComposeMode.image),
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  _mode == _ComposeMode.image ? WynColors.sapphire : null,
              foregroundColor:
                  _mode == _ComposeMode.image ? WynColors.paper : WynColors.ink,
              side: BorderSide(
                color: _mode == _ComposeMode.image
                    ? WynColors.sapphire
                    : WynColors.hairline,
              ),
            ),
            child: const BrowserSystemText('🖼️ รูปภาพ'),
          ),
        ),
        const SizedBox(width: WynSpacing.space2),
        Expanded(
          child: OutlinedButton(
            key: const Key('club_post_poll_mode_button'),
            onPressed: _isPosting
                ? null
                : () => setState(() => _mode = _ComposeMode.poll),
            style: OutlinedButton.styleFrom(
              backgroundColor:
                  _mode == _ComposeMode.poll ? WynColors.sapphire : null,
              foregroundColor:
                  _mode == _ComposeMode.poll ? WynColors.paper : WynColors.ink,
              side: BorderSide(
                color: _mode == _ComposeMode.poll
                    ? WynColors.sapphire
                    : WynColors.hairline,
              ),
            ),
            child: const BrowserSystemText('📊 โพล'),
          ),
        ),
      ],
    );
  }

  /// WYN-115, Design Screen 1 -- replaces the image strip/"แนบรูป"/link
  /// field when [_mode] is [_ComposeMode.poll]. The content field above
  /// this (shared with image mode, see [build]) doubles as the poll's
  /// question -- no separate question field. Mirrors CreateDropScreen's
  /// own `_buildPollComposer` (WYN-035) exactly, Sapphire instead of
  /// Cyan.
  Widget _buildPollComposer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _pollOptionControllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: WynSpacing.space2),
            child: Row(
              children: [
                Expanded(
                  child: BrowserSystemTextField(
                    controller: _pollOptionControllers[i],
                    maxLength: _pollOptionMaxLength,
                    enabled: !_isPosting,
                    style: const TextStyle(fontSize: 16, color: WynColors.ink),
                    decoration: InputDecoration(
                      hint: BrowserSystemText('ตัวเลือกที่ ${i + 1}'),
                      hintStyle:
                          const TextStyle(fontSize: 16, color: WynColors.faint),
                      counter: const SizedBox.shrink(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: WynSpacing.space3,
                          vertical: WynSpacing.space2),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(WynSpacing.radiusMd),
                        borderSide: const BorderSide(color: WynColors.hairline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(WynSpacing.radiusMd),
                        borderSide: const BorderSide(color: WynColors.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(WynSpacing.radiusMd),
                        borderSide: const BorderSide(color: WynColors.sapphire),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                // Only the 3rd/4th option can be removed -- the first 2
                // are the minimum a Poll must always have.
                if (i >= _minPollOptions)
                  BrowserSystemTooltip(
                      message: 'ลบตัวเลือกนี้',
                      child: BrowserSystemTooltip(
                          message: null,
                          child: IconButton(
                            key: ValueKey('remove_club_poll_option_$i'),
                            icon: const Icon(Icons.close,
                                color: WynColors.graphite),
                            onPressed:
                                _isPosting ? null : () => _removePollOption(i),
                          ))),
              ],
            ),
          ),
        if (_pollOptionControllers.length < _maxPollOptions)
          TextButton.icon(
            onPressed: _isPosting ? null : _addPollOption,
            style: TextButton.styleFrom(foregroundColor: WynColors.sapphire),
            icon: const Icon(Icons.add, size: 18),
            label: const BrowserSystemText('เพิ่มตัวเลือก',
                style: TextStyle(fontSize: 15)),
          ),
        const SizedBox(height: WynSpacing.space2),
        const BrowserSystemText('ระยะเวลาโหวต',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: WynColors.ink)),
        const SizedBox(height: WynSpacing.space2),
        SegmentedButton<int>(
          style: SegmentedButton.styleFrom(
            selectedForegroundColor: WynColors.paper,
            selectedBackgroundColor: WynColors.sapphire,
            foregroundColor: WynColors.ink,
            side: const BorderSide(color: WynColors.hairline),
          ),
          segments: const [
            ButtonSegment(value: 1, label: BrowserSystemText('1 วัน')),
            ButtonSegment(value: 3, label: BrowserSystemText('3 วัน')),
            ButtonSegment(value: 7, label: BrowserSystemText('7 วัน')),
          ],
          selected: {_pollDurationDays},
          onSelectionChanged: _isPosting
              ? null
              : (selection) =>
                  setState(() => _pollDurationDays = selection.first),
        ),
      ],
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
              separatorBuilder: (_, __) =>
                  const SizedBox(width: WynSpacing.space2),
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
                            onTap:
                                _isPosting ? null : () => _removeImage(index),
                            customBorder: const CircleBorder(),
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: WynColors.imageScrimStrong,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(5),
                                child: Icon(Icons.close,
                                    size: 13, color: WynColors.paper),
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
            child: BrowserSystemText(
              '${_images.length}/$_maxImages',
              style: const TextStyle(fontSize: 13, color: WynColors.faint),
            ),
          ),
        ],
      ),
    );
  }
}

/// The locked "โพสต์ใน [ชื่อ Club] · #[ห้อง]" chip -- takes the same slot
/// CreateDropScreen's own (tappable) `_AudienceChip` sits in, styled as
/// plain and non-interactive since there is no destination to pick here.
/// WYN-127: the channel name is appended the same way -- the composer is
/// always locked to whichever channel it was opened from, not just
/// whichever Club.
class _LockedClubChip extends StatelessWidget {
  const _LockedClubChip({required this.clubName, required this.channelName});

  final String clubName;
  final String channelName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space3, vertical: 6),
      decoration: BoxDecoration(
        color: WynColors.hairline,
        borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_outlined,
              size: 14, color: WynColors.graphite),
          const SizedBox(width: 6),
          Flexible(
            child: BrowserSystemText(
              channelName.isEmpty
                  ? 'โพสต์ใน $clubName'
                  : 'โพสต์ใน $clubName · #$channelName',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: WynColors.graphite),
            ),
          ),
        ],
      ),
    );
  }
}

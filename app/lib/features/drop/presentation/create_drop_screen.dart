import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../follow/data/follow_repository.dart';
import '../../follow/presentation/close_friends_screen.dart';
import '../../follow/presentation/exclude_friends_screen.dart';
import '../../hashtag/data/hashtag_repository.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../moderation/data/appeal_status.dart';
import '../../moderation/data/moderation_repository.dart';
import '../../moderation/presentation/appeal_form_screen.dart';
import '../../profile/data/profile.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/widgets/avatar_circle.dart';
import '../data/drop.dart';
import '../data/drop_draft.dart';
import '../data/drop_repository.dart';
import '../data/square_crop.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/widgets/mention_input.dart';
import '../../../core/widgets/restriction_banner.dart';

/// WYN-035: a Drop carries either an image or a Poll this round, never
/// both -- see .wyn/docs/design/wyn-035-poll-in-drop.md's Screen 1.
enum _ComposeMode { image, poll }

/// WYN-036: what the close-intercept dialog's 3 buttons resolve to --
/// see .wyn/docs/design/wyn-036-draft-system.md's Screen 1. `null`
/// (the dialog dismissed with no button tapped, e.g. tapping the
/// barrier) behaves the same as [cancel].
enum _CloseAction { save, discard, cancel }

/// Screen 2 — Create Drop, restyled to `04-drop.tsx` (2026-08-29,
/// Founder-approved re-brand -- see .wyn/company/DECISIONS.md). All real
/// logic/data kept exactly as before (poll composition, drafts,
/// restriction banner, up to 9 images, mention/hashtag autocomplete) --
/// see .wyn/docs/design/wyn-005-drop.md, wyn-035-poll-in-drop.md,
/// wyn-036-draft-system.md. 3 Founder decisions (2026-08-29) on where
/// this screen and the reference disagree:
///  - Poll: the reference's toolbar has a decorative, no-op poll icon
///    (it never actually built poll composition) -- this screen's real
///    poll mode is reachable from that same toolbar position instead of
///    the old top SegmentedButton.
///  - The reference's reply-permission row ("ทุกคนสามารถตอบกลับ") has no
///    real per-post backing (only an account-level commentPermission
///    exists) -- dropped entirely rather than shown fake or reading an
///    account-level setting as if it were per-post.
///  - The reference's audience chip ("ทุกคน ⌄") has no real per-post
///    audience feature either -- kept as a static, non-interactive
///    "ทุกคน" label for visual parity, not a working dropdown.
class CreateDropScreen extends StatefulWidget {
  const CreateDropScreen({
    super.key,
    required this.dropRepository,
    ProfileRepository? profileRepository,
    HashtagRepository? hashtagRepository,
    ModerationRepository? moderationRepository,
    AppealRepository? appealRepository,
    FollowRepository? followRepository,
    this.draft,
    @visibleForTesting this.debugInitialImagesBytes,
  })  : _profileRepository = profileRepository,
        _hashtagRepository = hashtagRepository,
        _moderationRepository = moderationRepository,
        _appealRepository = appealRepository,
        _followRepository = followRepository;

  final DropRepository dropRepository;

  /// WYN-036: opens the composer prefilled with an existing Draft's
  /// content ("Continue Editing") instead of a blank one. Null for
  /// the ordinary "new Drop" entry point.
  final DropDraft? draft;

  /// WYN-094 (test-only escape hatch): seeds `_imagesBytes` directly,
  /// bypassing the real image_picker + centerCropToSquare pipeline.
  /// Exists because `image_picker`'s default `MethodChannelImagePicker`
  /// instance hangs when exercised under `AutomatedTestWidgetsFlutterBinding`
  /// in this project's sandbox (reproduced in complete isolation, with no
  /// app code involved at all -- an `ImagePickerPlatform.instance` fake +
  /// a bare `testWidgets` pump is enough to hang; the identical call
  /// sequence in a plain `test()` returns instantly) -- there is no
  /// working way to widget-test the real picker flow here today. Never
  /// read outside tests: production call sites never pass this.
  @visibleForTesting
  final List<Uint8List>? debugInitialImagesBytes;

  // Optional -- defaults to a real Supabase-backed instance (see
  // _CreateDropScreenState's late final below) so existing call sites
  // don't need to thread one through just for MentionInput. Tests
  // inject a Recording* fake here instead of touching
  // Supabase.instance. See .wyn/learning/PATTERNS.md.
  final ProfileRepository? _profileRepository;

  // Same optional/defaulted shape as _profileRepository above -- WYNOS
  // V1.0.0 Beta requirement 7 (hashtag autocomplete). Must stay optional
  // and lazily defaulted the same way: an eager `Supabase.instance.client`
  // read here would blow up any widget test that opens this screen
  // without a real Supabase.initialize() call, even one that already
  // supplies every *other* repository as a Recording* fake.
  final HashtagRepository? _hashtagRepository;

  // Same optional/defaulted shape again -- WYN-029.
  final ModerationRepository? _moderationRepository;

  // Same shape again -- WYN-030's appeal entry point on the Restrict banner.
  final AppealRepository? _appealRepository;

  // Same shape again -- WYN-097's Audience Selector (friend list for
  // "ซ่อนเพื่อนบางคน"/"เพื่อนที่สนิท").
  final FollowRepository? _followRepository;

  @override
  State<CreateDropScreen> createState() => _CreateDropScreenState();
}

class _CreateDropScreenState extends State<CreateDropScreen> {
  static const _captionMaxLength = 500;

  final _captionController = TextEditingController();
  late final ProfileRepository _profileRepository =
      widget._profileRepository ?? ProfileRepository(Supabase.instance.client);
  late final ModerationRepository _moderationRepository =
      widget._moderationRepository ??
          ModerationRepository(Supabase.instance.client);
  late final AppealRepository _appealRepository =
      widget._appealRepository ?? AppealRepository(Supabase.instance.client);
  late final FollowRepository _followRepository =
      widget._followRepository ?? FollowRepository(Supabase.instance.client);
  Set<String> _mentionedUserIds = {};

  // WYN-097: who can see this Drop -- see AudienceOption's own doc
  // comment. [_excludedFriendIds] only matters when [_audience] is
  // AudienceOption.friendsExcept -- kept here (parent state), not
  // ExcludeFriendsScreen's own local state, so a 2nd visit to that
  // screen in the same composing session shows what was already
  // selected (Design spec's Screen 3 "กลับมาจาก Screen 3 ครั้งที่ 2").
  AudienceOption _audience = AudienceOption.everyone;
  Set<String> _excludedFriendIds = {};

  // 04-drop.tsx's header avatar -- fetched once, best-effort (a failed
  // fetch just leaves the avatar on its fallback-letter state, same
  // fail-open posture as every other identity-summary fetch in this
  // codebase, e.g. SideMenu's own _load()).
  Profile? _ownProfile;

  // WYN-071: 1-9 images (was a single Uint8List?/String pair) --
  // parallel lists, same order the preview grid shows them in. Both
  // always the same length; kept as two lists rather than a list of
  // records to minimize the diff against every other place in this
  // file that already threaded bytes/extension separately.
  final List<Uint8List> _imagesBytes = [];
  final List<String> _imageExtensions = [];
  static const _maxImages = 9;

  bool _isCropping = false;

  bool _isSharing = false;
  String? _errorMessage;

  // WYN-094: how many of _imagesBytes have finished uploading during
  // the in-flight _share() call -- drives the progress bar below the
  // header. Real progress (bumped by DropRepository.createDrop's own
  // onImageUploaded callback after each image actually finishes, not
  // a fake timer). Only meaningful while _isSharing; reset at the
  // start of each _share() call.
  int _uploadedImageCount = 0;

  // WYN-035: Poll composer state. Starts at 2 options (the minimum),
  // capped at 4 by _addPollOption -- see .wyn/tasks/active/WYN-035-poll-in-drop.md.
  _ComposeMode _mode = _ComposeMode.image;
  static const _maxPollOptions = 4;
  static const _minPollOptions = 2;
  static const _pollOptionMaxLength = 80;
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  int _pollDurationDays = 1;

  // WYN-036: set when opened from an existing Draft (widget.draft) --
  // null means "brand new, never saved." Once a save succeeds (either
  // the first one, which inserts, or any later one, which updates in
  // place) this is set to that draft's id so every subsequent save in
  // the same editing session targets the same row instead of
  // inserting a duplicate.
  String? _draftId;

  // WYN-036: an already-uploaded image carried over from a Draft --
  // never re-uploaded unless the user picks a new one (which clears
  // this and sets _imageBytes instead). Null for a brand-new Drop or
  // a poll-mode draft.
  String? _existingImageUrl;
  bool _isSavingDraft = false;

  // WYN-029 (Restrict): loaded once in initState, not re-polled while
  // this screen stays open -- see RestrictionBanner's own doc comment
  // on why a stale read here is an accepted, documented trade-off (the
  // real enforcement is server-side RLS regardless of what this screen
  // shows).
  String? _restrictReason;
  DateTime? _restrictExpiresAt;
  String? _restrictActionId;
  AppealStatus _restrictAppealStatus = AppealStatus.none;
  bool get _isRestricted => _restrictExpiresAt != null;

  /// WYNOS V1.0.0 Beta requirement 2: image mode no longer requires a
  /// photo -- an image alone, a caption alone, or both together are all
  /// shareable. Only "neither" is blocked (the old behavior always
  /// required a photo; text-only Drops are new).
  bool get _canShare {
    if (_isSharing || _isCropping || _isRestricted) return false;
    if (_mode == _ComposeMode.image) {
      return _imagesBytes.isNotEmpty ||
          _existingImageUrl != null ||
          _captionController.text.trim().isNotEmpty;
    }
    return _captionController.text.trim().isNotEmpty && _pollOptionsValid;
  }

  /// WYN-036: whether closing right now would lose something --
  /// drives the close-intercept dialog (Screen 1). Deliberately looser
  /// than [_canShare]/[_pollOptionsValid]: a single typed character or
  /// one filled-in poll option is "unsaved content" worth offering to
  /// keep, even though it's nowhere near ready to publish.
  bool get _hasUnsavedContent {
    if (_mode == _ComposeMode.image) {
      return _imagesBytes.isNotEmpty ||
          _existingImageUrl != null ||
          _captionController.text.trim().isNotEmpty;
    }
    return _captionController.text.trim().isNotEmpty ||
        _pollOptionControllers.any((c) => c.text.trim().isNotEmpty);
  }

  /// Every option non-empty (after trim) and within
  /// [_pollOptionMaxLength], and no two options equal
  /// case-insensitively after trim -- mirrors `valid_poll_options()`
  /// in supabase/schema.sql (that's the real enforcement; this is
  /// just so the "โพสต์" button doesn't invite a doomed request).
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
    _prefillFromDraft();
    final debugBytes = widget.debugInitialImagesBytes;
    if (debugBytes != null) {
      _imagesBytes.addAll(debugBytes);
      _imageExtensions.addAll(List.filled(debugBytes.length, 'png'));
    }
    _loadModerationStatus();
    _loadOwnProfile();
    // WYN-035: in poll mode _canShare depends on the caption text (the
    // poll's question) -- image mode never needed this since it only
    // ever depended on _imageBytes, which already goes through setState.
    _captionController.addListener(_onCaptionChanged);
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

  /// WYN-036 ("Continue Editing"): copies a Draft's saved content into
  /// this screen's own state, as if the user had just typed/picked it
  /// themselves. Called once, before the first build -- everything
  /// after this point behaves exactly like composing from scratch
  /// (same _canShare/_hasUnsavedContent/_share() paths, no special
  /// "draft mode" branching anywhere else in this file).
  void _prefillFromDraft() {
    final draft = widget.draft;
    if (draft == null) return;

    _draftId = draft.id;
    _existingImageUrl = draft.imageUrl;
    if (draft.caption != null) _captionController.text = draft.caption!;

    final pollOptions = draft.pollOptions;
    if (pollOptions != null) {
      _mode = _ComposeMode.poll;
      // Replace the 2 eagerly-created default controllers -- dispose
      // them first so they don't leak, same discipline
      // _removePollOption already follows.
      for (final controller in _pollOptionControllers) {
        controller.dispose();
      }
      _pollOptionControllers
        ..clear()
        ..addAll(
            pollOptions.map((option) => TextEditingController(text: option)));
      _pollDurationDays = draft.pollDurationDays ?? 1;
    }
  }

  void _onCaptionChanged() {
    if (mounted) setState(() {});
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
      // Silent -- fails open, same posture as AuthGate's own moderation
      // status check. The RLS INSERT guard still rejects the actual
      // post attempt regardless of whether this banner managed to show.
    }
  }

  // WYN-030: no re-poll while this screen stays open once the appeal is
  // submitted -- initState's one-time check above already accepted this
  // trade-off for expiry; submitting an appeal just needs the banner to
  // flip from "อุทธรณ์" to "อยู่ระหว่างพิจารณาอุทธรณ์" the same way.
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
    _captionController.removeListener(_onCaptionChanged);
    _captionController.dispose();
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

  /// WYN-071: a single image (camera). A freshly picked image clears
  /// [_existingImageUrl] the same way it always did pre-multi-image (a
  /// Draft's carried-over image and a fresh multi-image pick never mix
  /// -- see that field's doc comment).
  Future<void> _pickImage(ImageSource source) async {
    // Guards the same race the "โพสต์" button guards against (see
    // .wyn/tasks/bugs/WYN-004-feed-and-post.md, QA round 1): without
    // this, a rapid double-tap on the toolbar's camera icon could
    // reopen the picker while the previous pick is still being cropped.
    if (_isCropping) return;
    // WYN-103: the toolbar icon stays tappable at 9/9 (see the toolbar's
    // `enabled:` -- it never gates on _imagesBytes.length) so a SnackBar
    // is reachable here, rather than the icon just going inert/disabled
    // with no explanation.
    if (_imagesBytes.length >= _maxImages) {
      _showImageLimitSnackBar();
      return;
    }

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
        _imagesBytes.add(cropped);
        _imageExtensions.add('png');
        _existingImageUrl = null;
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

  /// WYN-071: gallery multi-select, capped via [ImagePicker.limit] --
  /// the OS picker itself refuses to let the user select more than
  /// that many, which is simpler and clearer feedback than letting them
  /// over-select and then silently trimming the result afterward.
  Future<void> _pickMultipleImages() async {
    if (_isCropping) return;
    if (_imagesBytes.length >= _maxImages) {
      _showImageLimitSnackBar();
      return;
    }

    final remaining = _maxImages - _imagesBytes.length;
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      limit: remaining,
    );
    if (picked.isEmpty) return;

    setState(() => _isCropping = true);
    try {
      final croppedList = <Uint8List>[];
      // WYN-103 Edge Case 2: `limit` above is the native picker's own
      // cap, which isn't honored on every platform -- truncate again
      // here so _imagesBytes can never exceed _maxImages regardless.
      for (final file in picked.take(remaining)) {
        final rawBytes = await file.readAsBytes();
        croppedList.add(await centerCropToSquare(rawBytes));
      }
      if (!mounted) return;
      setState(() {
        _imagesBytes.addAll(croppedList);
        _imageExtensions.addAll(List.filled(croppedList.length, 'png'));
        _existingImageUrl = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'เลือกรูปไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isCropping = false);
    }
  }

  /// WYN-071.
  void _removeImage(int index) {
    setState(() {
      _imagesBytes.removeAt(index);
      _imageExtensions.removeAt(index);
    });
  }

  /// WYN-103: shown instead of the toolbar's photo/camera icon just
  /// silently doing nothing once `_imagesBytes` is already at
  /// `_maxImages` -- a disabled-looking-but-not-actually-disabled icon
  /// is confusing on its own.
  void _showImageLimitSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('เพิ่มรูปได้สูงสุด 9 รูปต่อโพสต์')),
    );
  }

  /// WYN-097, Design spec Screen 2 -- opens the 5-option Audience
  /// Selector sheet. "ทุกคน"/"เพื่อน"/"เฉพาะฉัน" apply immediately;
  /// "ซ่อนเพื่อนบางคน"/"เพื่อนที่สนิท" hand off to a follow-up screen
  /// each (see [_openExcludeFriends]/[_openCloseFriendsForAudience]).
  Future<void> _showAudiencePicker() async {
    final selected = await showModalBottomSheet<AudienceOption>(
      context: context,
      builder: (sheetContext) => _AudiencePickerSheet(currentValue: _audience),
    );
    if (selected == null || !mounted) return;

    switch (selected) {
      case AudienceOption.friendsExcept:
        await _openExcludeFriends();
      case AudienceOption.closeFriends:
        await _openCloseFriendsForAudience();
      case AudienceOption.everyone:
      case AudienceOption.friends:
      case AudienceOption.onlyMe:
        setState(() => _audience = selected);
    }
  }

  /// Design spec Screen 3 -- multi-select "เพื่อนที่จะซ่อน", per-post
  /// (not persisted). Carries [_excludedFriendIds] in as
  /// [ExcludeFriendsScreen.initiallySelected] so a 2nd visit in the
  /// same composing session shows what was already picked.
  Future<void> _openExcludeFriends() async {
    final result = await Navigator.of(context).push<Set<String>>(
      MaterialPageRoute(
        builder: (_) => ExcludeFriendsScreen(
          followRepository: _followRepository,
          initiallySelected: _excludedFriendIds,
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _audience = AudienceOption.friendsExcept;
      _excludedFriendIds = result;
    });
  }

  /// Design spec Screen 2/4 -- "เพื่อนที่สนิท" the very first time it's
  /// picked (empty list) routes through CloseFriendsScreen's welcome
  /// banner first, rather than selecting immediately -- a Drop posted
  /// with audience = close_friends against an empty list would be
  /// visible to nobody but the author, a confusing silent trap. Once a
  /// list already exists, picking this option again just selects it
  /// immediately, same as "ทุกคน"/"เพื่อน"/"เฉพาะฉัน".
  Future<void> _openCloseFriendsForAudience() async {
    List<Profile> existingCloseFriends;
    try {
      existingCloseFriends = await _followRepository.fetchCloseFriends();
    } catch (_) {
      existingCloseFriends = [];
    }
    if (!mounted) return;

    if (existingCloseFriends.isEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CloseFriendsScreen(
            followRepository: _followRepository,
            showWelcomeBanner: true,
          ),
        ),
      );
      if (!mounted) return;
    }
    setState(() => _audience = AudienceOption.closeFriends);
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ฟีเจอร์นี้จะเปิดใช้งานเร็ว ๆ นี้')),
    );
  }

  Future<void> _share() async {
    // The "โพสต์" button's onPressed is only disabled on the *next*
    // rebuild (setState schedules it, it doesn't happen synchronously),
    // so a rapid double-tap before that rebuild would otherwise still
    // reach this method a second time. See .wyn/tasks/bugs/WYN-004-feed-and-post.md
    // (QA round 1) for the bug class this guards against.
    if (!_canShare) return;

    setState(() {
      _isSharing = true;
      _errorMessage = null;
      _uploadedImageCount = 0;
    });

    try {
      if (_mode == _ComposeMode.poll) {
        await widget.dropRepository.createPollDrop(
          question: _captionController.text,
          options: _pollOptionControllers.map((c) => c.text.trim()).toList(),
          durationDays: _pollDurationDays,
          mentionedUserIds: _mentionedUserIds,
          audience: _audience,
          excludedFriendIds: _excludedFriendIds,
        );
      } else {
        final existingImageUrl = _existingImageUrl;
        if (_imagesBytes.isNotEmpty) {
          await widget.dropRepository.createDrop(
            imagesBytes: _imagesBytes,
            imageExtensions: _imageExtensions,
            caption: _captionController.text,
            mentionedUserIds: _mentionedUserIds,
            audience: _audience,
            excludedFriendIds: _excludedFriendIds,
            onImageUploaded: (uploaded, total) {
              if (mounted) setState(() => _uploadedImageCount = uploaded);
            },
          );
        } else if (existingImageUrl != null) {
          // WYN-036: continuing a Draft without picking a new image --
          // the image is already uploaded (from when the Draft was
          // saved), so publish from that URL directly instead of
          // re-uploading bytes we don't have.
          await widget.dropRepository.createDropFromExistingImage(
            imageUrl: existingImageUrl,
            caption: _captionController.text,
            mentionedUserIds: _mentionedUserIds,
            audience: _audience,
            excludedFriendIds: _excludedFriendIds,
          );
        } else {
          // WYNOS V1.0.0 Beta requirement 2: no image at all -- _canShare
          // only allows reaching this branch when the caption is non-empty.
          await widget.dropRepository.createTextDrop(
            caption: _captionController.text,
            mentionedUserIds: _mentionedUserIds,
            audience: _audience,
            excludedFriendIds: _excludedFriendIds,
          );
        }
      }

      // WYN-036: a successful publish retires the Draft it came from
      // -- best-effort, not blocking: the real Drop is already
      // created, which matters more than tidying up the Draft row.
      final draftId = _draftId;
      if (draftId != null) {
        try {
          await widget.dropRepository.deleteDraft(draftId);
        } catch (_) {
          // Ignored -- see comment above.
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'แชร์ไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  /// WYN-036, Screen 1 -- the sole entry point for both the header's
  /// "ยกเลิก" button and the system back gesture (via the PopScope
  /// wrapping [build]'s Scaffold). A direct `Navigator.pop()` call
  /// always succeeds regardless of PopScope's `canPop` (only
  /// `maybePop()`/the system back gesture consult it), so every branch
  /// below can just call it once it's decided the screen should
  /// actually close.
  Future<void> _handleClose() async {
    if (_isSharing || _isSavingDraft) return;

    if (!_hasUnsavedContent) {
      Navigator.of(context).pop(false);
      return;
    }

    final action = await showDialog<_CloseAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('บันทึกเป็นร่างก่อนออกไหม?'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_CloseAction.discard),
            child: const Text('ทิ้ง'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_CloseAction.cancel),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_CloseAction.save),
            child: const Text('บันทึกร่าง'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    switch (action) {
      case _CloseAction.discard:
        Navigator.of(context).pop(false);
      case _CloseAction.save:
        await _saveDraftAndClose();
      case _CloseAction.cancel:
      case null:
        // Stay on this screen -- nothing to do.
        break;
    }
  }

  /// WYN-036: inserts a new draft row, or updates the one this screen
  /// was opened from ([_draftId]) in place -- never a duplicate on a
  /// second save within the same editing session.
  Future<void> _saveDraftAndClose() async {
    setState(() => _isSavingDraft = true);
    try {
      // Gated by _mode so a leftover _imageBytes/_existingImageUrl from
      // before switching to โพล mode (the toolbar toggle never clears
      // them -- see onSelectionChanged above) can't leak an image_url
      // into a poll draft, and vice versa.
      final isImageMode = _mode == _ComposeMode.image;
      // WYN-071: Drafts stay single-image only this round (non-goal --
      // see the Design doc) -- only the first picked image, if any, is
      // saved. A multi-image pick can still be drafted; resuming it
      // just resumes with 1 image instead of all of them, same as
      // resuming any other draft always meant "pick up roughly where
      // you left off," not a byte-for-byte snapshot.
      await widget.dropRepository.saveDraft(
        draftId: _draftId,
        imageBytes: isImageMode && _imagesBytes.isNotEmpty
            ? _imagesBytes.first
            : null,
        imageExtension:
            _imageExtensions.isNotEmpty ? _imageExtensions.first : 'jpg',
        existingImageUrl:
            isImageMode && _imagesBytes.isEmpty ? _existingImageUrl : null,
        caption: _captionController.text,
        pollOptions: _mode == _ComposeMode.poll
            ? _pollOptionControllers.map((c) => c.text.trim()).toList()
            : null,
        pollDurationDays: _mode == _ComposeMode.poll ? _pollDurationDays : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกร่างไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // WYN-036: canPop stays false while there's unsaved content so the
    // system back gesture/button routes through _handleClose() too
    // (via onPopInvokedWithResult) -- the header's "ยกเลิก" button below
    // always calls _handleClose() directly regardless, since a direct
    // Navigator.pop() call bypasses canPop entirely (only
    // maybePop()/the system back gesture consult it).
    return PopScope<bool>(
      canPop: !_hasUnsavedContent,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleClose();
      },
      child: Scaffold(
        backgroundColor: WynColors.paper,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Divider(height: 1, color: WynColors.hairline),
              if (_isSharing && _imagesBytes.isNotEmpty) _buildUploadProgress(),
              if (_isRestricted)
                RestrictionBanner(
                  reason: _restrictReason,
                  expiresAt: _restrictExpiresAt,
                  actionId: _restrictActionId,
                  appealStatus: _restrictAppealStatus,
                  onAppeal: _openAppeal,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(WynSpacing.space4,
                      WynSpacing.space4, WynSpacing.space4, WynSpacing.space4),
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
                            _AudienceChip(
                              value: _audience,
                              onTap: _isSharing ? null : _showAudiencePicker,
                            ),
                            const SizedBox(height: WynSpacing.space3),
                            // Shared between both modes -- doubles as the
                            // Poll's question when _mode is poll (same
                            // role it always played, just reordered to
                            // render before the image strip/poll options
                            // now, matching 04-drop.tsx's textarea-then-
                            // attachments order instead of the old
                            // attachments-then-caption order).
                            MentionInput(
                              controller: _captionController,
                              profileRepository: _profileRepository,
                              hashtagRepository: widget._hashtagRepository,
                              onMentionedUsersChanged: (ids) =>
                                  setState(() => _mentionedUserIds = ids),
                              maxLength: _captionMaxLength,
                              maxLines: null,
                              minLines: 3,
                              enabled: !_isSharing,
                              style: const TextStyle(
                                  fontSize: 20, color: WynColors.ink, height: 1.4),
                              decoration: InputDecoration(
                                hintText: _mode == _ComposeMode.poll
                                    ? 'ตั้งคำถามโพล...'
                                    : 'มีอะไรเกิดขึ้นบ้าง',
                                hintStyle: const TextStyle(
                                    fontSize: 20, color: WynColors.faint, height: 1.4),
                                border: InputBorder.none,
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                            ),
                            if (_mode == _ComposeMode.image)
                              _buildImageStrip()
                            else
                              _buildPollComposer(),
                            if (_captionController.text.length >
                                _captionMaxLength * 0.8)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: WynSpacing.space1),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${_captionMaxLength - _captionController.text.length}',
                                    style: const TextStyle(
                                        fontSize: 13, color: WynColors.sapphire),
                                  ),
                                ),
                              ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: WynSpacing.space2),
                              Text(
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
              _buildToolbar(),
            ],
          ),
        ),
      ),
    );
  }

  // 04-drop.tsx's header: "ยกเลิก" plain text (left) -- filled pill
  // "โพสต์" (right), sapphire when there's content to post, hairline/
  // flat when disabled. No center title -- deliberately not an AppBar
  // (no leading icon slot needed for a text-only cancel action).
  // WYN-094: only shown while actually uploading image bytes (a
  // caption/Poll-only Drop publishes fast enough that a real progress
  // bar wouldn't reflect anything meaningful -- see
  // wyn-094-upload-progress-indicator.md's "เงื่อนไขการแสดงแถบ"). The
  // percent is derived from _uploadedImageCount, which only advances
  // when DropRepository.createDrop's onImageUploaded callback fires
  // for a real finished upload -- never a fake/animated value.
  Widget _buildUploadProgress() {
    final total = _imagesBytes.length;
    final percent = ((_uploadedImageCount / total) * 100).round();
    return Semantics(
      label:
          'กำลังอัปโหลด $_uploadedImageCount จาก $total รูป, $percent เปอร์เซ็นต์',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                WynSpacing.space4, 0, WynSpacing.space4, WynSpacing.space1),
            child: Text(
              'กำลังอัปโหลด $_uploadedImageCount/$total รูป... $percent%',
              style: const TextStyle(fontSize: 13, color: WynColors.graphite),
            ),
          ),
          SizedBox(
            height: 3,
            child: LinearProgressIndicator(
              value: _uploadedImageCount / total,
              backgroundColor: WynColors.hairline,
              color: WynColors.sapphire,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          WynSpacing.space4, WynSpacing.space2, WynSpacing.space4, WynSpacing.space3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            key: const Key('cancel_button'),
            onPressed: _handleClose,
            style: TextButton.styleFrom(
              foregroundColor: WynColors.ink,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('ยกเลิก', style: TextStyle(fontSize: 15, color: WynColors.ink)),
          ),
          Semantics(
            label: _isRestricted
                ? 'โพสต์ ปิดใช้งานเนื่องจากบัญชีถูกจำกัดการโพสต์ชั่วคราว'
                : null,
            excludeSemantics: _isRestricted,
            child: TextButton(
              key: const Key('post_button'),
              onPressed: _canShare ? _share : null,
              style: TextButton.styleFrom(
                backgroundColor: _canShare ? WynColors.sapphire : WynColors.hairline,
                foregroundColor: _canShare ? WynColors.paper : WynColors.mutedNeutral,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                shape: const StadiumBorder(),
              ),
              child: _isSharing
                  ? SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _canShare ? WynColors.paper : WynColors.mutedNeutral,
                      ),
                    )
                  : const Text('โพสต์',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // 04-drop.tsx's ImageStrip: a horizontal scroll of picked images, each
  // its own remove button -- rendered only when non-empty (no dashed
  // empty-state box; picking an image is toolbar-only now, per the
  // reference's "attachments are optional tools reached through a
  // toolbar" direction). Draft continuation's already-uploaded image
  // (WYN-036) renders the same way, as a single-item strip.
  Widget _buildImageStrip() {
    final existingImageUrl = _existingImageUrl;

    if (existingImageUrl != null && _imagesBytes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: WynSpacing.space3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
          child: SizedBox(
            width: 128,
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Semantics(
                  label: 'รูปที่เลือก',
                  child: Container(
                    color: WynColors.hairline,
                    child: _isCropping
                        ? const Center(child: CircularProgressIndicator())
                        : Image.network(existingImageUrl, fit: BoxFit.cover),
                  ),
                ),
                _buildRemoveButton(
                    onTap: () => setState(() => _existingImageUrl = null)),
              ],
            ),
          ),
        ),
      );
    }

    if (_imagesBytes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: WynSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isCropping) const LinearProgressIndicator(),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _imagesBytes.length,
              separatorBuilder: (_, __) => const SizedBox(width: WynSpacing.space2),
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
                child: SizedBox(
                  width: 128,
                  height: 160,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(_imagesBytes[index], fit: BoxFit.cover),
                      _buildRemoveButton(onTap: () => _removeImage(index)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: WynSpacing.space1),
            child: Text(
              '${_imagesBytes.length}/$_maxImages',
              style: const TextStyle(fontSize: 13, color: WynColors.faint),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoveButton({required VoidCallback onTap}) {
    return Positioned(
      top: 8,
      right: 8,
      child: Semantics(
        label: 'ลบรูปนี้',
        button: true,
        excludeSemantics: true,
        child: InkWell(
          onTap: _isSharing ? null : onTap,
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
    );
  }

  /// WYN-035, Design Screen 1 -- replaces the image strip when [_mode]
  /// is [_ComposeMode.poll]. The caption field above this (shared with
  /// image mode, see [build]) doubles as the poll's question -- no
  /// separate question field.
  Widget _buildPollComposer() {
    return Padding(
      padding: const EdgeInsets.only(top: WynSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _pollOptionControllers.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: WynSpacing.space2),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pollOptionControllers[i],
                      maxLength: _pollOptionMaxLength,
                      enabled: !_isSharing,
                      style: const TextStyle(fontSize: 16, color: WynColors.ink),
                      decoration: InputDecoration(
                        hintText: 'ตัวเลือกที่ ${i + 1}',
                        hintStyle: const TextStyle(fontSize: 16, color: WynColors.faint),
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: WynSpacing.space3, vertical: WynSpacing.space2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
                          borderSide: const BorderSide(color: WynColors.hairline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
                          borderSide: const BorderSide(color: WynColors.hairline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
                          borderSide: const BorderSide(color: WynColors.sapphire),
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  // Only the 3rd/4th option can be removed -- the
                  // first 2 are the minimum a Poll must always have.
                  if (i >= _minPollOptions)
                    IconButton(
                      key: ValueKey('remove_poll_option_$i'),
                      icon: const Icon(Icons.close, color: WynColors.graphite),
                      tooltip: 'ลบตัวเลือกนี้',
                      onPressed: _isSharing ? null : () => _removePollOption(i),
                    ),
                ],
              ),
            ),
          if (_pollOptionControllers.length < _maxPollOptions)
            TextButton.icon(
              onPressed: _isSharing ? null : _addPollOption,
              style: TextButton.styleFrom(foregroundColor: WynColors.sapphire),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('เพิ่มตัวเลือก', style: TextStyle(fontSize: 15)),
            ),
          const SizedBox(height: WynSpacing.space2),
          const Text('ระยะเวลาโหวต',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: WynColors.ink)),
          const SizedBox(height: WynSpacing.space2),
          SegmentedButton<int>(
            style: SegmentedButton.styleFrom(
              selectedForegroundColor: WynColors.paper,
              selectedBackgroundColor: WynColors.sapphire,
              foregroundColor: WynColors.ink,
              side: const BorderSide(color: WynColors.hairline),
            ),
            segments: const [
              ButtonSegment(value: 1, label: Text('1 วัน')),
              ButtonSegment(value: 3, label: Text('3 วัน')),
              ButtonSegment(value: 7, label: Text('7 วัน')),
            ],
            selected: {_pollDurationDays},
            onSelectionChanged: _isSharing
                ? null
                : (selection) =>
                    setState(() => _pollDurationDays = selection.first),
          ),
        ],
      ),
    );
  }

  // 04-drop.tsx's bottom toolbar: photo (gallery, multi-select) /
  // camera (single shot) / poll (toggles _mode, replacing the old top
  // SegmentedButton -- Founder decision 2026-08-29) / location
  // (placeholder -- drops.location has no UI reading/writing it yet
  // anywhere in the app, see supabase/schema.sql's own comment on that
  // column). Photo/camera disabled in poll mode (a Drop carries either
  // an image or a Poll, never both) and while sharing/cropping.
  Widget _buildToolbar() {
    final imageDisabled = _isSharing || _isCropping || _mode == _ComposeMode.poll;
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: WynColors.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: WynSpacing.space4, vertical: WynSpacing.space3),
        child: Row(
          children: [
            _ToolbarIcon(
              key: const Key('toolbar_photo_button'),
              icon: Icons.image_outlined,
              enabled: !imageDisabled,
              onTap: _pickMultipleImages,
              semanticsLabel: 'แนบรูปจากคลังภาพ',
            ),
            const SizedBox(width: WynSpacing.space5),
            _ToolbarIcon(
              key: const Key('toolbar_camera_button'),
              icon: Icons.camera_alt_outlined,
              enabled: !imageDisabled,
              onTap: () => _pickImage(ImageSource.camera),
              semanticsLabel: 'ถ่ายรูปใหม่',
            ),
            const SizedBox(width: WynSpacing.space5),
            _ToolbarIcon(
              key: const Key('toolbar_poll_button'),
              icon: Icons.bar_chart,
              enabled: !_isSharing,
              active: _mode == _ComposeMode.poll,
              onTap: () => setState(() => _mode =
                  _mode == _ComposeMode.poll ? _ComposeMode.image : _ComposeMode.poll),
              semanticsLabel: _mode == _ComposeMode.poll ? 'ยกเลิกโพล' : 'สร้างโพล',
            ),
            const SizedBox(width: WynSpacing.space5),
            _ToolbarIcon(
              key: const Key('toolbar_location_button'),
              icon: Icons.location_on_outlined,
              enabled: true,
              onTap: _showComingSoon,
              semanticsLabel: 'เพิ่มตำแหน่งที่ตั้ง',
            ),
          ],
        ),
      ),
    );
  }
}

/// WYN-097, Design spec Screen 1 -- was a static "ทุกคน ⌄" label with no
/// state/interaction; now a real trigger for [_showAudiencePicker]
/// whose label tracks the current [AudienceOption]. Same container/
/// border/radius as the reference's original static chip -- only the
/// text and the `InkWell`/tap handler are new.
String audienceOptionLabel(AudienceOption value) => switch (value) {
      AudienceOption.everyone => 'ทุกคน',
      AudienceOption.friends => 'เพื่อน',
      AudienceOption.friendsExcept => 'ซ่อนเพื่อนบางคน',
      AudienceOption.closeFriends => 'เพื่อนที่สนิท',
      AudienceOption.onlyMe => 'เฉพาะฉัน',
    };

String audienceOptionDescription(AudienceOption value) => switch (value) {
      AudienceOption.everyone => 'ทุกคนเห็นโพสต์นี้ได้',
      AudienceOption.friends => 'เฉพาะเพื่อนของคุณเท่านั้นที่เห็นได้',
      AudienceOption.friendsExcept => 'เพื่อนทุกคนเห็นได้ ยกเว้นคนที่คุณเลือกซ่อน',
      AudienceOption.closeFriends => 'เฉพาะเพื่อนที่สนิทที่คุณเลือกไว้เท่านั้น',
      AudienceOption.onlyMe => 'เห็นเฉพาะคุณคนเดียว',
    };

IconData _audienceOptionIcon(AudienceOption value) => switch (value) {
      AudienceOption.everyone => Icons.public,
      AudienceOption.friends => Icons.people_outline,
      AudienceOption.friendsExcept => Icons.person_off_outlined,
      AudienceOption.closeFriends => Icons.star_outline,
      AudienceOption.onlyMe => Icons.lock_outline,
    };

class _AudienceChip extends StatelessWidget {
  const _AudienceChip({required this.value, required this.onTap});

  final AudienceOption value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'เลือกกลุ่มผู้ชมโพสต์ ตอนนี้เลือก ${audienceOptionLabel(value)}',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: WynSpacing.space3, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1EFE9),
            border: Border.all(color: WynColors.hairline),
            borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(audienceOptionLabel(value),
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: WynColors.ink)),
              const SizedBox(width: 2),
              const Icon(Icons.keyboard_arrow_down, size: 13, color: WynColors.graphite),
            ],
          ),
        ),
      ),
    );
  }
}

/// WYN-097, Design spec Screen 2 -- the 5-option Audience Selector
/// sheet. Same drag-handle/title/close-button structure as
/// `_showPermissionPicker` (settings_screen.dart), duplicated rather
/// than shared across the two files (Settings and Drop are separate
/// features in this codebase, same posture as every other
/// intentionally-not-shared bottom-sheet builder here) -- the part
/// that's actually new is the icon+subtitle per row, and the 2 options
/// ("ซ่อนเพื่อนบางคน"/"เพื่อนที่สนิท") that show a `chevron_right`
/// instead of a radio because they hand off to a follow-up screen
/// (see [_CreateDropScreenState._showAudiencePicker]) rather than
/// applying immediately.
class _AudiencePickerSheet extends StatelessWidget {
  const _AudiencePickerSheet({required this.currentValue});

  final AudienceOption currentValue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
        // Design spec's Responsive Behavior: 5 rows+subtitle is taller
        // than the 3-row permission picker this is otherwise modeled
        // on -- can overflow a short screen height. SingleChildScrollView
        // wraps the whole sheet body (header included) rather than just
        // the row list, the simpler of the two shapes Flutter's modal
        // bottom sheet sizing (bounded, not unbounded, height) actually
        // supports without extra plumbing -- the header only scrolls
        // away too on a screen short enough that this matters at all.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: WynSpacing.space2),
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: WynSpacing.space4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(WynSpacing.radiusFull),
                  ),
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text('ใครเห็นโพสต์นี้ได้บ้าง',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  SizedBox(
                    width: WynSpacing.touchTargetMin,
                    height: WynSpacing.touchTargetMin,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close),
                      tooltip: 'ปิด',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: WynSpacing.space2),
              for (final option in AudienceOption.values)
              Semantics(
                label:
                    '${audienceOptionLabel(option)} — ${audienceOptionDescription(option)}',
                selected: option == currentValue,
                excludeSemantics: true,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_audienceOptionIcon(option)),
                  title: Text(audienceOptionLabel(option)),
                  subtitle: Text(audienceOptionDescription(option)),
                  // "ซ่อนเพื่อนบางคน"/"เพื่อนที่สนิท" always show both a
                  // radio (when currently selected) and a chevron
                  // (Design spec's "โชว์ทั้ง radio (checked) และ chevron
                  // คู่กัน" -- signals "selected" AND "tap to edit the
                  // list" at once for those 2 options specifically).
                  trailing: switch (option) {
                    AudienceOption.friendsExcept || AudienceOption.closeFriends =>
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (option == currentValue)
                            Icon(Icons.radio_button_checked,
                                color: Theme.of(context).colorScheme.primary),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    _ => Icon(
                        option == currentValue
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: option == currentValue
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                  },
                  onTap: () => Navigator.of(context).pop(option),
                ),
              ),
              const SizedBox(height: WynSpacing.space4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.semanticsLabel,
    this.active = false,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String semanticsLabel;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = !enabled
        ? WynColors.faint
        : active
            ? WynColors.sapphire
            : WynColors.sapphire;
    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            decoration: active
                ? const BoxDecoration(
                    color: WynColors.sapphireRing,
                    shape: BoxShape.circle,
                  )
                : null,
            padding: active ? const EdgeInsets.all(4) : const EdgeInsets.all(0),
            child: Icon(icon, size: 19, color: color),
          ),
        ),
      ),
    );
  }
}

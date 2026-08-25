import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../hashtag/data/hashtag_repository.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../moderation/data/appeal_status.dart';
import '../../moderation/data/moderation_repository.dart';
import '../../moderation/presentation/appeal_form_screen.dart';
import '../../profile/data/profile_repository.dart';
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

/// Screen 2 — Create Drop.
/// See .wyn/docs/design/wyn-005-drop.md, .wyn/docs/design/wyn-035-poll-in-drop.md,
/// .wyn/docs/design/wyn-036-draft-system.md
class CreateDropScreen extends StatefulWidget {
  const CreateDropScreen({
    super.key,
    required this.dropRepository,
    ProfileRepository? profileRepository,
    HashtagRepository? hashtagRepository,
    ModerationRepository? moderationRepository,
    AppealRepository? appealRepository,
    this.draft,
  })  : _profileRepository = profileRepository,
        _hashtagRepository = hashtagRepository,
        _moderationRepository = moderationRepository,
        _appealRepository = appealRepository;

  final DropRepository dropRepository;

  /// WYN-036: opens the composer prefilled with an existing Draft's
  /// content ("Continue Editing") instead of a blank one. Null for
  /// the ordinary "new Drop" entry point.
  final DropDraft? draft;

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
  Set<String> _mentionedUserIds = {};

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
  /// just so the "แชร์" button doesn't invite a doomed request).
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
    _loadModerationStatus();
    // WYN-035: in poll mode _canShare depends on the caption text (the
    // poll's question) -- image mode never needed this since it only
    // ever depended on _imageBytes, which already goes through setState.
    _captionController.addListener(_onCaptionChanged);
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

  /// WYN-071: appends a single image (camera only -- gallery goes
  /// through [_pickMultipleImages] instead, see [_showImageSourceSheet]).
  /// A freshly picked image clears [_existingImageUrl] the same way it
  /// always did pre-multi-image (a Draft's carried-over image and a
  /// fresh multi-image pick never mix -- see that field's doc comment).
  Future<void> _pickImage(ImageSource source) async {
    // Guards the same race the "แชร์" button guards against (see
    // .wyn/tasks/bugs/WYN-004-feed-and-post.md, QA round 1): without
    // this, the image area's onTap could reopen the picker sheet while
    // the previous pick is still being cropped.
    if (_isCropping || _imagesBytes.length >= _maxImages) return;

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
    if (_isCropping || _imagesBytes.length >= _maxImages) return;

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
      for (final file in picked) {
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
                _pickMultipleImages();
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
    if (!_canShare) return;

    setState(() {
      _isSharing = true;
      _errorMessage = null;
    });

    try {
      if (_mode == _ComposeMode.poll) {
        await widget.dropRepository.createPollDrop(
          question: _captionController.text,
          options: _pollOptionControllers.map((c) => c.text.trim()).toList(),
          durationDays: _pollDurationDays,
          mentionedUserIds: _mentionedUserIds,
        );
      } else {
        final existingImageUrl = _existingImageUrl;
        if (_imagesBytes.isNotEmpty) {
          await widget.dropRepository.createDrop(
            imagesBytes: _imagesBytes,
            imageExtensions: _imageExtensions,
            caption: _captionController.text,
            mentionedUserIds: _mentionedUserIds,
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
          );
        } else {
          // WYNOS V1.0.0 Beta requirement 2: no image at all -- _canShare
          // only allows reaching this branch when the caption is non-empty.
          await widget.dropRepository.createTextDrop(
            caption: _captionController.text,
            mentionedUserIds: _mentionedUserIds,
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

  /// WYN-036, Screen 1 -- the sole entry point for both the AppBar's X
  /// button and the system back gesture (via the PopScope wrapping
  /// [build]'s Scaffold). A direct `Navigator.pop()` call always
  /// succeeds regardless of PopScope's `canPop` (only `maybePop()`/the
  /// system back gesture consult it), so every branch below can just
  /// call it once it's decided the screen should actually close.
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
      // before switching to โพล mode (the SegmentedButton never clears
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
    // (via onPopInvokedWithResult) -- the AppBar's X button below
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _handleClose,
          ),
          title: const Text('Drop ใหม่'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: WynSpacing.space2),
              child: Center(
                child: Semantics(
                  label: _isRestricted
                      ? 'แชร์ ปิดใช้งานเนื่องจากบัญชีถูกจำกัดการโพสต์ชั่วคราว'
                      : null,
                  excludeSemantics: _isRestricted,
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
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isRestricted)
                  RestrictionBanner(
                    reason: _restrictReason,
                    expiresAt: _restrictExpiresAt,
                    actionId: _restrictActionId,
                    appealStatus: _restrictAppealStatus,
                    onAppeal: _openAppeal,
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: WynSpacing.space4,
                    vertical: WynSpacing.space2,
                  ),
                  child: SegmentedButton<_ComposeMode>(
                    segments: const [
                      ButtonSegment(
                        value: _ComposeMode.image,
                        label: Text('รูปภาพ'),
                        icon: Icon(Icons.image_outlined),
                      ),
                      ButtonSegment(
                        value: _ComposeMode.poll,
                        label: Text('โพล'),
                        icon: Icon(Icons.poll_outlined),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: _isSharing
                        ? null
                        : (selection) =>
                            setState(() => _mode = selection.first),
                  ),
                ),
                if (_mode == _ComposeMode.image)
                  _buildImageArea()
                else
                  _buildPollComposer(),
                Padding(
                  padding: const EdgeInsets.all(WynSpacing.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MentionInput(
                        controller: _captionController,
                        profileRepository: _profileRepository,
                        hashtagRepository: widget._hashtagRepository,
                        onMentionedUsersChanged: (ids) =>
                            setState(() => _mentionedUserIds = ids),
                        maxLength: _captionMaxLength,
                        maxLines: 4,
                        minLines: 2,
                        enabled: !_isSharing,
                        decoration: InputDecoration(
                          hintText: _mode == _ComposeMode.poll
                              ? 'ตั้งคำถามโพล... ใส่ #hashtag หรือ @mention ได้'
                              : 'เขียนแคปชัน... ใส่ #hashtag หรือ @mention ได้',
                          border: InputBorder.none,
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
      ),
    );
  }

  Widget _buildImageArea() {
    final existingImageUrl = _existingImageUrl;

    // WYN-036 draft continuation, unchanged: a Draft's already-uploaded
    // image, not yet replaced by a fresh pick -- single image only,
    // same as before multi-image existed (see saveDraft's own scope
    // note above).
    if (existingImageUrl != null && _imagesBytes.isEmpty) {
      return GestureDetector(
        onTap: (_isSharing || _isCropping) ? null : _showImageSourceSheet,
        child: AspectRatio(
          aspectRatio: 1,
          child: Semantics(
            label: 'รูปที่เลือก',
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: _isCropping
                  ? const Center(child: CircularProgressIndicator())
                  : Image.network(existingImageUrl, fit: BoxFit.cover),
            ),
          ),
        ),
      );
    }

    if (_imagesBytes.isEmpty) {
      return GestureDetector(
        onTap: (_isSharing || _isCropping) ? null : _showImageSourceSheet,
        child: AspectRatio(
          aspectRatio: 1,
          child: Semantics(
            label: 'แตะเพื่อเลือกหรือถ่ายรูป',
            button: true,
            child: Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: _isCropping
                  ? const Center(child: CircularProgressIndicator())
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 40),
                          SizedBox(height: WynSpacing.space2),
                          Text('แตะเพื่อเลือกรูป (ไม่บังคับ)'),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    // WYN-071: 1-9 picked images -- grid responsive to count, per the
    // Design doc (1 image: full width, 2-3: single row, 4+: 3 columns).
    final crossAxisCount = _imagesBytes.length == 1
        ? 1
        : (_imagesBytes.length <= 3 ? _imagesBytes.length : 3);
    final canAddMore =
        _imagesBytes.length < _maxImages && !_isCropping && !_isSharing;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WynSpacing.space4,
        vertical: WynSpacing.space2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isCropping) const LinearProgressIndicator(),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: WynSpacing.space2,
              mainAxisSpacing: WynSpacing.space2,
            ),
            itemCount: _imagesBytes.length + (canAddMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _imagesBytes.length) return _buildAddImageTile();
              return _buildImageThumbnail(index);
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: WynSpacing.space1),
            child: Text(
              '${_imagesBytes.length}/$_maxImages',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageThumbnail(int index) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_imagesBytes[index], fit: BoxFit.cover),
          Positioned(
            top: 4,
            right: 4,
            child: Semantics(
              label: 'ลบรูปที่ ${index + 1}',
              button: true,
              excludeSemantics: true,
              child: InkWell(
                onTap: _isSharing ? null : () => _removeImage(index),
                borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: WynColors.imageScrimStrong,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddImageTile() {
    return Semantics(
      label: 'เพิ่มรูป เหลือได้อีก ${_maxImages - _imagesBytes.length} รูป',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: _showImageSourceSheet,
        borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
          ),
          child: const Icon(Icons.add_photo_alternate_outlined, size: 32),
        ),
      ),
    );
  }

  /// WYN-035, Design Screen 1 -- replaces [_buildImageArea] when
  /// [_mode] is [_ComposeMode.poll]. The caption field below this
  /// (shared with the image mode, see [build]) doubles as the poll's
  /// question -- no separate question field.
  Widget _buildPollComposer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
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
                      decoration: InputDecoration(
                        hintText: 'ตัวเลือกที่ ${i + 1}',
                        counterText: '',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  // Only the 3rd/4th option can be removed -- the
                  // first 2 are the minimum a Poll must always have.
                  if (i >= _minPollOptions)
                    IconButton(
                      key: ValueKey('remove_poll_option_$i'),
                      icon: const Icon(Icons.close),
                      tooltip: 'ลบตัวเลือกนี้',
                      onPressed: _isSharing ? null : () => _removePollOption(i),
                    ),
                ],
              ),
            ),
          if (_pollOptionControllers.length < _maxPollOptions)
            TextButton.icon(
              onPressed: _isSharing ? null : _addPollOption,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มตัวเลือก'),
            ),
          const SizedBox(height: WynSpacing.space2),
          Text('ระยะเวลาโหวต', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: WynSpacing.space2),
          SegmentedButton<int>(
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
}

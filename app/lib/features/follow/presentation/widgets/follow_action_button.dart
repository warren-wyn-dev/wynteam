import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../profile/data/profile.dart';
import '../../data/follow_repository.dart';
import '../../data/follow_request_repository.dart';

/// The Follow button's 3 states (ติดตาม / ขอติดตามแล้ว / กำลังติดตาม),
/// extracted out of `ViewProfileScreen` (WYN-039) into its own reusable
/// widget so WYN-040's Discovery page (Rising/Suggested Users sections)
/// can reuse the exact same 3-state logic instead of forking a second
/// copy of it -- see .wyn/docs/design/wyn-040-discovery-page.md, Screen
/// 1 (#3/#4): "ปุ่ม Follow reuse 3-state button เดิมจาก WYN-039 ตรงๆ ...
/// ไม่สร้างปุ่มใหม่". `ViewProfileScreen` is deliberately left untouched
/// (not refactored to call this widget too) -- it's already covered by
/// its own QA'd test suite, and swapping its inline implementation for
/// this one would be an unrelated refactor outside this task's scope.
///
/// Self-contained: loads its own initial follow/pending-request status
/// on init (unlike `ViewProfileScreen`, which loads it as part of a
/// larger profile-load sequence) -- every call site here is a small
/// list row/card with no other data to load alongside it.
class FollowActionButton extends StatefulWidget {
  const FollowActionButton({
    super.key,
    required this.profile,
    required this.followRepository,
    required this.followRequestRepository,
    this.compact = false,
  });

  final Profile profile;
  final FollowRepository followRepository;
  final FollowRequestRepository followRequestRepository;

  /// Smaller padding/min-size for the Rising section's card (Design
  /// doc: "ขนาดเล็กลง (compact OutlinedButton) ให้พอดีความกว้างการ์ด").
  final bool compact;

  @override
  State<FollowActionButton> createState() => _FollowActionButtonState();
}

class _FollowActionButtonState extends State<FollowActionButton> {
  // Null until loaded -- the button stays hidden rather than ever
  // showing a possibly-wrong state, same posture as
  // ViewProfileScreen._isFollowing/_hasPendingRequest.
  bool? _isFollowing;
  bool? _hasPendingRequest;
  bool _isActionInFlight = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final isFollowing =
          await widget.followRepository.isFollowing(userId: widget.profile.id);
      if (!mounted) return;
      setState(() => _isFollowing = isFollowing);
    } catch (_) {
      // Leave null -- see the field's doc comment above.
    }
    if (!widget.profile.isPrivate) return;
    try {
      final hasPending = await widget.followRequestRepository
          .hasPendingRequest(userId: widget.profile.id);
      if (!mounted) return;
      setState(() => _hasPendingRequest = hasPending);
    } catch (_) {
      // Same posture.
    }
  }

  // WYN-039 Design, Screen 2 -- the Follow button's 3 states. Mirrors
  // ViewProfileScreen._followButtonLabel exactly.
  String get _label {
    if (_isFollowing!) return 'กำลังติดตาม';
    if (widget.profile.isPrivate && (_hasPendingRequest ?? false)) {
      return 'ขอติดตามแล้ว';
    }
    return 'ติดตาม';
  }

  String get _semanticsLabel {
    if (_isFollowing!) return 'กำลังติดตาม กดเพื่อเลิกติดตาม';
    if (widget.profile.isPrivate && (_hasPendingRequest ?? false)) {
      return 'ขอติดตามแล้ว กดเพื่อยกเลิกคำขอ';
    }
    return widget.profile.isPrivate ? 'กดเพื่อขอติดตาม' : 'กดเพื่อติดตาม';
  }

  Future<void> _toggleFollow() async {
    final previous = _isFollowing!;
    setState(() => _isFollowing = !previous);
    HapticFeedback.lightImpact();
    try {
      await widget.followRepository.toggleFollow(
        userId: widget.profile.id,
        currentlyFollowing: previous,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFollowing = previous);
    }
  }

  Future<void> _sendRequest() async {
    if (_isActionInFlight) return;
    setState(() {
      _isActionInFlight = true;
      _hasPendingRequest = true;
    });
    try {
      await widget.followRequestRepository
          .sendRequest(userId: widget.profile.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasPendingRequest = false);
    } finally {
      if (mounted) setState(() => _isActionInFlight = false);
    }
  }

  // Confirm before canceling (unlike sending) -- mirrors
  // ViewProfileScreen._cancelFollowRequest exactly, same reasoning:
  // undoing a decision already communicated to the other party is
  // worth one extra tap to avoid an accidental cancel.
  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('ยกเลิกคำขอติดตาม ${widget.profile.nameOrUsername}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ไม่ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('ยกเลิกคำขอ'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || _isActionInFlight) return;

    setState(() {
      _isActionInFlight = true;
      _hasPendingRequest = false;
    });
    try {
      await widget.followRequestRepository
          .cancelRequest(userId: widget.profile.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasPendingRequest = true);
    } finally {
      if (mounted) setState(() => _isActionInFlight = false);
    }
  }

  void _onPressed() {
    if (_isFollowing!) {
      _toggleFollow();
    } else if (widget.profile.isPrivate && (_hasPendingRequest ?? false)) {
      _cancelRequest();
    } else if (widget.profile.isPrivate) {
      _sendRequest();
    } else {
      _toggleFollow();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFollowing == null) return const SizedBox.shrink();

    final primary = Theme.of(context).colorScheme.primary;
    final style = widget.compact
        ? OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: primary),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            textStyle: Theme.of(context).textTheme.labelSmall,
          )
        : OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: primary),
          );

    return Semantics(
      label: _semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: OutlinedButton(
        style: style,
        onPressed: _isActionInFlight ? null : _onPressed,
        // WYN-071: cross-fades the label on state changes instead of the
        // text snapping instantly -- key on the label text itself so
        // AnimatedSwitcher only triggers when it actually changes.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(_label, key: ValueKey(_label)),
        ),
      ),
    );
  }
}

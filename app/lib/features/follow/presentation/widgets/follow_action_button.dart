import 'package:wyn/core/typography/browser_system_text.dart';
import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/interaction/wyn_feedback.dart';
import '../../../../core/interaction/wyn_motion.dart';
import '../../../auth/presentation/widgets/guest_gate.dart';
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
    this.filled = false,
    this.headerCompact = false,
    this.hideWhenFollowing = false,
  });

  final Profile profile;
  final FollowRepository followRepository;
  final FollowRequestRepository followRequestRepository;

  /// Smaller padding/min-size for compact recommendation surfaces.
  final bool compact;

  /// Founder profile recommendation sheet uses a black filled pill while
  /// existing Discovery/Profile recommendation surfaces keep their original
  /// outlined appearance by default.
  final bool filled;

  /// Extra-small filled pill for an inline post header. Kept separate
  /// from [compact] so recommendation surfaces retain their 36px button.
  final bool headerCompact;

  /// IG-like feed behavior: hide the pill after a follow is established.
  final bool hideWhenFollowing;

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
      final isFollowing = await widget.followRepository.isFollowing(
        userId: widget.profile.id,
      );
      if (!mounted) return;
      setState(() => _isFollowing = isFollowing);
    } catch (_) {
      // Leave null -- see the field's doc comment above.
    }
    if (!widget.profile.isPrivate) return;
    try {
      final hasPending = await widget.followRequestRepository.hasPendingRequest(
        userId: widget.profile.id,
      );
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
    WynFeedback.follow();
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
    WynFeedback.follow();
    try {
      await widget.followRequestRepository.sendRequest(
        userId: widget.profile.id,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasPendingRequest = false);
    } finally {
      if (mounted) setState(() => _isActionInFlight = false);
    }
  }

  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: BrowserSystemText(
                'ยกเลิกคำขอติดตาม ${widget.profile.nameOrUsername}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const BrowserSystemText('ไม่ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const BrowserSystemText('ยกเลิกคำขอ'),
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
    WynFeedback.follow();
    try {
      await widget.followRequestRepository.cancelRequest(
        userId: widget.profile.id,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasPendingRequest = true);
    } finally {
      if (mounted) setState(() => _isActionInFlight = false);
    }
  }

  Future<void> _onPressed() async {
    // Guests may browse people, but Follow/Follow Request is a real-account
    // action. The shared gate shows the existing สมัคร/เข้าสู่ระบบ prompt
    // before any optimistic state change or write is attempted.
    if (!await requireRealAccount(context) || !mounted) return;

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

  Widget _labelWidget(BuildContext context) {
    return AnimatedSwitcher(
      duration: WynMotion.duration(context, WynMotion.quick),
      child: BrowserSystemText(_label, key: ValueKey(_label)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFollowing == null ||
        (widget.hideWhenFollowing && _isFollowing == true)) {
      return const SizedBox.shrink();
    }

    final primary = Theme.of(context).colorScheme.primary;
    final onPressed = _isActionInFlight ? null : _onPressed;

    final Widget button;
    if (widget.filled) {
      button = FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: WynColors.ink,
          foregroundColor: WynColors.paper,
          disabledBackgroundColor: WynColors.surfaceTint,
          disabledForegroundColor: WynColors.graphite,
          minimumSize: widget.headerCompact
              ? const Size(0, 28)
              : Size(widget.compact ? 84 : 0, widget.compact ? 36 : 44),
          padding: EdgeInsets.symmetric(
            horizontal: widget.headerCompact ? 12 : (widget.compact ? 16 : 20),
          ),
          shape: const StadiumBorder(),
          tapTargetSize:
              widget.headerCompact ? MaterialTapTargetSize.shrinkWrap : null,
          textStyle: widget.headerCompact
              ? Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(fontWeight: FontWeight.w700)
              : (widget.compact
                  ? Theme.of(context).textTheme.labelMedium
                  : Theme.of(context).textTheme.labelLarge),
          elevation: 0,
        ),
        child: _labelWidget(context),
      );
    } else {
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
      button = OutlinedButton(
        style: style,
        onPressed: onPressed,
        child: _labelWidget(context),
      );
    }

    return Semantics(
      label: _semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: button,
    );
  }
}

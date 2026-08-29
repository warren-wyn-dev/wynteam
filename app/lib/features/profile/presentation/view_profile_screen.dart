import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../club/data/club_post_repository.dart';
import '../../club/data/club_repository.dart';
import '../../drop/data/drop_repository.dart';
import '../../follow/data/follow_repository.dart';
import '../../follow/data/follow_request_repository.dart';
import '../../follow/presentation/follow_list_screen.dart';
import '../../follow/presentation/follow_request_list_screen.dart';
import '../../home/data/home_repository.dart';
import '../../pop/data/pop_repository.dart';
import '../../saved/data/saved_repository.dart';
import '../data/profile.dart';
import '../data/profile_repository.dart';
import 'edit_profile_screen.dart';
import 'widgets/avatar_circle.dart';
import 'widgets/profile_drafts_tab.dart';
import 'widgets/profile_drop_grid_tab.dart';
// Pop is hidden from Profile for WYNOS V1.0.0 Beta (Product spec
// requirement 3) -- the Pop system itself (ProfilePopGridTab,
// PopRepository, the pop_* DB tables) is untouched and stays in the
// codebase, just no longer wired up on this screen. See
// .wyn/company/DECISIONS.md, 2026-08-14/2026-08-22 (Pop already
// unmounted from RootShell's Bottom Nav the same way, for V3).
import 'widgets/profile_likes_tab.dart';
import 'widgets/profile_recommendation_section.dart';
import 'widgets/profile_redrops_tab.dart';
import 'widgets/profile_replies_tab.dart';
import 'widgets/profile_saved_tab.dart';
import 'widgets/privacy_notice_banner.dart';
import 'widgets/profile_skeleton.dart';
// WYN-073 (WYNOS Design Reference Rollout, Screen 05 -- Profile,
// own-profile view only): the 3 own-profile-only tabs (โพสต์/ReDrop/
// ถูกใจ) render as full-width WynosPostRow lists instead of the shared
// grid tabs above, which stay wired up for someone else's profile only
// -- see the "Club/other-profile branch untouched" note on
// `_buildOtherProfileTabBarView` below.
import 'widgets/wynos_profile_post_list.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wynos_home_tokens.dart';
import '../../../core/widgets/wynos_ringed_avatar.dart';
import '../../block/data/block_relationship.dart';
import '../../block/data/block_repository.dart';
import '../../block/presentation/block_dialogs.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/shared_content_type.dart';
import '../../chat/presentation/conversation_screen.dart';
import '../../chat/presentation/share_sheet.dart';
import '../../moderation/data/appeal_repository.dart';
import '../../mute/data/mute_repository.dart';
import '../../notification/data/notification_repository.dart';
import '../../notification/presentation/notification_list_screen.dart';
import '../../report/data/report_repository.dart';
import '../../report/data/report_target_type.dart';
import '../../report/presentation/report_sheet.dart';
import '../../search/data/discovery_repository.dart';
import '../../search/presentation/search_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../zoky/data/zoky_repository.dart';

/// Placeholder share link -- same "no real hosting/domain yet" caveat as
/// dropShareLink/clubShareLink (WYN-005/014).
String profileShareLink(String username) => 'https://wyn.app/@$username';

typedef _ProfileWithCounts = ({
  Profile profile,
  int followerCount,
  int followingCount,
  // WYN-073: own-profile's Stats row now shows a 3rd stat ("โพสต์") per
  // `/05-profile.tsx` Section 3 -- only ever fetched for the viewer's
  // own profile (see `_load` below), 0 and unused otherwise, since
  // someone else's profile still shows just the 2 original stats.
  int postCount,
});

/// Screen 1 — View Profile. Doubles as both personas WYN-013 needs (the
/// current user's own profile, or someone else's) rather than being two
/// separate screens -- only the header actions/tab count differ. See
/// .wyn/docs/design/wyn-003-user-profile.md, wyn-008-follow.md (Screen 4),
/// wyn-013-profile-v2.md (Screen 1-2).
class ViewProfileScreen extends StatefulWidget {
  const ViewProfileScreen({
    super.key,
    required this.profileRepository,
    required this.followRepository,
    required this.dropRepository,
    required this.popRepository,
    required this.savedRepository,
    required this.userId,
    this.clubRepository,
    this.clubPostRepository,
    this.reportRepository,
    this.blockRepository,
    this.muteRepository,
    this.chatRepository,
    this.homeRepository,
    this.followRequestRepository,
  });

  final ProfileRepository profileRepository;
  final FollowRepository followRepository;
  final DropRepository dropRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final String userId;

  // Optional (unlike every other repository here) -- only used to
  // construct SearchScreen/NotificationListScreen from _openSearch/
  // _openNotifications below (someone else's profile only, see those
  // methods), never queried directly by this screen itself. Formerly
  // also backed the own-profile-only "My Clubs" shelf (WYN-015),
  // removed entirely per WYN-073's design-reference rollout -- kept
  // optional/defaulted the same way regardless, so every call site that
  // never had a real Club repository to hand (tap-to-profile from a
  // Drop/Pop, a Follow list row, a Search result) still doesn't need
  // one just to open Search/Notifications from a pushed profile screen.
  final ClubRepository? clubRepository;
  final ClubPostRepository? clubPostRepository;

  // Optional and defaulted to Supabase.instance.client when omitted
  // (see the State's _reportRepository/_blockRepository/_muteRepository
  // getters below) -- these three used to be hardcoded directly in the
  // State, unlike every repository above, which meant the More menu's
  // "รายงาน"/"บล็อก"/"ปิดเสียง" items (and the Blocked persona banner)
  // had no way to be exercised by a widget test: WYN-027 QA found this
  // gap and flagged it as a fast-follow (see .wyn/company/DECISIONS.md,
  // WYN-027 QA round 1). Fixed here while adding WYN-028's own
  // muteRepository to the same three-repository hardcoding, rather than
  // compounding the same gap a third time.
  final ReportRepository? reportRepository;
  final BlockRepository? blockRepository;
  final MuteRepository? muteRepository;

  // Same optional/defaulted shape as the 3 above -- WYN-031's
  // "ส่งข้อความ" entry point.
  final ChatRepository? chatRepository;

  // Same optional/defaulted shape again -- WYN-034's "ReDrops" tab
  // (Screen 4), the only place on this screen that reads `home_feed`
  // rather than `drops` directly.
  final HomeRepository? homeRepository;

  // Same optional/defaulted shape again -- WYN-039's Follow Request flow
  // (Locked persona's button + own-profile badge into
  // FollowRequestListScreen).
  final FollowRequestRepository? followRequestRepository;

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  late Future<_ProfileWithCounts> _loadFuture;

  // Whether the *current viewer* follows this profile's owner -- null
  // until the real status has loaded. Only relevant (and only loaded)
  // when this isn't the viewer's own profile. See
  // DropDetailScreen._isFollowing (WYN-008) for why this stays hidden
  // rather than defaulting to false.
  bool? _isFollowing;

  // Null until loaded (only for other people's profiles, same as
  // _isFollowing) -- WYN-027's Blocked persona (Design Screen 3) reads
  // this to decide whether to show the Follow button/counts at all or
  // replace them with a banner, and the More menu (Screen 1) reads it
  // to decide whether "บล็อก" belongs in the list.
  BlockRelationship? _blockRelationship;

  // Null until loaded (only for other people's profiles) -- WYN-028's
  // More menu toggle (Design Screen 1) reads this to decide whether to
  // show "ปิดเสียง" or "เปิดเสียง", and stays hidden while null so the
  // label can never show the wrong action, same posture as
  // _blockRelationship above.
  bool? _isMuted;

  late final ReportRepository _reportRepository =
      widget.reportRepository ?? ReportRepository(Supabase.instance.client);
  late final BlockRepository _blockRepository =
      widget.blockRepository ?? BlockRepository(Supabase.instance.client);
  late final MuteRepository _muteRepository =
      widget.muteRepository ?? MuteRepository(Supabase.instance.client);
  late final ChatRepository _chatRepository =
      widget.chatRepository ?? ChatRepository(Supabase.instance.client);
  late final HomeRepository _homeRepository =
      widget.homeRepository ?? HomeRepository(Supabase.instance.client);
  late final FollowRequestRepository _followRequestRepository =
      widget.followRequestRepository ??
          FollowRequestRepository(Supabase.instance.client);

  // WYN-071 Screen 5 -- same optional/defaulted shape as every other
  // repository above. Built fresh (not threaded through the
  // constructor) since only this screen's Recommendation Section uses
  // it here.
  late final DiscoveryRepository _discoveryRepository = DiscoveryRepository(
    Supabase.instance.client,
    homeRepository: _homeRepository,
    profileRepository: widget.profileRepository,
  );

  // Null until loaded (only for other people's profiles, same posture as
  // _isFollowing) -- true only while the *current viewer* has an
  // outstanding, undecided Follow Request against this Private profile.
  // Drives the Follow button's 3rd state ("ขอติดตามแล้ว").
  bool? _hasPendingRequest;
  bool _isFollowActionInFlight = false;

  // Only meaningful for the viewer's own profile -- how many people are
  // waiting on a Follow Request decision. Drives the badge entry point
  // into FollowRequestListScreen (Design Screen 3). 0 renders no badge
  // at all.
  int _pendingRequestCount = 0;

  bool _isStartingChat = false;

  bool get _isOwnProfile =>
      widget.userId == Supabase.instance.client.auth.currentUser!.id;

  /// WYNOS Unified Home Feed Algorithm V1.0 -- best-effort "Profile
  /// Visit" User Signal, only for someone else's profile (the guard at
  /// this method's own call site already ensures that; there's no
  /// further self-visit check needed here, unlike record_drop_view()'s
  /// server-side one -- see HomeRepository.recordProfileVisit's own
  /// doc comment for why). Silent on failure, same posture as every
  /// other best-effort background fetch on this screen (e.g.
  /// _loadFollowStatus) -- a missed personalization signal is never
  /// worth a blocking error for a screen the user is just browsing.
  Future<void> _recordProfileVisit() async {
    try {
      await _homeRepository.recordProfileVisit(widget.userId);
    } catch (_) {
      // Silent -- see doc comment above.
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
    if (!_isOwnProfile) {
      _loadFollowStatus();
      _loadBlockRelationship();
      _loadMuteStatus();
      _loadPendingRequestStatus();
      _recordProfileVisit();
    } else {
      _loadPendingRequestCount();
    }
    // WYN-073: the "Club ของฉัน" shelf (WYN-015) that used to populate
    // from `widget.clubRepository` here has been removed from
    // own-profile entirely, per `/05-profile.tsx`'s own explicit list of
    // changes -- see this class's doc comment. `widget.clubRepository`/
    // `widget.clubPostRepository` are still used (unconditionally, not
    // own-profile-specific) by `_openSearch`/`_openNotifications` below.
  }

  // Profile and Follower/Following counts are loaded together as one
  // future so there's a single loading state, not counts appearing in a
  // separate flicker after the profile itself. See
  // .wyn/docs/design/wyn-008-follow.md, Screen 4.
  Future<_ProfileWithCounts> _load() async {
    final profile = await widget.profileRepository.fetchProfile(widget.userId);
    final followerCount =
        await widget.followRepository.countFollowers(userId: widget.userId);
    final followingCount =
        await widget.followRepository.countFollowing(userId: widget.userId);
    // WYN-073: only queried for the viewer's own profile -- someone
    // else's profile doesn't render this stat at all, so there's no
    // reason to add a 3rd query to that branch's load.
    final postCount = _isOwnProfile
        ? await widget.dropRepository.countByAuthor(authorId: widget.userId)
        : 0;
    return (
      profile: profile,
      followerCount: followerCount,
      followingCount: followingCount,
      postCount: postCount,
    );
  }

  void _reload() {
    setState(() => _loadFuture = _load());
  }

  Future<void> _loadFollowStatus() async {
    try {
      final isFollowing =
          await widget.followRepository.isFollowing(userId: widget.userId);
      if (!mounted) return;
      setState(() => _isFollowing = isFollowing);
    } catch (_) {
      // Leave _isFollowing null -- the button stays hidden rather than
      // showing a possibly-wrong state.
    }
  }

  Future<void> _toggleFollow() async {
    final previous = _isFollowing;
    if (previous == null) return;
    setState(() => _isFollowing = !previous);
    HapticFeedback.lightImpact();
    try {
      await widget.followRepository.toggleFollow(
        userId: widget.userId,
        currentlyFollowing: previous,
      );
      _reload();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFollowing = previous);
    }
  }

  // WYN-039 Design, Screen 2 -- the Follow button's 3 states. Only
  // reached once _isFollowing is non-null (the caller above already
  // guards that), so this never has to represent a 4th "still loading"
  // state itself.
  String _followButtonLabel(Profile profile) {
    if (_isFollowing!) return 'กำลังติดตาม';
    if (profile.isPrivate && (_hasPendingRequest ?? false)) {
      return 'ขอติดตามแล้ว';
    }
    return 'ติดตาม';
  }

  String _followButtonSemanticsLabel(Profile profile) {
    if (_isFollowing!) return 'กำลังติดตาม กดเพื่อเลิกติดตาม';
    if (profile.isPrivate && (_hasPendingRequest ?? false)) {
      return 'ขอติดตามแล้ว กดเพื่อยกเลิกคำขอ';
    }
    return profile.isPrivate ? 'กดเพื่อขอติดตาม' : 'กดเพื่อติดตาม';
  }

  void _onFollowButtonPressed(Profile profile) {
    if (_isFollowing!) {
      _toggleFollow();
    } else if (profile.isPrivate && (_hasPendingRequest ?? false)) {
      _cancelFollowRequest(profile);
    } else if (profile.isPrivate) {
      _sendFollowRequest();
    } else {
      _toggleFollow();
    }
  }

  Future<void> _loadPendingRequestStatus() async {
    try {
      final hasPending = await _followRequestRepository.hasPendingRequest(
          userId: widget.userId);
      if (!mounted) return;
      setState(() => _hasPendingRequest = hasPending);
    } catch (_) {
      // Leave it null -- same posture as _loadFollowStatus.
    }
  }

  Future<void> _loadPendingRequestCount() async {
    try {
      final count = await _followRequestRepository.countPendingRequests();
      if (!mounted) return;
      setState(() => _pendingRequestCount = count);
    } catch (_) {
      // Leave it at 0 -- the badge just stays hidden, same posture as
      // every other best-effort count on this screen.
    }
  }

  // WYN-039 Design, Screen 2 -- sends a Follow Request instead of an
  // instant follow when the target is Private and not yet followed.
  // Optimistic, no confirm dialog (mirrors _toggleFollow's own posture
  // for the same reason: fully reversible, one tap to undo via
  // _cancelFollowRequest below).
  Future<void> _sendFollowRequest() async {
    if (_isFollowActionInFlight) return;
    setState(() {
      _isFollowActionInFlight = true;
      _hasPendingRequest = true;
    });
    try {
      await _followRequestRepository.sendRequest(userId: widget.userId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasPendingRequest = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งคำขอติดตามไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isFollowActionInFlight = false);
    }
  }

  // Confirm before canceling (unlike sending) -- the Design doc calls
  // this out explicitly since it's the one Follow-adjacent action on
  // this screen with a confirm dialog, mirroring _blockUser's posture
  // rather than _toggleFollow's: undoing a decision already communicated
  // to the other party is worth one extra tap to avoid an accidental
  // cancel.
  Future<void> _cancelFollowRequest(Profile profile) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('ยกเลิกคำขอติดตาม ${profile.nameOrUsername}?'),
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
    if (!confirmed || _isFollowActionInFlight) return;

    setState(() {
      _isFollowActionInFlight = true;
      _hasPendingRequest = false;
    });
    try {
      await _followRequestRepository.cancelRequest(userId: widget.userId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasPendingRequest = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ยกเลิกคำขอไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isFollowActionInFlight = false);
    }
  }

  // WYN-071 Design, Screen 8 -- built fresh here rather than threaded
  // through this screen's constructor, same optional/defaulted pattern
  // already used above for _reportRepository/_blockRepository/etc. (and
  // documented on NotificationListScreen's own followRequestRepository
  // field as "see ViewProfileScreen's own comment on the pattern") --
  // every call site of ViewProfileScreen would otherwise need to grow
  // these params just to support a shortcut icon two people out of many
  // call sites will ever use.
  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          clubRepository:
              widget.clubRepository ?? ClubRepository(Supabase.instance.client),
          clubPostRepository: widget.clubPostRepository ??
              ClubPostRepository(Supabase.instance.client),
          autofocus: true,
        ),
      ),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationListScreen(
          notificationRepository: NotificationRepository(Supabase.instance.client),
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          savedRepository: widget.savedRepository,
          clubRepository:
              widget.clubRepository ?? ClubRepository(Supabase.instance.client),
          clubPostRepository: widget.clubPostRepository ??
              ClubPostRepository(Supabase.instance.client),
          zokyRepository: ZokyRepository(Supabase.instance.client),
          appealRepository: AppealRepository(Supabase.instance.client),
          chatRepository: _chatRepository,
        ),
      ),
    );
  }

  /// WYN-071: Saved's tab content pushed as its own screen instead --
  /// see the Row above `_openEdit`'s button. `ProfileSavedTab`/
  /// `ProfileDraftsTab` themselves are unchanged (still the exact same
  /// widgets, just no longer mounted inside this screen's TabBarView).
  void _openSaved() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('บันทึก')),
          body: ProfileSavedTab(
            savedRepository: widget.savedRepository,
            dropRepository: widget.dropRepository,
            popRepository: widget.popRepository,
            followRepository: widget.followRepository,
            profileRepository: widget.profileRepository,
          ),
        ),
      ),
    );
  }

  void _openDrafts() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('ร่าง')),
          body: ProfileDraftsTab(
            dropRepository: widget.dropRepository,
            profileRepository: widget.profileRepository,
          ),
        ),
      ),
    );
  }

  void _openFollowRequests() {
    Navigator.of(context)
        .push<void>(
      MaterialPageRoute(
        builder: (_) => FollowRequestListScreen(
          followRequestRepository: _followRequestRepository,
        ),
      ),
    )
        .then((_) {
      // The list screen may have Accepted/Rejected requests -- refresh
      // both the badge count and this profile's own Followers count.
      if (!mounted) return;
      _loadPendingRequestCount();
      _reload();
    });
  }

  // WYN-031, Screen 4. get_or_create_conversation() itself rejects a
  // blocked pair server-side, but this button is already hidden in
  // that state (see the Blocked persona branch in build()), so the
  // only realistic failure here is a transient network error.
  Future<void> _openChat(Profile profile) async {
    if (_isStartingChat) return;
    setState(() => _isStartingChat = true);
    try {
      final conversationId =
          await _chatRepository.getOrCreateConversation(widget.userId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            chatRepository: _chatRepository,
            conversationId: conversationId,
            otherUserId: widget.userId,
            otherUsername: profile.username,
            otherDisplayName: profile.displayName,
            otherAvatarUrl: profile.avatarUrl,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เริ่มบทสนทนาไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    } finally {
      if (mounted) setState(() => _isStartingChat = false);
    }
  }

  Future<void> _loadBlockRelationship() async {
    try {
      final relationship =
          await _blockRepository.blockRelationship(widget.userId);
      if (!mounted) return;
      setState(() => _blockRelationship = relationship);
    } catch (_) {
      // Leave it null -- the Follow button/banner both stay hidden
      // rather than guessing, same posture as _loadFollowStatus.
    }
  }

  Future<void> _blockUser(Profile profile) async {
    final confirmed = await confirmBlock(context, username: profile.username);
    if (!confirmed) return;

    try {
      await _blockRepository.blockUser(widget.userId);
      if (!mounted) return;
      setState(() => _blockRelationship = BlockRelationship.blockedByMe);
      // Blocking may have just torn down an existing Follow relationship
      // (either direction) and always changes the follower/following
      // counts -- reload both rather than leaving stale numbers/state.
      _isFollowing = null;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บล็อก @${profile.username} แล้ว')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บล็อกไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _loadMuteStatus() async {
    try {
      final isMuted = await _muteRepository.isMuted(widget.userId);
      if (!mounted) return;
      setState(() => _isMuted = isMuted);
    } catch (_) {
      // Leave it null -- the More menu item stays hidden rather than
      // guessing, same posture as _loadBlockRelationship.
    }
  }

  // Optimistic toggle, no confirm dialog -- unlike _blockUser above,
  // mute has no side effect visible to anyone but the current user and
  // is fully reversible, so the extra friction of a dialog isn't
  // warranted (WYN-028 Design, Screen 1 -- mirrors _toggleFollow's
  // shape exactly, not _blockUser's).
  Future<void> _toggleMute(Profile profile) async {
    final previous = _isMuted;
    if (previous == null) return;
    setState(() => _isMuted = !previous);
    try {
      if (previous) {
        await _muteRepository.unmuteUser(widget.userId);
      } else {
        await _muteRepository.muteUser(widget.userId);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(previous
              ? 'เปิดเสียง @${profile.username} แล้ว'
              : 'ปิดเสียง @${profile.username} แล้ว'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isMuted = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  Future<void> _openEdit(Profile profile) async {
    await Navigator.of(context).push<Profile>(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profileRepository: widget.profileRepository,
          profile: profile,
        ),
      ),
    );
    _reload();
  }

  Future<void> _reportUser() {
    return showReportSheet(
      context,
      reportRepository: _reportRepository,
      targetType: ReportTargetType.user,
      targetId: widget.userId,
      targetLabel: 'รายงานผู้ใช้นี้',
      associatedUserId: widget.userId,
    );
  }

  // Extensible on purpose -- WYN-026 already left room for WYN-027/028
  // to add items here without restructuring it. "บล็อก" only shows once
  // _blockRelationship has loaded and confirms there isn't one already
  // (Design Screen 1) -- once blocked, this menu shows just "รายงาน"
  // (no "เลิกบล็อก" shortcut here per Product spec, Design Screen 3).
  // "ปิดเสียง"/"เปิดเสียง" (WYN-028) sits between รายงาน/บล็อก by
  // severity (Design Screen 1) and, like บล็อก, only shows once its own
  // status has loaded -- and never at all when a block relationship
  // already exists, since Block's Blocked persona menu reduces to just
  // "รายงาน" regardless (mute would be redundant under a much stronger
  // restriction).
  Future<void> _openMoreMenu() async {
    // WYN-033: needs the username for both the native-share text and
    // the Share-to-Chat preview label -- _loadFuture is already
    // in-flight/resolved by the time this button is reachable (set in
    // initState), so this just awaits the same cached Future the body
    // itself uses, never a second query.
    final data = await _loadFuture;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('แชร์โปรไฟล์'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showShareSheet(
                  context,
                  chatRepository: _chatRepository,
                  profileRepository: widget.profileRepository,
                  sharedContentType: SharedContentType.profile,
                  sharedContentId: widget.userId,
                  previewLabel: 'แชร์โปรไฟล์ @${data.profile.username}',
                  nativeShareText: profileShareLink(data.profile.username),
                  nativeShareTitle:
                      data.profile.displayName ?? '@${data.profile.username}',
                );
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('รายงาน'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _reportUser();
              },
            ),
            if (_isMuted != null &&
                _blockRelationship == BlockRelationship.none)
              ListTile(
                leading: Icon(_isMuted! ? Icons.volume_up : Icons.volume_off),
                title: Text(_isMuted! ? 'เปิดเสียง' : 'ปิดเสียง'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _onMuteTapped();
                },
              ),
            if (_blockRelationship == BlockRelationship.none)
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('บล็อก'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _onBlockTapped();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onBlockTapped() async {
    try {
      final data = await _loadFuture;
      if (!mounted) return;
      await _blockUser(data.profile);
    } catch (_) {
      // The profile itself failed to load -- nothing sensible to block
      // by username; the screen's own error state already covers this.
    }
  }

  Future<void> _onMuteTapped() async {
    try {
      final data = await _loadFuture;
      if (!mounted) return;
      await _toggleMute(data.profile);
    } catch (_) {
      // The profile itself failed to load -- nothing sensible to mute
      // by username; the screen's own error state already covers this.
    }
  }

  // WYN-039 Design, Screen 2 -- the follower/following *count* stays
  // visible on a Locked profile (see follower_count()/following_count()
  // in schema.sql), but the drill-down list itself doesn't open for
  // anyone who isn't the owner or an accepted follower -- `follows`' own
  // RLS would just return an empty list anyway, but a SnackBar is a
  // clearer outcome than silently opening to nothing.
  Future<void> _openFollowList(
    FollowListMode mode, {
    required bool isLockedPrivate,
  }) async {
    if (isLockedPrivate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ต้องติดตามก่อนถึงจะดูรายชื่อได้')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListScreen(
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: widget.userId,
          mode: mode,
        ),
      ),
    );
  }

  /// WYN-027 Design, Screen 3 -- when blocked (either direction), the
  /// Drop/Pop grid's empty state must say the content is *hidden*, not
  /// reuse the ordinary "ยังไม่มี ... เลย" copy that would wrongly imply
  /// this person has no content at all.
  String _gridEmptyText({
    required bool isOwnProfile,
    required bool isBlockedEitherWay,
    required bool isLockedPrivate,
    required String contentLabel,
    required Profile profile,
  }) {
    if (isBlockedEitherWay) {
      return (_blockRelationship?.iBlockedThem ?? false)
          ? 'คุณบล็อกผู้ใช้นี้อยู่ จึงไม่เห็นเนื้อหาของเขา'
          : 'ไม่สามารถดูเนื้อหาของผู้ใช้นี้ได้';
    }
    // WYN-039 Design, Screen 2 -- the grid genuinely has no rows for a
    // locked viewer (RLS on `drops` hides them), so this is the same
    // "must say hidden, not implausibly-empty" reasoning WYN-027 already
    // established above, not a new pattern.
    if (isLockedPrivate) {
      return 'บัญชีนี้เป็นส่วนตัว — ติดตามเพื่อดู ${profile.nameOrUsername}';
    }
    return isOwnProfile
        ? 'ยังไม่มี $contentLabel เลย'
        : '${profile.nameOrUsername} ยังไม่มี $contentLabel เลย';
  }

  /// WYN-027 Design, Screen 3 -- two honest variants depending on who
  /// blocked whom, never a generic "you can't see this" that would
  /// misrepresent a relationship the viewer didn't actually choose.
  Widget _buildBlockedBanner() {
    final iBlockedThem = _blockRelationship?.iBlockedThem ?? false;
    final message = iBlockedThem
        ? 'คุณบล็อกผู้ใช้นี้อยู่'
        : 'ไม่สามารถดูเนื้อหาของผู้ใช้นี้ได้';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: WynSpacing.space4,
        vertical: WynSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block,
              size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: WynSpacing.space2),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = _isOwnProfile;

    return DefaultTabController(
      // WYN-073: 3 tabs (โพสต์/ReDrop/ถูกใจ) for the viewer's own
      // profile, per `/05-profile.tsx`'s explicit "removed the ตอบกลับ/
      // มีเดีย tabs" change -- still 5 (Posts/ReDrops/Replies/Media/
      // Likes, WYN-071) for someone else's profile, untouched. See the
      // TabBar/TabBarView built by `_buildOwnProfileBody`/
      // `_buildOtherProfileBody` below.
      length: isOwnProfile ? 3 : 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('โปรไฟล์'),
          actions: [
            if (isOwnProfile) ...[
              // WYN-073: the standalone logout icon that used to sit
              // here (equal visual weight to Settings) is gone -- only
              // the gear remains. Sign-out now lives inside
              // SettingsScreen itself, at the bottom, visually
              // separated -- see SettingsScreen's own "ออกจากระบบ"
              // section.
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                tooltip: 'ตั้งค่า',
                onPressed: () async {
                  // Settings' "เครื่องมือผู้ดูแล" section (WYN-029, Screen 1)
                  // needs platformRole -- reuses this screen's own
                  // already-in-flight/already-resolved _loadFuture
                  // (started in initState) instead of a second query.
                  // The AppBar (and this button) renders before the
                  // body's FutureBuilder resolves, so awaiting here
                  // rather than reading a possibly-still-null cached
                  // value is what keeps this correct on a slow
                  // connection too -- in the overwhelmingly common case
                  // this resolves instantly since the future is already
                  // in flight or done.
                  final data = await _loadFuture;
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        platformRole: data.profile.platformRole,
                        isPrivate: data.profile.isPrivate,
                        dmPermission: data.profile.dmPermission,
                        mentionPermission: data.profile.mentionPermission,
                        commentPermission: data.profile.commentPermission,
                      ),
                    ),
                  );
                  // The Privacy toggle (WYN-039) may have changed since
                  // this profile was first loaded -- reload so the Drop
                  // grid/Follow Requests badge reflect the new value
                  // immediately, without requiring a manual pull-to-
                  // refresh.
                  _reload();
                },
              ),
            ] else ...[
              // WYN-071: Search/Notifications shortcuts, only on someone
              // else's profile -- the Bottom Nav already puts both 1 tap
              // away from the viewer's own profile (a root tab of
              // RootShell), so duplicating them there would be dead
              // weight. A pushed profile screen like this one hides the
              // Bottom Nav, so these fill the gap here specifically.
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'ค้นหา',
                onPressed: _openSearch,
              ),
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'การแจ้งเตือน',
                onPressed: _openNotifications,
              ),
              Semantics(
                label: 'ตัวเลือกเพิ่มเติมสำหรับโปรไฟล์นี้',
                excludeSemantics: true,
                child: IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: _openMoreMenu,
                ),
              ),
            ],
          ],
        ),
        body: FutureBuilder<_ProfileWithCounts>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('โหลดโปรไฟล์ไม่สำเร็จ'),
                    const SizedBox(height: WynSpacing.space3),
                    TextButton(
                        onPressed: _reload, child: const Text('ลองใหม่')),
                  ],
                ),
              );
            }

            if (!snapshot.hasData) {
              return const ProfileSkeleton();
            }

            final data = snapshot.data!;
            final profile = data.profile;

            // WYN-073: own-profile's body is a full restyle to
            // `/05-profile.tsx` (WynosHomeTokens, 3 tabs, no Club shelf,
            // de-emphasized action row) -- someone else's profile keeps
            // its existing WynTheme-based layout completely untouched
            // (`_buildOtherProfileBody`, unchanged from before this
            // task). See this class's own doc comment on scope.
            return isOwnProfile
                ? _buildOwnProfileBody(context, profile, data)
                : _buildOtherProfileBody(context, profile, data);
          },
        ),
      ),
    );
  }

  /// WYN-073 -- own-profile only. Identity block, Stats row (with the
  /// 3rd "โพสต์" stat), de-emphasized Action row, then the 3-tab
  /// (โพสต์/ReDrop/ถูกใจ) `TabBar`/`TabBarView`, per `/05-profile.tsx`.
  /// Never reached for someone else's profile -- see `_buildOtherProfileBody`.
  Widget _buildOwnProfileBody(
    BuildContext context,
    Profile profile,
    _ProfileWithCounts data,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            children: [
              WynosRingedAvatar(
                imageUrl: profile.avatarUrl,
                fallbackText: profile.username,
                radius: 38,
              ),
              const SizedBox(height: WynSpacing.space3),
              Text(
                profile.nameOrUsername,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: WynosHomeTokens.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text('@${profile.username}', style: WynosHomeTokens.caption()),
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                const SizedBox(height: WynSpacing.space3),
                Text(
                  profile.bio!,
                  textAlign: TextAlign.center,
                  style: WynosHomeTokens.bodySmall(color: WynosHomeTokens.ink),
                ),
              ],
              const SizedBox(height: WynSpacing.space5),
              // R3: Stats row -- ผู้ติดตาม / กำลังติดตาม / โพสต์, real
              // counts (data.postCount is only ever fetched for the
              // viewer's own profile, see `_load`), vertical hairline
              // dividers between each.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _WynosStatBlock(
                    value: data.followerCount,
                    label: 'ผู้ติดตาม',
                    onTap: () => _openFollowList(
                      FollowListMode.followers,
                      isLockedPrivate: false,
                    ),
                  ),
                  const _WynosStatDivider(),
                  _WynosStatBlock(
                    value: data.followingCount,
                    label: 'กำลังติดตาม',
                    onTap: () => _openFollowList(
                      FollowListMode.following,
                      isLockedPrivate: false,
                    ),
                  ),
                  const _WynosStatDivider(),
                  _WynosStatBlock(value: data.postCount, label: 'โพสต์'),
                ],
              ),
              const SizedBox(height: WynSpacing.space5),
              // R4: de-emphasized action row -- a small centered pill
              // (not a full-width bordered button) + 2 plain borderless
              // icons (Bookmark -> Saved, PenLine -> Drafts, same
              // destinations as before WYN-073, see _openSaved/
              // _openDrafts's own doc comments).
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      side: const BorderSide(color: WynosHomeTokens.hairline),
                      foregroundColor: WynosHomeTokens.ink,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 10),
                      textStyle: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () => _openEdit(profile),
                    child: const Text('แก้ไขโปรไฟล์'),
                  ),
                  const SizedBox(width: WynSpacing.space5),
                  Semantics(
                    label: 'บันทึก',
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(Icons.bookmark_border,
                          color: WynosHomeTokens.graphite),
                      onPressed: _openSaved,
                    ),
                  ),
                  Semantics(
                    label: 'ร่าง',
                    button: true,
                    excludeSemantics: true,
                    child: IconButton(
                      icon: const Icon(Icons.edit_note_outlined,
                          color: WynosHomeTokens.graphite),
                      onPressed: _openDrafts,
                    ),
                  ),
                ],
              ),
              // WYN-039 Design, Screen 3's entry point -- only for a
              // Private account with at least 1 request waiting (see
              // _loadPendingRequestCount: stays 0, so hidden, for a
              // Public account). Left in its original (pre-WYN-073)
              // styling -- not covered by `/05-profile.tsx`, which has
              // no Follow Request concept at all.
              if (profile.isPrivate && _pendingRequestCount > 0) ...[
                const SizedBox(height: WynSpacing.space2),
                InkWell(
                  onTap: _openFollowRequests,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WynSpacing.space4,
                      vertical: WynSpacing.space2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_add_alt, size: 18),
                        const SizedBox(width: WynSpacing.space2),
                        Text('คำขอติดตาม ($_pendingRequestCount)'),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // ProfileRecommendationSection stays other-profile-only,
        // completely untouched -- it never rendered for own-profile
        // before WYN-073 either (see _buildOtherProfileBody), and
        // `/05-profile.tsx`'s own list of changes doesn't mention it at
        // all. See this task's Known Issues for why it's left alone
        // rather than repositioned.
        const SizedBox(height: WynSpacing.space5),
        // R5: 3 tabs (โพสต์/ReDrop/ถูกใจ), sapphire underline indicator
        // (not the rainbow-gradient/default-Cyan indicator other
        // screens still use).
        TabBar(
          indicatorColor: WynosHomeTokens.sapphire,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: WynosHomeTokens.filterTab(active: true),
          unselectedLabelStyle: WynosHomeTokens.filterTab(active: false),
          tabs: const [
            Tab(text: 'โพสต์'),
            Tab(text: 'ReDrop'),
            Tab(text: 'ถูกใจ'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              // R6/R1: full-width WynosPostRow lists (see
              // wynos_profile_post_list.dart) instead of the 3-column
              // grid `ProfileDropGridTab`/`ProfileLikesTab` still use on
              // someone else's profile -- `/05-profile.tsx`'s own doc
              // comment: "WYNOS posts are text-first, and a photo-grid
              // format truncates them and strips engagement down to a
              // single icon."
              WynosProfilePostListTab(
                fetchPage: (page) async {
                  final drops = await widget.dropRepository.fetchByAuthor(
                    authorId: widget.userId,
                    page: page,
                  );
                  return drops.map(PostRowData.fromDrop).toList();
                },
                pageSize: DropRepository.pageSize,
                emptyText: 'ยังไม่มี Post เลย',
                errorText: 'โหลด Drop ไม่สำเร็จ',
                dropRepository: widget.dropRepository,
                followRepository: widget.followRepository,
                profileRepository: widget.profileRepository,
                popRepository: widget.popRepository,
                savedRepository: widget.savedRepository,
              ),
              WynosProfilePostListTab(
                fetchPage: (page) async {
                  final items = await _homeRepository.fetchRedropsByUser(
                    userId: widget.userId,
                    page: page,
                  );
                  return items.map(PostRowData.fromHomeFeedItem).toList();
                },
                pageSize: HomeRepository.pageSize,
                emptyText: 'ยังไม่มี ReDrop เลย',
                errorText: 'โหลด ReDrop ไม่สำเร็จ',
                dropRepository: widget.dropRepository,
                followRepository: widget.followRepository,
                profileRepository: widget.profileRepository,
                popRepository: widget.popRepository,
                savedRepository: widget.savedRepository,
                allowRedropActions: true,
              ),
              // "ถูกใจ" -- keeps the same "คนอื่นเห็นสิ่งที่คุณกด Like ได้
              // เหมือนกัน" privacy disclosure the shared (pre-WYN-073)
              // Likes tab always showed the profile owner (WYN-071),
              // unchanged in style -- `/05-profile.tsx` doesn't cover
              // privacy banners at all, so this stays exactly as it was
              // rather than being restyled/dropped.
              Column(
                children: [
                  const PrivacyNoticeBanner(
                    prefsKey: 'seen_likes_privacy_notice',
                    message: 'คนอื่นเห็นสิ่งที่คุณกด Like ได้เหมือนกัน',
                  ),
                  Expanded(
                    child: WynosProfilePostListTab(
                      fetchPage: (page) async {
                        final drops =
                            await widget.dropRepository.fetchLikedByAuthor(
                          authorId: widget.userId,
                          page: page,
                        );
                        return drops.map(PostRowData.fromDrop).toList();
                      },
                      pageSize: DropRepository.pageSize,
                      emptyText: 'ยังไม่มีสิ่งที่ถูกใจเลย',
                      errorText: 'โหลดรายการที่ถูกใจไม่สำเร็จ',
                      dropRepository: widget.dropRepository,
                      followRepository: widget.followRepository,
                      profileRepository: widget.profileRepository,
                      popRepository: widget.popRepository,
                      savedRepository: widget.savedRepository,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Someone else's profile -- unchanged from before WYN-073 (which is
  /// scoped to own-profile only). Still WynTheme/WynColors-based, still
  /// 5 tabs (Posts/ReDrops/Replies/Media/Likes, WYN-071), still the
  /// 3-column grid tabs. See this class's own doc comment.
  Widget _buildOtherProfileBody(
    BuildContext context,
    Profile profile,
    _ProfileWithCounts data,
  ) {
    final isBlockedEitherWay =
        _blockRelationship?.isBlockedEitherWay ?? false;
    // WYN-039 Design, Screen 2 -- Block always takes precedence over
    // Private (a blocked pair sees the Blocked banner, never the Locked
    // one, regardless of the target's account type). While
    // _isFollowing is still loading (null), this conservatively treats
    // the viewer as not-yet-a-follower -- the same brief-flicker
    // tradeoff _blockRelationship's own `?? false` default already
    // accepts elsewhere on this screen, not a new one introduced here.
    final isLockedPrivate = !isBlockedEitherWay &&
        profile.isPrivate &&
        (_isFollowing ?? false) == false;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(WynSpacing.space6),
          child: Column(
            children: [
              AvatarCircle(
                imageUrl: profile.avatarUrl,
                fallbackText: profile.username,
              ),
              const SizedBox(height: WynSpacing.space4),
              Text(
                profile.nameOrUsername,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: WynSpacing.space1),
              Text(
                '@${profile.username}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                const SizedBox(height: WynSpacing.space4),
                Text(profile.bio!, textAlign: TextAlign.center),
              ],
              const SizedBox(height: WynSpacing.space4),
              // Blocked persona (WYN-027 Design, Screen 3): counts and
              // the Follow button are both replaced by a banner -- a
              // relationship that's been severed has no meaningful
              // follower/following numbers to show, and "disabled but
              // visible" would be less clear than just saying why
              // outright.
              if (isBlockedEitherWay)
                _buildBlockedBanner()
              else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _FollowCountTarget(
                      count: data.followerCount,
                      label: 'ผู้ติดตาม',
                      onTap: () => _openFollowList(
                        FollowListMode.followers,
                        isLockedPrivate: isLockedPrivate,
                      ),
                    ),
                    const SizedBox(width: WynSpacing.space6),
                    _FollowCountTarget(
                      count: data.followingCount,
                      label: 'กำลังติดตาม',
                      onTap: () => _openFollowList(
                        FollowListMode.following,
                        isLockedPrivate: isLockedPrivate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: WynSpacing.space6),
                if (_isFollowing != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: _followButtonSemanticsLabel(profile),
                        excludeSemantics: true,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.primary,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          onPressed: _isFollowActionInFlight
                              ? null
                              : () => _onFollowButtonPressed(profile),
                          child: Text(_followButtonLabel(profile)),
                        ),
                      ),
                      const SizedBox(width: WynSpacing.space2),
                      // WYN-031, Screen 4 -- always reachable (no
                      // Message Request gate this round, see the design
                      // doc's own scope note).
                      OutlinedButton(
                        onPressed: _isStartingChat
                            ? null
                            : () => _openChat(profile),
                        child: _isStartingChat
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('ส่งข้อความ'),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
        ProfileRecommendationSection(
          discoveryRepository: _discoveryRepository,
          followRepository: widget.followRepository,
          followRequestRepository: _followRequestRepository,
          profileRepository: widget.profileRepository,
        ),
        // WYN-071: exactly 5 tabs (Posts/ReDrops/Replies/Media/Likes) --
        // untouched by WYN-073, which only restyles the own-profile
        // branch above. Saved/Draft (own-only, private) never applied
        // here anyway (they moved to own-profile's icon row, WYN-071).
        const TabBar(
          isScrollable: true,
          tabs: [
            Tab(icon: Icon(Icons.grid_view_outlined), text: 'Posts'),
            Tab(icon: Icon(Icons.repeat), text: 'ReDrops'),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Replies'),
            Tab(icon: Icon(Icons.image_outlined), text: 'Media'),
            Tab(icon: Icon(Icons.favorite_border), text: 'Likes'),
            // Pop tab intentionally omitted here -- see the import
            // comment above (WYNOS V1.0.0 Beta requirement 3).
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              ProfileDropGridTab(
                dropRepository: widget.dropRepository,
                followRepository: widget.followRepository,
                profileRepository: widget.profileRepository,
                popRepository: widget.popRepository,
                savedRepository: widget.savedRepository,
                authorId: widget.userId,
                emptyText: _gridEmptyText(
                  isOwnProfile: false,
                  isBlockedEitherWay: isBlockedEitherWay,
                  isLockedPrivate: isLockedPrivate,
                  contentLabel: 'Post',
                  profile: profile,
                ),
              ),
              ProfileRedropsTab(
                homeRepository: _homeRepository,
                dropRepository: widget.dropRepository,
                followRepository: widget.followRepository,
                profileRepository: widget.profileRepository,
                popRepository: widget.popRepository,
                savedRepository: widget.savedRepository,
                authorId: widget.userId,
                emptyText: _gridEmptyText(
                  isOwnProfile: false,
                  isBlockedEitherWay: isBlockedEitherWay,
                  isLockedPrivate: isLockedPrivate,
                  contentLabel: 'ReDrop',
                  profile: profile,
                ),
              ),
              ProfileRepliesTab(
                dropRepository: widget.dropRepository,
                followRepository: widget.followRepository,
                profileRepository: widget.profileRepository,
                popRepository: widget.popRepository,
                savedRepository: widget.savedRepository,
                authorId: widget.userId,
                emptyText: _gridEmptyText(
                  isOwnProfile: false,
                  isBlockedEitherWay: isBlockedEitherWay,
                  isLockedPrivate: isLockedPrivate,
                  contentLabel: 'การตอบกลับ',
                  profile: profile,
                ),
              ),
              ProfileDropGridTab(
                dropRepository: widget.dropRepository,
                followRepository: widget.followRepository,
                profileRepository: widget.profileRepository,
                popRepository: widget.popRepository,
                savedRepository: widget.savedRepository,
                authorId: widget.userId,
                onlyWithImages: true,
                emptyText: _gridEmptyText(
                  isOwnProfile: false,
                  isBlockedEitherWay: isBlockedEitherWay,
                  isLockedPrivate: isLockedPrivate,
                  contentLabel: 'สื่อ',
                  profile: profile,
                ),
              ),
              ProfileLikesTab(
                dropRepository: widget.dropRepository,
                followRepository: widget.followRepository,
                profileRepository: widget.profileRepository,
                popRepository: widget.popRepository,
                savedRepository: widget.savedRepository,
                authorId: widget.userId,
                emptyText: _gridEmptyText(
                  isOwnProfile: false,
                  isBlockedEitherWay: isBlockedEitherWay,
                  isLockedPrivate: isLockedPrivate,
                  contentLabel: 'สิ่งที่ถูกใจ',
                  profile: profile,
                ),
              ),
              // Pop tab intentionally omitted here -- see the import
              // comment above (WYNOS V1.0.0 Beta requirement 3).
            ],
          ),
        ),
      ],
    );
  }
}

class _FollowCountTarget extends StatelessWidget {
  const _FollowCountTarget({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count $label',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: WynSpacing.space2, vertical: WynSpacing.space1),
          child: Column(
            children: [
              Text(
                '$count',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// WYN-073's own-profile Stats row -- `/05-profile.tsx`'s `StatBlock`
/// (16px/700/ink value, 11.5px/graphite label), reusing
/// `WynosHomeTokens` instead of `Theme.of(context)` the way
/// `_FollowCountTarget` above does, since own-profile's Stats row is
/// Sapphire-token-styled while someone else's profile keeps the old
/// WynTheme look via `_FollowCountTarget` unchanged.
class _WynosStatBlock extends StatelessWidget {
  const _WynosStatBlock({
    required this.value,
    required this.label,
    this.onTap,
  });

  final int value;
  final String label;

  /// Null for "โพสต์" -- unlike ผู้ติดตาม/กำลังติดตาม, there's no
  /// existing drill-down screen for "posts by this author" beyond the
  /// โพสต์ tab already right below this row.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$value $label',
      button: onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: WynSpacing.space2, vertical: WynSpacing.space1),
          child: Column(
            children: [
              Text(
                '$value',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: WynosHomeTokens.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(label, style: WynosHomeTokens.caption()),
            ],
          ),
        ),
      ),
    );
  }
}

/// The vertical hairline divider between each `_WynosStatBlock` --
/// `/05-profile.tsx`'s `StatsRow`: `w-px h-8` (1 x 32px), `hairline`.
class _WynosStatDivider extends StatelessWidget {
  const _WynosStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
      color: WynosHomeTokens.hairline,
    );
  }
}

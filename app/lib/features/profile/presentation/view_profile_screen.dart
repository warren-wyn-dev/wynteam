import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
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
import '../../saved/presentation/bookmarks_screen.dart';
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
// ProfileRepliesTab (Replies tab) is similarly untouched but no longer
// wired up here -- 05-profile.tsx cuts it down to 3 tabs, see the
// TabBar/TabBarView below.
import 'widgets/profile_likes_tab.dart';
import 'widgets/profile_recommendation_section.dart';
import 'widgets/profile_redrops_tab.dart';
import 'widgets/privacy_notice_banner.dart';
import 'widgets/profile_skeleton.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_typography.dart';
import '../../../core/widgets/action_sheet_row.dart';
import '../../block/data/block_relationship.dart';
import '../../block/data/block_repository.dart';
import '../../block/presentation/block_dialogs.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/shared_content_type.dart';
import '../../chat/presentation/conversation_screen.dart';
import '../../chat/presentation/share_sheet.dart';
import '../../mute/data/mute_repository.dart';
import '../../report/data/report_repository.dart';
import '../../report/data/report_target_type.dart';
import '../../report/presentation/report_sheet.dart';
import '../../search/data/discovery_repository.dart';
import '../../search/presentation/search_screen.dart';
import '../../settings/presentation/settings_screen.dart';

/// Placeholder share link -- same "no real hosting/domain yet" caveat as
/// dropShareLink/clubShareLink (WYN-005/014).
String profileShareLink(String username) => 'https://wyn.app/@$username';

typedef _ProfileWithCounts = ({
  Profile profile,
  int followerCount,
  int followingCount,
  int dropCount,
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

  // Optional (unlike every other repository here): 05-profile.tsx
  // removed the "Club ของฉัน" shelf this screen used to render (still
  // reachable via Home's "From Your Clubs" feed) -- kept only so
  // _openSearch can still hand a real ClubRepository/ClubPostRepository
  // to the screen it pushes, rather than every call site of *this*
  // screen needing to supply one just for that.
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
    // 05-profile.tsx's StatsRow 3rd stat -- loaded alongside the other
    // two so there's still just the one combined loading state, same
    // reasoning as follower/following count above.
    final dropCount = await widget.dropRepository.countByAuthor(widget.userId);
    return (
      profile: profile,
      followerCount: followerCount,
      followingCount: followingCount,
      dropCount: dropCount,
    );
  }

  void _reload() {
    // Block body, not `() => _loadFuture = _load()` -- an assignment
    // expression evaluates to the assigned value, so an arrow body here
    // would make this closure literally return the Future, which trips
    // setState()'s own "did you accidentally do async work in here?"
    // debug assertion the instant this runs inside one (found via
    // WYN-081, which made this method reachable from a RefreshIndicator
    // pull for the first time -- see the 3 profile tabs'
    // onRefreshHeader).
    setState(() {
      _loadFuture = _load();
    });
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
  // already used above for _reportRepository/_blockRepository/etc. --
  // every call site of ViewProfileScreen would otherwise need to grow
  // these params just to support a shortcut icon two people out of many
  // call sites will ever use.
  //
  // WYN-085 (Wynos V1.0.0 Beta2, item 23): this used to have a sibling
  // _openNotifications() pushing NotificationListScreen next to this
  // one, with its own AppBar-less bell IconButton in actions[] below.
  // NotificationListScreen (02-notifications.tsx) has no back button of
  // its own -- it was designed only as a Bottom Nav root destination,
  // with a hamburger-drawer header instead of an AppBar, relying on the
  // Bottom Nav for onward navigation. This screen (when viewing someone
  // else's profile, i.e. exactly where that bell IconButton lived) is
  // itself pushed on top of another stack and hides the Bottom Nav, so
  // pushing NotificationListScreen from here stranded the viewer on a
  // screen with no way back out -- Founder: "หน้าโปรไฟล์คนอื่น มีปุ่ม
  // แจ้งเตือนได้ไง กดแล้ว ออกไปหน้าอื่นก็ไม่ได้". Removed entirely
  // rather than given a back button, since a bell shortcut pointing at
  // *your own* notifications never belonged on someone else's profile
  // in the first place.
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

  /// WYN-071: Saved's tab content pushed as its own screen instead --
  /// see the Row above `_openEdit`'s button. 15-bookmarks.tsx: that
  /// screen is [BookmarksScreen], its own full-width post-row list --
  /// see that file's own doc comment for why it's not `ProfileSavedTab`'s
  /// grid (which stays as the profile's own Saved tab body, untouched).
  void _openSaved() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookmarksScreen(
          savedRepository: widget.savedRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
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
      builder: (sheetContext) => ActionSheetBody(rows: [
        ActionSheetRow(
          icon: Icons.share_outlined,
          label: 'แชร์โปรไฟล์',
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
        ActionSheetRow(
          icon: Icons.flag_outlined,
          label: 'รายงาน',
          onTap: () {
            Navigator.of(sheetContext).pop();
            _reportUser();
          },
        ),
        if (_isMuted != null && _blockRelationship == BlockRelationship.none)
          ActionSheetRow(
            icon: _isMuted! ? Icons.volume_up : Icons.volume_off,
            label: _isMuted! ? 'เปิดเสียง' : 'ปิดเสียง',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _onMuteTapped();
            },
          ),
        if (_blockRelationship == BlockRelationship.none)
          ActionSheetRow(
            icon: Icons.block,
            label: 'บล็อก',
            onTap: () {
              Navigator.of(sheetContext).pop();
              _onBlockTapped();
            },
          ),
      ]),
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
      // 05-profile.tsx cuts Replies/Media -- 3 tabs (Posts/ReDrops/Likes)
      // for every viewer now. See the TabBar/TabBarView below.
      length: 3,
      child: Scaffold(
        backgroundColor: WynColors.paper,
        appBar: AppBar(
          backgroundColor: WynColors.paper,
          // 18-other-profile.tsx: someone else's profile names them in
          // the header ("@warren", Inter weight 700 -- an identity
          // label, not a screen-title moment, so no title styling here)
          // instead of a generic "โปรไฟล์" title. Reuses the same
          // _loadFuture the body's own FutureBuilder awaits rather than
          // fetching a second time; shows the generic title until it
          // resolves.
          title: isOwnProfile
              ? Text(
                  'โปรไฟล์',
                  style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink),
                )
              : FutureBuilder<_ProfileWithCounts>(
                  future: _loadFuture,
                  builder: (context, snapshot) {
                    final username = snapshot.data?.profile.username;
                    return Text(
                      username == null ? 'โปรไฟล์' : '@$username',
                      style: _textStyle(fontSize: 15, fontWeight: FontWeight.w700, color: WynColors.ink),
                    );
                  },
                ),
          actions: [
            if (isOwnProfile) ...[
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
              const SizedBox(width: WynSpacing.space2),
            ] else ...[
              // WYN-071: Search shortcut, only on someone else's profile
              // -- the Bottom Nav already puts it 1 tap away from the
              // viewer's own profile (a root tab of RootShell), so
              // duplicating it there would be dead weight. A pushed
              // profile screen like this one hides the Bottom Nav, so
              // this fills the gap here specifically. (A matching
              // Notifications shortcut used to sit next to this one --
              // removed by WYN-085, see _openSearch's own doc comment.)
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'ค้นหา',
                onPressed: _openSearch,
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
            final isBlockedEitherWay = !isOwnProfile &&
                (_blockRelationship?.isBlockedEitherWay ?? false);
            // WYN-039 Design, Screen 2 -- Block always takes precedence
            // over Private (a blocked pair sees the Blocked banner, never
            // the Locked one, regardless of the target's account type).
            // While _isFollowing is still loading (null), this
            // conservatively treats the viewer as not-yet-a-follower --
            // the same brief-flicker tradeoff _blockRelationship's own
            // `?? false` default already accepts elsewhere on this
            // screen, not a new one introduced here.
            final isLockedPrivate = !isOwnProfile &&
                !isBlockedEitherWay &&
                profile.isPrivate &&
                (_isFollowing ?? false) == false;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(WynSpacing.space6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // WYN-095 (Wynos V1.0.0 Beta2, item 24) Mockup A:
                      // avatar left + stats row right, same row --
                      // replaces the old fully-centered wyn-071 layout
                      // (avatar/name/username/bio/stats all centered,
                      // stats below bio) per Founder's own annotated
                      // layout sketch (see wyn-095-profile-layout-
                      // redesign.md's "Final Spec -- Mockup A").
                      Row(
                        children: [
                          AvatarCircle(
                            imageUrl: profile.avatarUrl,
                            fallbackText: profile.username,
                            ring: true,
                          ),
                          // Blocked persona (WYN-027 Design, Screen 3):
                          // no stats to show at all in that case --
                          // _buildBlockedBanner() below (in the old
                          // stats+buttons slot) covers it, so this row
                          // is just the avatar alone rather than an
                          // empty Expanded next to it.
                          if (!isBlockedEitherWay) ...[
                            const SizedBox(width: WynSpacing.space4),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _FollowCountTarget(
                                    count: data.followerCount,
                                    label: 'ผู้ติดตาม',
                                    onTap: () => _openFollowList(
                                      FollowListMode.followers,
                                      isLockedPrivate: isLockedPrivate,
                                    ),
                                  ),
                                  _buildStatDivider(),
                                  _FollowCountTarget(
                                    count: data.followingCount,
                                    label: 'กำลังติดตาม',
                                    onTap: () => _openFollowList(
                                      FollowListMode.following,
                                      isLockedPrivate: isLockedPrivate,
                                    ),
                                  ),
                                  _buildStatDivider(),
                                  _StatBlock(
                                      count: data.dropCount, label: 'โพสต์'),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: WynSpacing.space3),
                      Text(
                        profile.nameOrUsername,
                        style: _textStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: WynColors.ink,
                        ),
                      ),
                      const SizedBox(height: WynSpacing.space1),
                      Text(
                        '@${profile.username}',
                        style:
                            _textStyle(fontSize: 13, color: WynColors.mutedNeutral),
                      ),
                      if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                        const SizedBox(height: WynSpacing.space2),
                        Text(
                          profile.bio!,
                          style: _textStyle(
                            fontSize: 15,
                            color: _bioTone,
                            height: 1.45,
                          ),
                        ),
                      ],
                      const SizedBox(height: WynSpacing.space4),
                      // Blocked persona (WYN-027 Design, Screen 3): the
                      // Follow button is replaced by a banner -- a
                      // relationship that's been severed has no
                      // meaningful action to offer, and "disabled but
                      // visible" would be less clear than just saying
                      // why outright.
                      if (isBlockedEitherWay)
                        _buildBlockedBanner()
                      else if (isOwnProfile) ...[
                        Row(
                          children: [
                            // 05-profile.tsx de-emphasizes this: a
                            // small pill, not a full-width bordered
                            // button -- editing your own profile is
                            // occasional, not this screen's primary
                            // action, so it no longer competes with
                            // the identity block above it. WYN-095:
                            // kept at its original (non-Expanded)
                            // width -- a single button doesn't need to
                            // split a row in half the way the
                            // Follow+Message pair below does.
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: const StadiumBorder(),
                                side: const BorderSide(
                                    color: WynColors.hairline),
                                foregroundColor: WynColors.ink,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: WynSpacing.space5,
                                  vertical: WynSpacing.space2,
                                ),
                              ),
                              onPressed: () => _openEdit(profile),
                              child: Text(
                                'แก้ไขโปรไฟล์',
                                style: _textStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: WynColors.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: WynSpacing.space4),
                            // WYN-071: Saved/Draft moved off the
                            // public tab row (Posts/ReDrops/Replies/
                            // Media/Likes is now the same set for
                            // every viewer) into these two
                            // owner-only icons -- neither capability
                            // was removed, just relocated (see the
                            // Design doc, Screen 6).
                            Semantics(
                              label: 'บันทึก',
                              button: true,
                              excludeSemantics: true,
                              child: IconButton(
                                key: const Key('profile_saved_button'),
                                icon: const Icon(Icons.bookmark_border,
                                    color: WynColors.graphite),
                                onPressed: _openSaved,
                              ),
                            ),
                            Semantics(
                              label: 'ร่าง',
                              button: true,
                              excludeSemantics: true,
                              child: IconButton(
                                icon: const Icon(Icons.edit_note_outlined,
                                    color: WynColors.graphite),
                                onPressed: _openDrafts,
                              ),
                            ),
                          ],
                        ),
                        // WYN-039 Design, Screen 3's entry point --
                        // only for a Private account with at least 1
                        // request waiting (see _loadPendingRequestCount:
                        // stays 0, so hidden, for a Public account,
                        // which can never accumulate a pending request
                        // in the first place).
                        if (profile.isPrivate &&
                            _pendingRequestCount > 0) ...[
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
                      ] else if (_isFollowing != null)
                        // WYN-095: was a small filled pill + a 40x40
                        // icon-only circle side by side (natural
                        // width, centered) -- now a full-width Row
                        // split evenly in half, both StadiumBorder
                        // pills, per Mockup A. The Message button
                        // gains a visible "ส่งข้อความ" label (was
                        // icon-only) -- same border/foreground color
                        // as before, just a different shape/padding +
                        // the new label.
                        Row(
                          children: [
                            Expanded(
                              child: Semantics(
                                label: _followButtonSemanticsLabel(profile),
                                excludeSemantics: true,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    shape: const StadiumBorder(),
                                    backgroundColor: _isFollowing!
                                        ? const Color(0xFFF1EFE9)
                                        : WynColors.sapphire,
                                    foregroundColor: _isFollowing!
                                        ? WynColors.graphite
                                        : WynColors.paper,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: WynSpacing.space3,
                                    ),
                                    textStyle: _textStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: _isFollowActionInFlight
                                      ? null
                                      : () => _onFollowButtonPressed(profile),
                                  child: Text(_followButtonLabel(profile)),
                                ),
                              ),
                            ),
                            const SizedBox(width: WynSpacing.space2),
                            // WYN-031, Screen 4 -- always reachable (no
                            // Message Request gate this round, see the
                            // design doc's own scope note).
                            Expanded(
                              child: Semantics(
                                label:
                                    'ส่งข้อความถึง ${profile.nameOrUsername}',
                                button: true,
                                excludeSemantics: true,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    shape: const StadiumBorder(),
                                    side: const BorderSide(
                                        color: WynColors.hairline),
                                    foregroundColor: WynColors.ink,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: WynSpacing.space3,
                                    ),
                                  ),
                                  onPressed: _isStartingChat
                                      ? null
                                      : () => _openChat(profile),
                                  icon: _isStartingChat
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.send_outlined,
                                          size: 16, color: WynColors.ink),
                                  label: Text(
                                    'ส่งข้อความ',
                                    style: _textStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: WynColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (!isOwnProfile)
                  ProfileRecommendationSection(
                    discoveryRepository: _discoveryRepository,
                    followRepository: widget.followRepository,
                    followRequestRepository: _followRequestRepository,
                    profileRepository: widget.profileRepository,
                  ),
                // 05-profile.tsx cuts Replies/Media -- 3 tabs
                // (Posts/ReDrops/Likes) for every viewer now, same
                // public set regardless of who's looking. Saved/Draft
                // (own-only, private) stay on the icon row above, not
                // tabs here -- see _openSaved/_openDrafts.
                TabBar(
                  indicatorColor: WynColors.sapphire,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 2,
                  labelColor: WynColors.ink,
                  unselectedLabelColor: WynColors.mutedNeutral,
                  labelStyle:
                      _textStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle:
                      _textStyle(fontSize: 13, fontWeight: FontWeight.w400),
                  tabs: const [
                    Tab(text: 'โพสต์'),
                    Tab(text: 'รีโพสต์'),
                    Tab(text: 'ถูกใจ'),
                    // Pop tab intentionally omitted here -- see the
                    // import comment above (WYNOS V1.0.0 Beta requirement 3).
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
                        onRefreshHeader: _reload,
                        emptyText: _gridEmptyText(
                          isOwnProfile: isOwnProfile,
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
                        onRefreshHeader: _reload,
                        emptyText: _gridEmptyText(
                          isOwnProfile: isOwnProfile,
                          isBlockedEitherWay: isBlockedEitherWay,
                          isLockedPrivate: isLockedPrivate,
                          contentLabel: 'รีโพสต์',
                          profile: profile,
                        ),
                      ),
                      Column(
                        children: [
                          if (isOwnProfile)
                            const PrivacyNoticeBanner(
                              prefsKey: 'seen_likes_privacy_notice',
                              message: 'คนอื่นเห็นสิ่งที่คุณกด Like ได้เหมือนกัน',
                            ),
                          Expanded(
                            child: ProfileLikesTab(
                              dropRepository: widget.dropRepository,
                              followRepository: widget.followRepository,
                              profileRepository: widget.profileRepository,
                              popRepository: widget.popRepository,
                              savedRepository: widget.savedRepository,
                              authorId: widget.userId,
                              onRefreshHeader: _reload,
                              emptyText: _gridEmptyText(
                                isOwnProfile: isOwnProfile,
                                isBlockedEitherWay: isBlockedEitherWay,
                                isLockedPrivate: isLockedPrivate,
                                contentLabel: 'สิ่งที่ถูกใจ',
                                profile: profile,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
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
          child: _StatBlockContent(count: count, label: label),
        ),
      ),
    );
  }
}

/// The non-interactive 3rd stat (05-profile.tsx's "โพสต์") -- unlike
/// [_FollowCountTarget], this doesn't open a list of its own (there's no
/// separate "my posts" screen distinct from the Posts tab already on
/// this very page), so it's a plain Column, not wrapped in a
/// Semantics(button: true)/InkWell.
class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: WynSpacing.space2, vertical: WynSpacing.space1),
      child: _StatBlockContent(count: count, label: label),
    );
  }
}

class _StatBlockContent extends StatelessWidget {
  const _StatBlockContent({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          // WYN-095: the stat now sits in a 3-way row squeezed beside
          // the avatar rather than spanning the full screen width, so
          // a large raw number risks overflowing at 360px -- the
          // Semantics label above still reads the exact count out
          // loud, this is the visible text only.
          compactCountLabel(count),
          style:
              _textStyle(fontSize: 24, fontWeight: FontWeight.w700, color: WynColors.ink),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: _textStyle(fontSize: 13, color: WynColors.graphite),
        ),
      ],
    );
  }
}

/// SPEC.md Section 3's `w-px h-8 background hairline` vertical divider
/// between StatsRow stats.
Widget _buildStatDivider() => Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
      color: WynColors.hairline,
    );

/// 05-profile.tsx's bio tone (`#2B2A26`) -- deliberately not full
/// `WynColors.ink`, same "quieter than the nearest named token" pattern
/// SPEC.md's own Section 4.10 sanctions for Home's reply-preview text
/// (see notification_list_screen.dart's identical reasoning for its own
/// message-body tone).
const _bioTone = Color(0xFF2B2A26);

TextStyle _textStyle({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w400,
  Color? color,
  double? height,
}) =>
    TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding='utf-8')


def write(path: str, text: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding='utf-8')


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{path}: expected exactly one occurrence, found {count}: {old[:80]!r}')
    write(path, text.replace(old, new, 1))


def sub_once(path: str, pattern: str, repl: str, flags: int = re.S) -> None:
    text = read(path)
    updated, count = re.subn(pattern, repl, text, count=1, flags=flags)
    if count != 1:
        raise SystemExit(f'{path}: regex expected exactly one match, found {count}: {pattern[:100]!r}')
    write(path, updated)


# ---------------------------------------------------------------------------
# WYNOS v1.0.0 Beta5 — Profile V2 data model.
# ---------------------------------------------------------------------------
profile_path = 'app/lib/features/profile/data/profile.dart'
replace_once(profile_path, '    this.avatarUrl,\n    this.platformRole = PlatformRole.user,',
             '    this.avatarUrl,\n    this.coverUrl,\n    this.platformRole = PlatformRole.user,')
replace_once(profile_path, "        avatarUrl: map['avatar_url'] as String?,\n        platformRole:",
             "        avatarUrl: map['avatar_url'] as String?,\n        coverUrl: map['cover_url'] as String?,\n        platformRole:")
replace_once(profile_path, '  final String? avatarUrl;\n  final PlatformRole platformRole;',
             '  final String? avatarUrl;\n  final String? coverUrl;\n  final PlatformRole platformRole;')

repo_path = 'app/lib/features/profile/data/profile_repository.dart'
text = read(repo_path)
text = text.replace(
    'id, username, display_name, bio, avatar_url, platform_role, is_private, is_verified, dm_permission, mention_permission, comment_permission, likes_visibility',
    'id, username, display_name, bio, avatar_url, cover_url, platform_role, is_private, is_verified, dm_permission, mention_permission, comment_permission, likes_visibility',
)
text = text.replace(
    "select('id, username, display_name, bio, avatar_url')",
    "select('id, username, display_name, bio, avatar_url, cover_url')",
)
text = text.replace(
    'id, username, display_name, bio, avatar_url, platform_role, is_private, is_verified',
    'id, username, display_name, bio, avatar_url, cover_url, platform_role, is_private, is_verified',
)
write(repo_path, text)

cover_methods = r'''

  /// Beta5 Profile V2: uploads a wide profile cover into the same
  /// per-user public `avatars` storage folder as the avatar. Reusing the
  /// existing bucket means the already-deployed owner-folder storage RLS
  /// continues to be the authority; no new public bucket is introduced.
  Future<String> uploadCover({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path = '$userId/cover.$fileExtension';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    final url =
        '${_client.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
    await _client.from('profiles').update({'cover_url': url}).eq('id', userId);
    return url;
  }
'''
sub_once(
    repo_path,
    r'(  Future<String> uploadAvatar\([\s\S]*?\n    return url;\n  \})',
    r'\1' + cover_methods,
)

# ---------------------------------------------------------------------------
# Drop pinning — stored on the Drop itself because a Drop has exactly one
# author/profile. This keeps pin visibility under existing drops RLS.
# ---------------------------------------------------------------------------
drop_repo_path = 'app/lib/features/drop/data/drop_repository.dart'
pin_methods = r'''

  /// Beta5 Profile V2: the author's pinned Drops, ordered by the server's
  /// 1..3 profile_pin_position. This remains an ordinary `drops` select,
  /// so every existing audience/private/block RLS rule still applies.
  Future<List<Drop>> fetchPinnedByAuthor({required String authorId}) async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('drops')
        .select(_dropSelect)
        .eq('author_id', authorId)
        .isFilter('deleted_at', null)
        .not('profile_pin_position', 'is', null)
        .order('profile_pin_position', ascending: true);

    final viewer = await _fetchViewerState(userId: userId, rows: rows);
    return rows
        .map((row) => Drop.fromMap(
              row,
              likedByMe: viewer.likedIds.contains(row['id'] as String),
              savedByMe: viewer.savedIds.contains(row['id'] as String),
              redroppedByMe: viewer.redroppedIds.contains(row['id'] as String),
              pollMyVoteIndex:
                  viewer.pollStates[_pollIdFromRow(row)]?.myVoteIndex,
              pollTotalVotes:
                  viewer.pollStates[_pollIdFromRow(row)]?.totalVotes,
              pollOptionCounts:
                  viewer.pollStates[_pollIdFromRow(row)]?.optionCounts,
              imageUrls: viewer.imageUrlsByDropId[row['id'] as String],
            ))
        .toList();
  }

  /// Atomically pins one of the signed-in user's own Drops into the first
  /// free Profile slot (maximum 3). The RPC serializes concurrent pin
  /// requests server-side, so two taps/devices cannot create four pins.
  Future<void> pinProfileDrop(String dropId) async {
    await _client.rpc('pin_profile_drop', params: {'p_drop_id': dropId});
  }

  Future<void> unpinProfileDrop(String dropId) async {
    await _client.rpc('unpin_profile_drop', params: {'p_drop_id': dropId});
  }
'''
replace_once(
    drop_repo_path,
    '  /// Total (non-deleted) Drop count for one author -- 05-profile.tsx\'s',
    pin_methods + '\n  /// Total (non-deleted) Drop count for one author -- 05-profile.tsx\'s',
)

recording_path = 'app/test/support/recording_drop_repository.dart'
recording_pin = r'''

  /// Beta5 Profile V2 fixtures. Tests opt in by populating this map; all
  /// existing tests see an empty pinned shelf by default.
  Map<String, List<Drop>> pinnedDropsByAuthor = {};
  final List<String> pinProfileDropCalls = [];
  final List<String> unpinProfileDropCalls = [];

  @override
  Future<List<Drop>> fetchPinnedByAuthor({required String authorId}) async =>
      pinnedDropsByAuthor[authorId] ?? <Drop>[];

  @override
  Future<void> pinProfileDrop(String dropId) async {
    pinProfileDropCalls.add(dropId);
  }

  @override
  Future<void> unpinProfileDrop(String dropId) async {
    unpinProfileDropCalls.add(dropId);
  }
'''
replace_once(
    recording_path,
    '  /// Returned by [countByAuthor], keyed by authorId -- defaults to 0 for',
    recording_pin + '\n  /// Returned by [countByAuthor], keyed by authorId -- defaults to 0 for',
)

# ---------------------------------------------------------------------------
# New Profile V2 widgets.
# ---------------------------------------------------------------------------
write('app/lib/features/profile/presentation/widgets/profile_v2_header.dart', r'''import 'package:flutter/material.dart';

import '../../data/profile.dart';
import 'avatar_circle.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Beta5 Profile V2 full header.
///
/// Founder decision: the old full-width "แก้ไขโปรไฟล์" + link/button band
/// is deliberately not rendered here. Editing lives in the compact top
/// bar, so the first post moves upward and the profile reads as one piece.
class ProfileV2Header extends StatelessWidget {
  const ProfileV2Header({
    super.key,
    required this.profile,
    required this.nameRow,
    required this.followingCount,
    required this.followerCount,
    required this.onFollowingTap,
    required this.onFollowersTap,
    this.onEditCover,
    this.blockedBanner,
    this.actionRow,
    this.pendingRequestEntry,
  });

  final Profile profile;
  final Widget nameRow;
  final int followingCount;
  final int followerCount;
  final VoidCallback onFollowingTap;
  final VoidCallback onFollowersTap;
  final VoidCallback? onEditCover;
  final Widget? blockedBanner;
  final Widget? actionRow;
  final Widget? pendingRequestEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('profile_v2_full_header'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: double.infinity,
              height: 124,
              child: _CoverImage(url: profile.coverUrl),
            ),
            Positioned(
              left: WynSpacing.space5,
              bottom: -39,
              child: AvatarCircle(
                imageUrl: profile.avatarUrl,
                fallbackText: profile.username,
                radius: 42,
                ring: true,
              ),
            ),
            if (onEditCover != null)
              Positioned(
                right: WynSpacing.space3,
                bottom: WynSpacing.space3,
                child: Material(
                  color: WynColors.paper.withValues(alpha: 0.88),
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const Key('profile_cover_edit_button'),
                    tooltip: 'เปลี่ยนรูปปก',
                    icon: const Icon(Icons.photo_camera_outlined, size: 19),
                    onPressed: onEditCover,
                  ),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WynSpacing.space5,
            WynSpacing.space3,
            WynSpacing.space5,
            WynSpacing.space3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 94, height: 40),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        nameRow,
                        const SizedBox(height: WynSpacing.space1),
                        Text(
                          '@${profile.username}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: WynColors.mutedNeutral,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: WynSpacing.space2),
                Text(
                  profile.bio!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.35,
                        color: WynColors.graphite,
                      ),
                ),
              ],
              if (blockedBanner != null) ...[
                const SizedBox(height: WynSpacing.space3),
                blockedBanner!,
              ] else ...[
                const SizedBox(height: WynSpacing.space3),
                Row(
                  children: [
                    _ProfileStat(
                      count: followingCount,
                      label: 'กำลังติดตาม',
                      onTap: onFollowingTap,
                    ),
                    const SizedBox(width: WynSpacing.space5),
                    _ProfileStat(
                      count: followerCount,
                      label: 'ผู้ติดตาม',
                      onTap: onFollowersTap,
                    ),
                  ],
                ),
                if (actionRow != null) ...[
                  const SizedBox(height: WynSpacing.space3),
                  actionRow!,
                ],
                if (pendingRequestEntry != null) ...[
                  const SizedBox(height: WynSpacing.space1),
                  pendingRequestEntry!,
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [WynColors.surfaceTint, WynColors.paper],
        ),
      ),
    );
    if (url == null || url!.isEmpty) return fallback;
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _ProfileStat extends StatelessWidget {
  const _ProfileStat({
    required this.count,
    required this.label,
    required this.onTap,
  });

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: WynSpacing.space1,
          horizontal: WynSpacing.space1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: WynColors.ink,
                  ),
            ),
            const SizedBox(width: WynSpacing.space1),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: WynColors.mutedNeutral,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
''')

write('app/lib/features/profile/presentation/profile_cover_editor_screen.dart', r'''import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/profile.dart';
import '../data/profile_repository.dart';
import '../../../core/design/wyn_colors.dart';
import '../../../core/design/wyn_spacing.dart';

/// Small, focused Beta5 editor for the wide profile cover. Basic identity
/// editing stays in EditProfileScreen; this screen exists so tapping the
/// cover itself does exactly what the user expects without restoring a
/// large edit button under the profile stats.
class ProfileCoverEditorScreen extends StatefulWidget {
  const ProfileCoverEditorScreen({
    super.key,
    required this.profileRepository,
    required this.profile,
  });

  final ProfileRepository profileRepository;
  final Profile profile;

  @override
  State<ProfileCoverEditorScreen> createState() =>
      _ProfileCoverEditorScreenState();
}

class _ProfileCoverEditorScreenState extends State<ProfileCoverEditorScreen> {
  Uint8List? _bytes;
  String _extension = 'jpg';
  bool _saving = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1800,
      maxHeight: 1000,
      imageQuality: 88,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    final name = image.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : 'jpg';
    setState(() {
      _bytes = bytes;
      _extension = {'jpg', 'jpeg', 'png', 'webp'}.contains(ext) ? ext : 'jpg';
      _error = null;
    });
  }

  Future<void> _chooseSource() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('เลือกรูปจากคลัง'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('ถ่ายรูป'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pick(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final bytes = _bytes;
    if (bytes == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.profileRepository.uploadCover(
        userId: widget.profile.id,
        bytes: bytes,
        fileExtension: _extension,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'อัปโหลดรูปปกไม่สำเร็จ ลองใหม่อีกครั้ง');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _bytes == null
        ? (widget.profile.coverUrl == null
            ? Container(color: WynColors.surfaceTint)
            : Image.network(widget.profile.coverUrl!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    Container(color: WynColors.surfaceTint)))
        : Image.memory(_bytes!, fit: BoxFit.cover);

    return Scaffold(
      backgroundColor: WynColors.paper,
      appBar: AppBar(
        backgroundColor: WynColors.paper,
        title: const Text('รูปปกโปรไฟล์'),
        actions: [
          TextButton(
            onPressed: _bytes == null || _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('บันทึก'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(WynSpacing.space5),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(WynSpacing.radiusLg),
            child: AspectRatio(aspectRatio: 16 / 7, child: preview),
          ),
          const SizedBox(height: WynSpacing.space4),
          OutlinedButton.icon(
            onPressed: _saving ? null : _chooseSource,
            icon: const Icon(Icons.image_outlined),
            label: const Text('เลือกรูปปก'),
          ),
          const SizedBox(height: WynSpacing.space2),
          Text(
            'รูปแนวนอนจะดูดีที่สุด และ WYNOS จะครอปให้พอดีกับพื้นที่ปกอัตโนมัติ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: WynColors.mutedNeutral,
                ),
          ),
          if (_error != null) ...[
            const SizedBox(height: WynSpacing.space3),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}
''')

write('app/lib/features/profile/presentation/widgets/profile_pinned_drops_sheet.dart', r'''import 'package:flutter/material.dart';

import '../../../drop/data/drop.dart';
import '../../../drop/data/drop_repository.dart';
import '../../../../core/design/wyn_colors.dart';
import '../../../../core/design/wyn_spacing.dart';

Future<bool> showProfilePinnedDropsSheet(
  BuildContext context, {
  required DropRepository dropRepository,
  required String authorId,
}) async {
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        builder: (_) => _ProfilePinnedDropsSheet(
          dropRepository: dropRepository,
          authorId: authorId,
        ),
      ) ??
      false;
}

class _ProfilePinnedDropsSheet extends StatefulWidget {
  const _ProfilePinnedDropsSheet({
    required this.dropRepository,
    required this.authorId,
  });

  final DropRepository dropRepository;
  final String authorId;

  @override
  State<_ProfilePinnedDropsSheet> createState() =>
      _ProfilePinnedDropsSheetState();
}

class _ProfilePinnedDropsSheetState extends State<_ProfilePinnedDropsSheet> {
  List<Drop> _pinned = const [];
  List<Drop> _recent = const [];
  bool _loading = true;
  bool _changed = false;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pinnedFuture = widget.dropRepository
          .fetchPinnedByAuthor(authorId: widget.authorId);
      final recentFuture = widget.dropRepository.fetchByAuthor(
        authorId: widget.authorId,
        page: 0,
      );
      final pinned = await pinnedFuture;
      final recent = await recentFuture;
      if (!mounted) return;
      setState(() {
        _pinned = pinned;
        _recent = recent;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Drop drop, bool isPinned) async {
    if (_busyId != null) return;
    setState(() => _busyId = drop.id);
    try {
      if (isPinned) {
        await widget.dropRepository.unpinProfileDrop(drop.id);
      } else {
        await widget.dropRepository.pinProfileDrop(drop.id);
      }
      _changed = true;
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPinned
              ? 'เลิกปักหมุดไม่สำเร็จ ลองใหม่อีกครั้ง'
              : 'ปักหมุดได้สูงสุด 3 โพสต์ หรือเกิดข้อผิดพลาด กรุณาลองใหม่'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinnedIds = _pinned.map((d) => d.id).toSet();
    final all = <Drop>[
      ..._pinned,
      ..._recent.where((d) => !pinnedIds.contains(d.id)),
    ];

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                WynSpacing.space4,
                WynSpacing.space3,
                WynSpacing.space2,
                WynSpacing.space2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'จัดการโพสต์ปักหมุด (${_pinned.length}/3)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'เสร็จ',
                    onPressed: () => Navigator.of(context).pop(_changed),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : all.isEmpty
                      ? const Center(child: Text('ยังไม่มีโพสต์ให้ปักหมุด'))
                      : ListView.separated(
                          itemCount: all.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final drop = all[index];
                            final pinned = pinnedIds.contains(drop.id);
                            final disabled = !pinned && _pinned.length >= 3;
                            return ListTile(
                              leading: _DropThumb(drop: drop),
                              title: Text(
                                (drop.caption?.trim().isNotEmpty ?? false)
                                    ? drop.caption!.trim()
                                    : 'โพสต์รูปภาพ',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: pinned
                                  ? const Text('ปักหมุดอยู่')
                                  : null,
                              trailing: TextButton(
                                onPressed: disabled || _busyId == drop.id
                                    ? null
                                    : () => _toggle(drop, pinned),
                                child: _busyId == drop.id
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : Text(pinned ? 'เลิกปัก' : 'ปักหมุด'),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropThumb extends StatelessWidget {
  const _DropThumb({required this.drop});
  final Drop drop;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: WynColors.surfaceTint,
        borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
      ),
      child: const Icon(Icons.notes, size: 20),
    );
    if (drop.imageUrl == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
      child: Image.network(
        drop.imageUrl!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }
}
''')

# ---------------------------------------------------------------------------
# Profile tab: pinned shelf + unified refresh.
# ---------------------------------------------------------------------------
grid_path = 'app/lib/features/profile/presentation/widgets/profile_drop_grid_tab.dart'
replace_once(grid_path, "import '../view_profile_screen.dart';\n", "import '../view_profile_screen.dart';\nimport 'profile_pinned_drops_sheet.dart';\n")
replace_once(grid_path, '    required this.emptyText,\n    this.onRefreshHeader,',
             '    required this.emptyText,\n    this.isOwnProfile = false,\n    this.onRefreshHeader,')
replace_once(grid_path, '  final String emptyText;\n', '  final String emptyText;\n  final bool isOwnProfile;\n')
replace_once(grid_path, '  final VoidCallback? onRefreshHeader;', '  final Future<void> Function()? onRefreshHeader;')
replace_once(grid_path, '  final List<Drop> _drops = [];\n', '  final List<Drop> _drops = [];\n  final List<Drop> _pinnedDrops = [];\n')

sub_once(
    grid_path,
    r'  Future<void> _loadInitial\(\) async \{[\s\S]*?\n  \}\n\n  // Only used by RefreshIndicator',
    r'''  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final pinnedFuture = widget.dropRepository
          .fetchPinnedByAuthor(authorId: widget.authorId);
      final postsFuture = widget.dropRepository.fetchByAuthor(
        authorId: widget.authorId,
        page: 0,
      );
      final pinned = await pinnedFuture;
      final fetched = await postsFuture;
      final pinnedIds = pinned.map((d) => d.id).toSet();
      final drops = fetched.where((d) => !pinnedIds.contains(d.id)).toList();
      if (!mounted) return;
      setState(() {
        _pinnedDrops
          ..clear()
          ..addAll(pinned);
        _drops
          ..clear()
          ..addAll(drops);
        _seenKeys
          ..clear()
          ..addAll(drops.map((d) => d.id));
        _page = 0;
        _hasMore = fetched.length == DropRepository.pageSize;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'โหลดโพสต์ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  // Only used by RefreshIndicator''',
)
sub_once(
    grid_path,
    r'  Future<void> _onPullToRefresh\(\) async \{\n    widget\.onRefreshHeader\?\.call\(\);\n    await _loadInitial\(\);\n  \}',
    r'''  Future<void> _onPullToRefresh() async {
    final headerRefresh = widget.onRefreshHeader;
    if (headerRefresh == null) {
      await _loadInitial();
      return;
    }
    await Future.wait([headerRefresh(), _loadInitial()]);
  }''',
)
replace_once(
    grid_path,
    '        for (final drop in drops) {\n          if (_seenKeys.add(drop.id)) _drops.add(drop);\n        }',
    '        final pinnedIds = _pinnedDrops.map((d) => d.id).toSet();\n        for (final drop in drops) {\n          if (pinnedIds.contains(drop.id)) continue;\n          if (_seenKeys.add(drop.id)) _drops.add(drop);\n        }',
)

manage_method = r'''

  Future<void> _openPinnedManager() async {
    final changed = await showProfilePinnedDropsSheet(
      context,
      dropRepository: widget.dropRepository,
      authorId: widget.authorId,
    );
    if (changed && mounted) await _loadInitial();
  }
'''
replace_once(grid_path, '  Future<void> _toggleLike(String dropId) async {',
             manage_method + '\n  Future<void> _toggleLike(String dropId) async {')

replace_once(
    grid_path,
    '    if (_drops.isEmpty) {\n      return Center(child: Text(widget.emptyText));\n    }',
    '    if (_drops.isEmpty && _pinnedDrops.isEmpty) {\n      return Center(child: Text(widget.emptyText));\n    }',
)
replace_once(
    grid_path,
    '          slivers: [\n            // The last full-width post card had no breathing room above',
    '''          slivers: [
            if (_pinnedDrops.isNotEmpty || widget.isOwnProfile)
              SliverToBoxAdapter(
                child: _PinnedDropsSection(
                  drops: _pinnedDrops,
                  canManage: widget.isOwnProfile,
                  onManage: _openPinnedManager,
                  onOpen: _openDropDetail,
                ),
              ),
            // The last full-width post card had no breathing room above''',
)

pinned_widgets = r'''

class _PinnedDropsSection extends StatelessWidget {
  const _PinnedDropsSection({
    required this.drops,
    required this.canManage,
    required this.onManage,
    required this.onOpen,
  });

  final List<Drop> drops;
  final bool canManage;
  final VoidCallback onManage;
  final ValueChanged<Drop> onOpen;

  @override
  Widget build(BuildContext context) {
    if (drops.isEmpty && !canManage) return const SizedBox.shrink();
    return Padding(
      key: const Key('profile_pinned_drops_section'),
      padding: const EdgeInsets.fromLTRB(
        WynSpacing.space4,
        WynSpacing.space3,
        WynSpacing.space4,
        WynSpacing.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  drops.isEmpty ? 'โพสต์เด่น' : 'ปักหมุด (${drops.length})',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (canManage)
                TextButton(
                  onPressed: onManage,
                  child: Text(drops.isEmpty ? 'ปักหมุดโพสต์' : 'จัดการ'),
                ),
            ],
          ),
          if (drops.isNotEmpty) ...[
            const SizedBox(height: WynSpacing.space1),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: WynSpacing.space2),
                  Expanded(
                    child: i < drops.length
                        ? _PinnedDropTile(
                            drop: drops[i],
                            onTap: () => onOpen(drops[i]),
                          )
                        : canManage
                            ? _EmptyPinnedSlot(onTap: onManage)
                            : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PinnedDropTile extends StatelessWidget {
  const _PinnedDropTile({required this.drop, required this.onTap});
  final Drop drop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      padding: const EdgeInsets.all(WynSpacing.space2),
      alignment: Alignment.center,
      color: WynColors.surfaceTint,
      child: Text(
        (drop.caption?.trim().isNotEmpty ?? false) ? drop.caption!.trim() : 'โพสต์',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
    return Semantics(
      button: true,
      label: 'เปิดโพสต์ปักหมุด',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (drop.imageUrl == null)
                  fallback
                else
                  Image.network(
                    drop.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => fallback,
                  ),
                const Positioned(
                  top: WynSpacing.space1,
                  right: WynSpacing.space1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: WynColors.ink,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(Icons.push_pin, size: 13, color: WynColors.paper),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPinnedSlot extends StatelessWidget {
  const _EmptyPinnedSlot({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      child: AspectRatio(
        aspectRatio: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: WynColors.surfaceTint,
            borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
          ),
          child: const Icon(Icons.add, color: WynColors.mutedNeutral),
        ),
      ),
    );
  }
}
'''
text = read(grid_path)
if not text.rstrip().endswith('}'):
    raise SystemExit(f'{grid_path}: unexpected ending')
# Append helper widgets after the State class.
write(grid_path, text.rstrip() + pinned_widgets + '\n')

for tab_path in [
    'app/lib/features/profile/presentation/widgets/profile_redrops_tab.dart',
    'app/lib/features/profile/presentation/widgets/profile_likes_tab.dart',
]:
    replace_once(tab_path, '  final VoidCallback? onRefreshHeader;',
                 '  final Future<void> Function()? onRefreshHeader;')
    sub_once(
        tab_path,
        r'  Future<void> _onPullToRefresh\(\) async \{\n    widget\.onRefreshHeader\?\.call\(\);\n    await _loadInitial\(\);\n  \}',
        r'''  Future<void> _onPullToRefresh() async {
    final headerRefresh = widget.onRefreshHeader;
    if (headerRefresh == null) {
      await _loadInitial();
      return;
    }
    await Future.wait([headerRefresh(), _loadInitial()]);
  }''',
    )

# ---------------------------------------------------------------------------
# ViewProfileScreen — compact app-bar identity + new full header.
# ---------------------------------------------------------------------------
view_path = 'app/lib/features/profile/presentation/view_profile_screen.dart'
replace_once(view_path, "import 'widgets/profile_recommendation_section.dart';\n", '')
replace_once(view_path, "import '../../search/data/discovery_repository.dart';\n", '')
replace_once(view_path, "import 'widgets/profile_skeleton.dart';\n", "import 'widgets/profile_skeleton.dart';\nimport 'widgets/profile_v2_header.dart';\nimport 'profile_cover_editor_screen.dart';\n")
replace_once(view_path, '  late Future<_ProfileWithCounts> _loadFuture;\n',
             '  late Future<_ProfileWithCounts> _loadFuture;\n  final ScrollController _profileScrollController = ScrollController();\n  bool _showCompactIdentity = false;\n')
replace_once(view_path, '    super.initState();\n    _loadFuture = _load();',
             '    super.initState();\n    _profileScrollController.addListener(_onProfileScroll);\n    _loadFuture = _load();')

# Remove the now-unwanted profile recommendation repository block.
sub_once(
    view_path,
    r'\n  // WYN-071 Screen 5 -- same optional/defaulted shape[\s\S]*?\n  late final DiscoveryRepository _discoveryRepository = DiscoveryRepository\([\s\S]*?\n  \);\n',
    '\n',
)

scroll_methods = r'''

  void _onProfileScroll() {
    final next = _profileScrollController.hasClients &&
        _profileScrollController.offset > 150;
    if (next == _showCompactIdentity || !mounted) return;
    setState(() => _showCompactIdentity = next);
  }

  @override
  void dispose() {
    _profileScrollController
      ..removeListener(_onProfileScroll)
      ..dispose();
    super.dispose();
  }
'''
replace_once(view_path, '  // Profile and Follower/Following counts are loaded together as one\n',
             scroll_methods + '\n  // Profile and Follower/Following counts are loaded together as one\n')

sub_once(
    view_path,
    r'  void _reload\(\) \{[\s\S]*?\n  \}\n\n  Future<void> _loadFollowStatus',
    r'''  Future<void> _reload() async {
    final next = _load();
    setState(() => _loadFuture = next);
    await next;
    if (!mounted) return;
    if (_isOwnProfile) {
      await _loadPendingRequestCount();
    } else {
      await Future.wait([
        _loadFollowStatus(),
        _loadBlockRelationship(),
        _loadMuteStatus(),
        _loadPendingRequestStatus(),
      ]);
    }
  }

  Future<void> _loadFollowStatus''',
)

cover_open = r'''

  Future<void> _openCoverEditor(Profile profile) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfileCoverEditorScreen(
          profileRepository: widget.profileRepository,
          profile: profile,
        ),
      ),
    );
    if (changed == true && mounted) await _reload();
  }
'''
replace_once(view_path, '  Future<void> _reportUser() {', cover_open + '\n  Future<void> _reportUser() {')

helpers = r'''

  Widget _buildAppBarTitle(bool isOwnProfile) {
    if (!isOwnProfile) {
      return FutureBuilder<_ProfileWithCounts>(
        future: _loadFuture,
        builder: (context, snapshot) {
          final username = snapshot.data?.profile.username;
          return Text(
            username == null ? 'โปรไฟล์' : '@$username',
            style: _textStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: WynColors.ink,
            ),
          );
        },
      );
    }

    if (!_showCompactIdentity) {
      return Text(
        'โปรไฟล์',
        style: WynTypography.screenTitle(fontSize: 16, color: WynColors.ink),
      );
    }

    return FutureBuilder<_ProfileWithCounts>(
      future: _loadFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data?.profile;
        if (profile == null) return const SizedBox.shrink();
        return Row(
          key: const Key('profile_v2_compact_identity'),
          children: [
            AvatarCircle(
              imageUrl: profile.avatarUrl,
              fallbackText: profile.username,
              radius: 15,
            ),
            const SizedBox(width: WynSpacing.space2),
            Expanded(
              child: Text(
                profile.nameOrUsername,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _textStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: WynColors.ink,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileNameRow(Profile profile, bool isOwnProfile) {
    if (isOwnProfile) {
      return _AccountSwitcherName(
        name: profile.nameOrUsername,
        isVerified: profile.isVerified,
        onTap: _openAccountSwitcher,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            profile.nameOrUsername,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _textStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: WynColors.ink,
            ),
          ),
        ),
        if (profile.isVerified) ...[
          const SizedBox(width: WynSpacing.space1),
          const VerifiedBadge(),
        ],
      ],
    );
  }

  Widget? _buildOtherProfileActions(Profile profile) {
    if (_isOwnProfile || _isFollowing == null) return null;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: _followButtonSemanticsLabel(profile),
            excludeSemantics: true,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                backgroundColor: _isFollowing!
                    ? WynColors.surfaceTint
                    : WynColors.sapphire,
                foregroundColor:
                    _isFollowing! ? WynColors.graphite : WynColors.paper,
              ),
              onPressed: _isFollowActionInFlight
                  ? null
                  : () => _onFollowButtonPressed(profile),
              child: Text(_followButtonLabel(profile)),
            ),
          ),
        ),
        const SizedBox(width: WynSpacing.space2),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              side: const BorderSide(color: WynColors.hairline),
              foregroundColor: WynColors.ink,
            ),
            onPressed: _isStartingChat ? null : () => _openChat(profile),
            icon: _isStartingChat
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined, size: 16),
            label: const Text('ส่งข้อความ'),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingRequestEntry() {
    return InkWell(
      onTap: _openFollowRequests,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),
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
    );
  }
'''
replace_once(view_path, '  String _gridEmptyText({', helpers + '\n  String _gridEmptyText({')

# Replace AppBar title with compact identity builder.
sub_once(
    view_path,
    r'          title: isOwnProfile[\s\S]*?\n          actions: \[',
    r'''          title: _buildAppBarTitle(isOwnProfile),
          actions: [''',
)

# Add a small Edit icon beside Settings (the large full-width button is gone).
replace_once(
    view_path,
    "            if (isOwnProfile) ...[\n              IconButton(\n                icon: const Icon(Icons.settings_outlined),",
    "            if (isOwnProfile) ...[\n              FutureBuilder<_ProfileWithCounts>(\n                future: _loadFuture,\n                builder: (context, snapshot) => IconButton(\n                  icon: const Icon(Icons.edit_outlined),\n                  tooltip: 'แก้ไขโปรไฟล์',\n                  onPressed: snapshot.hasData\n                      ? () => _openEdit(snapshot.data!.profile)\n                      : null,\n                ),\n              ),\n              IconButton(\n                icon: const Icon(Icons.settings_outlined),",
)
replace_once(view_path, '            return NestedScrollView(\n',
             '            return NestedScrollView(\n              controller: _profileScrollController,\n')

# Replace the large Beta4 identity block with ProfileV2Header and remove
# the recommendation shelf that was making other profiles even taller.
sub_once(
    view_path,
    r'                SliverToBoxAdapter\(\n                  child:\n[\s\S]*?\n                \),\n                if \(!isOwnProfile\)\n                  SliverToBoxAdapter\(\n                    child: ProfileRecommendationSection\([\s\S]*?\n                  \),\n',
    r'''                SliverToBoxAdapter(
                  child: ProfileV2Header(
                    profile: profile,
                    nameRow: _buildProfileNameRow(profile, isOwnProfile),
                    followingCount: data.followingCount,
                    followerCount: data.followerCount,
                    onFollowingTap: () => _openFollowList(
                      FollowListMode.following,
                      isLockedPrivate: isLockedPrivate,
                    ),
                    onFollowersTap: () => _openFollowList(
                      FollowListMode.followers,
                      isLockedPrivate: isLockedPrivate,
                    ),
                    onEditCover:
                        isOwnProfile ? () => _openCoverEditor(profile) : null,
                    blockedBanner:
                        isBlockedEitherWay ? _buildBlockedBanner() : null,
                    actionRow: isBlockedEitherWay
                        ? null
                        : _buildOtherProfileActions(profile),
                    pendingRequestEntry: isOwnProfile &&
                            profile.isPrivate &&
                            _pendingRequestCount > 0
                        ? _buildPendingRequestEntry()
                        : null,
                  ),
                ),
''',
)

replace_once(
    view_path,
    '                    authorId: widget.userId,\n                    onRefreshHeader: _reload,',
    '                    authorId: widget.userId,\n                    isOwnProfile: isOwnProfile,\n                    onRefreshHeader: _reload,',
)

# ---------------------------------------------------------------------------
# DB migration + schema baseline + integration test.
# ---------------------------------------------------------------------------
migration = r'''-- WYN-155 / WYNOS v1.0.0 Beta5 Profile V2
-- Cover image metadata + atomic max-3 pinned Drops.

begin;

alter table public.profiles
  add column if not exists cover_url text;

alter table public.drops
  add column if not exists profile_pin_position smallint;

alter table public.drops
  drop constraint if exists drops_profile_pin_position_check;
alter table public.drops
  add constraint drops_profile_pin_position_check
  check (profile_pin_position is null or profile_pin_position between 1 and 3);

create unique index if not exists drops_author_profile_pin_position_unique
  on public.drops(author_id, profile_pin_position)
  where profile_pin_position is not null and deleted_at is null;

create or replace function public.clear_profile_pin_on_soft_delete()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  if new.deleted_at is not null and old.deleted_at is null then
    new.profile_pin_position := null;
  end if;
  return new;
end;
$$;

drop trigger if exists drops_clear_profile_pin_on_soft_delete on public.drops;
create trigger drops_clear_profile_pin_on_soft_delete
before update of deleted_at on public.drops
for each row
execute function public.clear_profile_pin_on_soft_delete();

create or replace function public.pin_profile_drop(p_drop_id uuid)
returns smallint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
  v_existing smallint;
  v_position smallint;
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('profile-pin:' || v_user_id::text, 0)
  );

  select d.profile_pin_position
    into v_existing
  from public.drops d
  where d.id = p_drop_id
    and d.author_id = v_user_id
    and d.deleted_at is null;

  if not found then
    raise exception 'drop_not_owned_or_not_found' using errcode = '42501';
  end if;

  if v_existing is not null then
    return v_existing;
  end if;

  select s.position::smallint
    into v_position
  from generate_series(1, 3) as s(position)
  where not exists (
    select 1
    from public.drops d
    where d.author_id = v_user_id
      and d.deleted_at is null
      and d.profile_pin_position = s.position
  )
  order by s.position
  limit 1;

  if v_position is null then
    raise exception 'profile_pin_limit_reached' using errcode = 'P0001';
  end if;

  update public.drops
  set profile_pin_position = v_position
  where id = p_drop_id
    and author_id = v_user_id
    and deleted_at is null;

  return v_position;
end;
$$;

create or replace function public.unpin_profile_drop(p_drop_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;

  update public.drops
  set profile_pin_position = null
  where id = p_drop_id
    and author_id = v_user_id;

  if not found then
    raise exception 'drop_not_owned_or_not_found' using errcode = '42501';
  end if;
end;
$$;

revoke all on function public.pin_profile_drop(uuid) from public;
revoke all on function public.unpin_profile_drop(uuid) from public;
grant execute on function public.pin_profile_drop(uuid) to authenticated;
grant execute on function public.unpin_profile_drop(uuid) to authenticated;

commit;
'''
write('supabase/migrations_wyn155_beta5_profile_v2.sql', migration)

schema_path = 'supabase/schema.sql'
schema = read(schema_path)
if 'WYN-155 / WYNOS v1.0.0 Beta5 Profile V2' not in schema:
    write(schema_path, schema.rstrip() + '\n\n' + migration + '\n')

write('supabase/tests/wyn_155_beta5_profile_v2_test.sh', r'''#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MIGRATION="$SCRIPT_DIR/../migrations_wyn155_beta5_profile_v2.sql"
DB="wyn155_profile_v2_${RANDOM}_$$"
trap 'dropdb --if-exists "$DB" >/dev/null 2>&1 || true' EXIT

createdb "$DB"
psql -d "$DB" -v ON_ERROR_STOP=1 <<'SQL'
create schema auth;
create role authenticated nologin;
create role anon nologin;
create or replace function auth.uid() returns uuid
language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

create table public.profiles(
  id uuid primary key,
  username text
);
create table public.drops(
  id uuid primary key,
  author_id uuid not null references public.profiles(id) on delete cascade,
  deleted_at timestamptz
);

insert into public.profiles(id, username) values
 ('11111111-1111-1111-1111-111111111111', 'one'),
 ('22222222-2222-2222-2222-222222222222', 'two');
insert into public.drops(id, author_id) values
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','11111111-1111-1111-1111-111111111111'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2','11111111-1111-1111-1111-111111111111'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3','11111111-1111-1111-1111-111111111111'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4','11111111-1111-1111-1111-111111111111'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1','22222222-2222-2222-2222-222222222222');
SQL
psql -d "$DB" -v ON_ERROR_STOP=1 -f "$MIGRATION" >/dev/null

psql -d "$DB" -Atqc "select exists(select 1 from information_schema.columns where table_schema='public' and table_name='profiles' and column_name='cover_url')" | grep -qx t
psql -d "$DB" -Atqc "select exists(select 1 from information_schema.columns where table_schema='public' and table_name='drops' and column_name='profile_pin_position')" | grep -qx t
psql -d "$DB" -Atqc "select has_function_privilege('authenticated','public.pin_profile_drop(uuid)','execute')" | grep -qx t
psql -d "$DB" -Atqc "select has_function_privilege('anon','public.pin_profile_drop(uuid)','execute')" | grep -qx f

for n in 1 2 3; do
  psql -d "$DB" -v ON_ERROR_STOP=1 -Atqc "set role authenticated; set request.jwt.claim.sub='11111111-1111-1111-1111-111111111111'; select public.pin_profile_drop('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa${n}')" | tail -n1 | grep -qx "$n"
done

if psql -d "$DB" -v ON_ERROR_STOP=1 -qc "set role authenticated; set request.jwt.claim.sub='11111111-1111-1111-1111-111111111111'; select public.pin_profile_drop('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4')" >/dev/null 2>&1; then
  echo "expected fourth pin to fail" >&2
  exit 1
fi

if psql -d "$DB" -v ON_ERROR_STOP=1 -qc "set role authenticated; set request.jwt.claim.sub='22222222-2222-2222-2222-222222222222'; select public.unpin_profile_drop('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1')" >/dev/null 2>&1; then
  echo "expected cross-owner unpin to fail" >&2
  exit 1
fi

psql -d "$DB" -v ON_ERROR_STOP=1 -qc "set role authenticated; set request.jwt.claim.sub='11111111-1111-1111-1111-111111111111'; select public.unpin_profile_drop('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2')" >/dev/null
psql -d "$DB" -v ON_ERROR_STOP=1 -Atqc "set role authenticated; set request.jwt.claim.sub='11111111-1111-1111-1111-111111111111'; select public.pin_profile_drop('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4')" | tail -n1 | grep -qx 2

# Soft-delete clears a pin before the unique partial index can become a
# restore-time trap later.
psql -d "$DB" -v ON_ERROR_STOP=1 -qc "update public.drops set deleted_at=now() where id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'" >/dev/null
psql -d "$DB" -Atqc "select profile_pin_position is null from public.drops where id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'" | grep -qx t

echo "WYN-155 BETA5 PROFILE V2 CHECKS PASSED"
''')

# ---------------------------------------------------------------------------
# Version metadata + tests/docs.
# ---------------------------------------------------------------------------
pubspec_path = 'app/pubspec.yaml'
replace_once(pubspec_path, 'description: WYNOS — social app (V1.0.0 Beta4)\nversion: 1.0.0+4',
             'description: WYNOS — social app (V1.0.0 Beta5)\nversion: 1.0.0+5')
app_version_path = 'app/lib/core/app_version.dart'
replace_once(app_version_path, "  static const String stable = 'V1.0.0 Beta4';",
             "  static const String stable = 'V1.0.0 Beta5';")
replace_once(app_version_path, "  static const String developerPreview = 'V1.0.0 Beta5 [พัฒนาอยู่]';",
             "  static const String developerPreview = 'V1.0.0 Beta5';")

audit_path = 'app/test/audit_remaining_regression_test.dart'
text = read(audit_path)
text = text.replace("test('BUG-005 package metadata matches stable Beta4'", "test('package metadata matches stable Beta5'")
text = text.replace('description: WYNOS — social app (V1.0.0 Beta4)', 'description: WYNOS — social app (V1.0.0 Beta5)')
text = text.replace('version: 1.0.0+4', 'version: 1.0.0+5')
write(audit_path, text)

# Existing Beta4 layout assertions expected the now-removed large edit
# button. Keep the important responsive assertions while updating the UI
# contract to Beta5's compact edit icon.
view_test = 'app/test/view_profile_screen_test.dart'
text = read(view_test)
text = text.replace("expect(find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์'), findsOneWidget);",
                    "expect(find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์'), findsNothing);")
text = re.sub(
    r"      final button =\n          tester\.getRect\(find\.widgetWithText\(OutlinedButton, 'แก้ไขโปรไฟล์'\)\);\n      expect\(button\.left, greaterThanOrEqualTo\(0\)\);\n      expect\(button\.right, lessThanOrEqualTo\(320\)\);",
    "      expect(find.byKey(const Key('profile_v2_full_header')), findsOneWidget);",
    text,
)
text = re.sub(
    r"\n    final buttonTop =\n        tester\.getTopLeft\(find\.widgetWithText\(OutlinedButton, 'แก้ไขโปรไฟล์'\)\)\.dy;",
    '',
    text,
)
text = text.replace('    expect(buttonTop, greaterThan(statsTop));\n', '')
text = re.sub(
    r"\n    final buttonRect =\n        tester\.getRect\(find\.widgetWithText\(OutlinedButton, 'แก้ไขโปรไฟล์'\)\);\n    expect\(\(buttonRect\.left - columnLeft\)\.abs\(\), lessThan\(2\)\);",
    '',
    text,
)
write(view_test, text)

qa_path = 'app/test/qa_wyn110_profile_scroll_header_test.dart'
text = read(qa_path)
text = text.replace("expect(find.text('แก้ไขโปรไฟล์'), findsOneWidget);",
                    "expect(find.byKey(const Key('profile_v2_full_header')), findsOneWidget);")
text = text.replace("expect(find.text('แก้ไขโปรไฟล์'), findsNothing);",
                    "expect(find.byKey(const Key('profile_v2_full_header')), findsNothing);")
write(qa_path, text)

write('app/test/beta5_profile_v2_test.dart', r'''import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_v2_header.dart';

void main() {
  test('Beta5 Profile parses cover_url', () {
    final profile = Profile.fromMap({
      'id': 'me',
      'username': 'warren',
      'cover_url': 'https://example.com/cover.jpg',
    });
    expect(profile.coverUrl, 'https://example.com/cover.jpg');
  });

  testWidgets('Beta5 full header keeps the large edit/link band out',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfileV2Header(
            profile: const Profile(
              id: 'me',
              username: 'warren',
              displayName: 'WARREN',
              bio: 'WYNOS',
            ),
            nameRow: const Text('WARREN'),
            followingCount: 3,
            followerCount: 6,
            onFollowingTap: () {},
            onFollowersTap: () {},
            onEditCover: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('profile_v2_full_header')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์'), findsNothing);
    expect(find.byKey(const Key('profile_cover_edit_button')), findsOneWidget);
  });
}
''')

release_path = 'RELEASE_NOTES.md'
release = read(release_path)
release = release.replace('## Current release — WYNOS v1.0.0 Beta4',
                          '## Current release — WYNOS v1.0.0 Beta5', 1)
marker = '## Current release — WYNOS v1.0.0 Beta5\n'
if marker in release and '### Profile V2' not in release.split(marker, 1)[1][:1200]:
    release = release.replace(
        marker,
        marker + '\n### Profile V2\n- Unified pull-to-refresh for profile identity + active content tab.\n- Compact cover/avatar identity header; large edit/link band removed so posts start sooner.\n- Header collapses into a compact identity in the top bar while scrolling.\n- Profile cover upload and up to 3 atomic pinned Drops.\n\n',
        1,
    )
write(release_path, release)

write('.wyn/docs/product/wynos-v1.0.0-beta5-profile-v2.md', r'''# WYNOS v1.0.0 Beta5 — Profile V2

Founder-approved direction (2026-09-10): profile-first, post-forward.

## Locked decisions
- Pull down once refreshes the profile identity/counts and the active tab together.
- Add a compact cover image with avatar overlap.
- The full-width `แก้ไขโปรไฟล์` + profile-link button band is removed; it consumed too much vertical space and hid the first post.
- Basic Edit Profile remains available as a small top-bar edit icon.
- Cover is edited directly from the cover camera button.
- Header scrolls away and the top bar becomes a compact avatar/name identity while reading posts.
- Up to 3 Drops can be pinned to a small Profile shelf; pinning is atomic and owner-only.
- No new unrelated social surfaces are added in this scope.
''')

print('Beta5 Profile V2 patch applied successfully')

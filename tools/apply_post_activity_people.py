from pathlib import Path


def insert_before_once(path: Path, anchor: str, addition: str) -> None:
    text = path.read_text()
    if addition.strip() in text:
        return
    if anchor not in text:
        raise SystemExit(f"anchor not found in {path}: {anchor[:80]!r}")
    path.write_text(text.replace(anchor, addition + anchor, 1))


def replace_between(path: Path, start_marker: str, end_marker: str, replacement: str) -> None:
    text = path.read_text()
    start = text.find(start_marker)
    if start == -1:
        raise SystemExit(f"start marker not found in {path}: {start_marker!r}")
    end = text.find(end_marker, start)
    if end == -1:
        raise SystemExit(f"end marker not found in {path}: {end_marker!r}")
    path.write_text(text[:start] + replacement + text[end:])


repo_path = Path('app/lib/features/drop/data/drop_repository.dart')
repo_methods = '''  /// User ids that liked one Drop, newest Like first. This intentionally
  /// reads the same public interaction rows that power Drop like counts/
  /// liked-by avatars; WYN-099's likes_visibility only controls a user's
  /// profile Likes tab, not whether their Like is attributable on the
  /// post they interacted with.
  Future<List<String>> fetchLikeUserIds(String dropId) async {
    final rows = await _client
        .from('drop_likes')
        .select('user_id')
        .eq('drop_id', dropId)
        .order('created_at', ascending: false);
    final seen = <String>{};
    return rows
        .map((row) => row['user_id'] as String)
        .where(seen.add)
        .toList(growable: false);
  }

  /// User ids that ReDropped one Drop, newest ReDrop first. Both Standard
  /// and Quote ReDrops are included because [Drop.redropCount] also counts
  /// both forms; duplicate ids are collapsed defensively while preserving
  /// newest-first order.
  Future<List<String>> fetchRedropperIds(String dropId) async {
    final rows = await _client
        .from('redrops')
        .select('redropper_id')
        .eq('drop_id', dropId)
        .order('created_at', ascending: false);
    final seen = <String>{};
    return rows
        .map((row) => row['redropper_id'] as String)
        .where(seen.add)
        .toList(growable: false);
  }

'''
insert_before_once(
    repo_path,
    '  /// WYN-071: Profile\'s "Likes" tab',
    repo_methods,
)


detail_path = Path('app/lib/features/drop/presentation/drop_detail_screen.dart')
activity_block = '''  Widget _buildActivityRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        WynosFounderMetrics.detailEdgeInset,
        2,
        WynosFounderMetrics.detailEdgeInset,
        10,
      ),
      child: Material(
        color: WynColors.surfaceTint,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _openActivitySheet,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: WynosFounderMetrics.activityRowHeight,
            child: const Row(
              children: [
                SizedBox(width: 14),
                SizedBox(
                  width: 42,
                  child: Icon(
                    Icons.insights_outlined,
                    size: 22,
                    color: WynColors.graphite,
                  ),
                ),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'ดูกิจกรรม',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: WynColors.ink,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 27,
                  color: WynColors.graphite,
                ),
                SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openActivitySheet() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: WynColors.paper,
      builder: (context) => _DropActivitySheet(
        dropId: _drop.id,
        dropRepository: widget.dropRepository,
        followRepository: widget.followRepository,
        profileRepository: widget.profileRepository,
        popRepository: widget.popRepository,
        savedRepository: widget.savedRepository,
      ),
    );
  }

'''
replace_between(
    detail_path,
    '  List<DropComment> get _activityParticipants {',
    '  Widget _buildCommentRow(',
    activity_block,
)

activity_sheet_class = r'''

class _DropActivitySheet extends StatefulWidget {
  const _DropActivitySheet({
    required this.dropId,
    required this.dropRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
  });

  final String dropId;
  final DropRepository dropRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;

  @override
  State<_DropActivitySheet> createState() => _DropActivitySheetState();
}

class _DropActivitySheetState extends State<_DropActivitySheet> {
  late Future<({List<Profile> liked, List<Profile> redropped})> _activity;

  @override
  void initState() {
    super.initState();
    _activity = _loadActivity();
  }

  Future<({List<Profile> liked, List<Profile> redropped})>
      _loadActivity() async {
    final idLists = await Future.wait<List<String>>([
      widget.dropRepository.fetchLikeUserIds(widget.dropId),
      widget.dropRepository.fetchRedropperIds(widget.dropId),
    ]);
    final likedIds = idLists[0];
    final redroppedIds = idLists[1];

    final allIds = <String>[];
    final seen = <String>{};
    for (final id in [...likedIds, ...redroppedIds]) {
      if (seen.add(id)) allIds.add(id);
    }

    final profiles = await widget.profileRepository.fetchProfilesByIds(allIds);
    final byId = {for (final profile in profiles) profile.id: profile};

    return (
      liked: [
        for (final id in likedIds)
          if (byId[id] != null) byId[id]!,
      ],
      redropped: [
        for (final id in redroppedIds)
          if (byId[id] != null) byId[id]!,
      ],
    );
  }

  void _retry() {
    setState(() => _activity = _loadActivity());
  }

  void _openProfile(Profile profile) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewProfileScreen(
          profileRepository: widget.profileRepository,
          followRepository: widget.followRepository,
          dropRepository: widget.dropRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          userId: profile.id,
        ),
      ),
    );
  }

  Widget _peopleList(List<Profile> profiles, {required String emptyLabel}) {
    if (profiles.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: const TextStyle(fontSize: 14, color: WynColors.graphite),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: profiles.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 72,
        color: WynColors.hairline,
      ),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return ListTile(
          onTap: () => _openProfile(profile),
          leading: AvatarCircle(
            imageUrl: profile.avatarUrl,
            fallbackText: profile.username,
            radius: 21,
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  profile.nameOrUsername,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: WynColors.ink,
                  ),
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(width: 4),
                const VerifiedBadge(),
              ],
            ],
          ),
          subtitle: profile.username.isEmpty
              ? null
              : Text(
                  '@${profile.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: WynColors.mutedNeutral,
                  ),
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
                child: Text(
                  'กิจกรรมโพสต์',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: WynColors.ink,
                  ),
                ),
              ),
              const TabBar(
                labelColor: WynColors.ink,
                unselectedLabelColor: WynColors.graphite,
                indicatorColor: WynColors.sapphire,
                tabs: [
                  Tab(text: 'ถูกใจ'),
                  Tab(text: 'รีโพสต์'),
                ],
              ),
              const Divider(height: 1, color: WynColors.hairline),
              Expanded(
                child: FutureBuilder<
                    ({List<Profile> liked, List<Profile> redropped})>(
                  future: _activity,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('โหลดกิจกรรมไม่สำเร็จ'),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _retry,
                              child: const Text('ลองใหม่'),
                            ),
                          ],
                        ),
                      );
                    }
                    final data = snapshot.data!;
                    return TabBarView(
                      children: [
                        _peopleList(
                          data.liked,
                          emptyLabel: 'ยังไม่มีใครถูกใจโพสต์นี้',
                        ),
                        _peopleList(
                          data.redropped,
                          emptyLabel: 'ยังไม่มีใครรีโพสต์โพสต์นี้',
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
'''
text = detail_path.read_text()
if 'class _DropActivitySheet extends StatefulWidget' not in text:
    detail_path.write_text(text.rstrip() + activity_sheet_class + '\n')


fake_drop_path = Path('app/test/support/recording_drop_repository.dart')
fake_drop_addition = '''  /// Canned activity actor ids used by DropDetailScreen's activity sheet.
  /// Keys are Drop ids; list order is newest interaction first, matching
  /// the real repository methods.
  Map<String, List<String>> likeUserIdsByDrop = {};
  Map<String, List<String>> redropperIdsByDrop = {};
  Object? fetchActivityPeopleError;
  int fetchLikeUserIdsCalls = 0;
  int fetchRedropperIdsCalls = 0;

  @override
  Future<List<String>> fetchLikeUserIds(String dropId) async {
    fetchLikeUserIdsCalls++;
    if (fetchActivityPeopleError != null) throw fetchActivityPeopleError!;
    return likeUserIdsByDrop[dropId] ?? const <String>[];
  }

  @override
  Future<List<String>> fetchRedropperIds(String dropId) async {
    fetchRedropperIdsCalls++;
    if (fetchActivityPeopleError != null) throw fetchActivityPeopleError!;
    return redropperIdsByDrop[dropId] ?? const <String>[];
  }

'''
insert_before_once(
    fake_drop_path,
    '  /// Returned by [searchByCaption] for page 0 only',
    fake_drop_addition,
)


fake_profile_path = Path('app/test/support/recording_profile_repository.dart')
fake_profile_addition = '''  /// Canned bulk profile rows for callers that already have actor ids.
  /// Any id not present here falls back to [profile] when it matches,
  /// preserving the old single-profile fake behavior.
  Map<String, Profile> profilesById = {};
  int fetchProfilesByIdsCalls = 0;

  @override
  Future<List<Profile>> fetchProfilesByIds(List<String> ids) async {
    fetchProfilesByIdsCalls++;
    return ids
        .map((id) => profilesById[id] ?? (profile.id == id ? profile : null))
        .whereType<Profile>()
        .toList(growable: false);
  }

'''
insert_before_once(
    fake_profile_path,
    '  @override\n  Future<Profile?> fetchProfileByUsername',
    fake_profile_addition,
)


test_path = Path('app/test/drop_detail_screen_test.dart')
test_text = test_path.read_text()
activity_test = r'''

  testWidgets(
      'post activity shows only Like and ReDrop tabs and the people in each',
      (tester) async {
    repo.likeUserIdsByDrop['d-activity'] = ['liker-1'];
    repo.redropperIdsByDrop['d-activity'] = ['redropper-1'];
    profileRepo.profilesById = {
      'liker-1': const Profile(
        id: 'liker-1',
        username: 'mint',
        displayName: 'Mint',
      ),
      'redropper-1': const Profile(
        id: 'redropper-1',
        username: 'nine',
        displayName: 'Nine',
      ),
    };

    final activityDrop = Drop(
      id: 'd-activity',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      createdAt: DateTime.now(),
      likeCount: 1,
      commentCount: 9,
      redropCount: 1,
      viewCount: 20,
      likedByMe: false,
      savedByMe: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(
        dropRepository: repo,
        followRepository: followRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        drop: activityDrop,
      ),
    ));
    await tester.pumpAndSettle();

    final activityEntry = find.text('ดูกิจกรรม');
    await tester.ensureVisible(activityEntry);
    await tester.pumpAndSettle();
    await tester.tap(activityEntry);
    await tester.pumpAndSettle();

    expect(find.text('กิจกรรมโพสต์'), findsOneWidget);
    expect(find.text('ถูกใจ'), findsOneWidget);
    expect(find.text('รีโพสต์'), findsOneWidget);
    expect(find.text('ทั้งหมด'), findsNothing);
    expect(find.text('ความคิดเห็น'), findsNothing);
    expect(find.text('การเข้าชม'), findsNothing);

    expect(find.text('Mint'), findsOneWidget);
    expect(find.text('@mint'), findsOneWidget);

    await tester.tap(find.text('รีโพสต์'));
    await tester.pumpAndSettle();

    expect(find.text('Nine'), findsOneWidget);
    expect(find.text('@nine'), findsOneWidget);
  });
'''
if 'post activity shows only Like and ReDrop tabs' not in test_text:
    close = test_text.rfind('\n}')
    if close == -1:
        raise SystemExit('could not find final main() close in drop_detail_screen_test.dart')
    test_path.write_text(test_text[:close] + activity_test + test_text[close:])

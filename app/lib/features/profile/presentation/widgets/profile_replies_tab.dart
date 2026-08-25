import 'package:flutter/material.dart';

import '../../../drop/data/drop_comment.dart';
import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/drop_detail_screen.dart';
import '../../../follow/data/follow_repository.dart';
import '../../../pop/data/pop_repository.dart';
import '../../../saved/data/saved_repository.dart';
import '../../data/profile_repository.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/text_utils.dart';

/// "Replies" tab on a profile -- WYN-071 Design, Screen 6/7. A plain
/// list (not the grid every other tab on this screen uses) since a
/// reply is text, not media -- each row is the comment text plus just
/// enough of its parent Drop to place it in context, mirroring
/// FollowListScreen's row-list convention (WYN-008/013) rather than
/// inventing a new list style. Public to any viewer (Founder decision
/// 2026-08-24) -- see DropRepository.fetchRepliesByAuthor's own doc
/// comment on why no new RLS was needed for this.
class ProfileRepliesTab extends StatefulWidget {
  const ProfileRepliesTab({
    super.key,
    required this.dropRepository,
    required this.followRepository,
    required this.profileRepository,
    required this.popRepository,
    required this.savedRepository,
    required this.authorId,
    required this.emptyText,
  });

  final DropRepository dropRepository;
  final FollowRepository followRepository;
  final ProfileRepository profileRepository;
  final PopRepository popRepository;
  final SavedRepository savedRepository;
  final String authorId;
  final String emptyText;

  @override
  State<ProfileRepliesTab> createState() => _ProfileRepliesTabState();
}

class _ProfileRepliesTabState extends State<ProfileRepliesTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final List<ProfileReply> _replies = [];
  int _page = 0;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoadingInitial = true;
      _error = null;
    });
    try {
      final replies = await widget.dropRepository.fetchRepliesByAuthor(
        authorId: widget.authorId,
        page: 0,
      );
      setState(() {
        _replies
          ..clear()
          ..addAll(replies);
        _page = 0;
        _hasMore = replies.length == DropRepository.pageSize;
      });
    } catch (_) {
      setState(() => _error = 'โหลดการตอบกลับไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final replies = await widget.dropRepository.fetchRepliesByAuthor(
        authorId: widget.authorId,
        page: nextPage,
      );
      setState(() {
        _replies.addAll(replies);
        _page = nextPage;
        _hasMore = replies.length == DropRepository.pageSize;
      });
    } catch (_) {
      // Silent -- same posture as every other tab's own load-more.
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openDrop(ProfileReply reply) async {
    final drop = await widget.dropRepository.fetchById(reply.dropId);
    if (!mounted || drop == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DropDetailScreen(
          dropRepository: widget.dropRepository,
          followRepository: widget.followRepository,
          profileRepository: widget.profileRepository,
          popRepository: widget.popRepository,
          savedRepository: widget.savedRepository,
          drop: drop,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _loadInitial, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_replies.isEmpty) {
      return Center(child: Text(widget.emptyText));
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.separated(
        controller: _scrollController,
        itemCount: _replies.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index >= _replies.length) {
            return const Padding(
              padding: EdgeInsets.all(WynSpacing.space4),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final reply = _replies[index];
          return ListTile(
            onTap: () => _openDrop(reply),
            leading: SizedBox(
              width: 44,
              height: 44,
              child: reply.dropImageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                      child: Image.network(
                        reply.dropImageUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : null,
            ),
            title: Text(
              reply.comment.textContent,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'ตอบกลับโพสต์ของ ${reply.dropAuthorNameOrUsername} · '
              '${relativeTimeLabel(reply.comment.createdAt, now: DateTime.now())}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        },
      ),
    );
  }
}

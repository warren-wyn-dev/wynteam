import 'package:flutter/material.dart';

import '../../../profile/data/profile_repository.dart';
import '../../data/drop_draft.dart';
import '../../data/drop_repository.dart';
import '../create_drop_screen.dart';
import 'draft_grid_tile.dart';
import '../../../../core/design/wyn_spacing.dart';
import '../../../../core/widgets/empty_state_block.dart';

/// The user's saved Drafts (WYN-036), as a 3-column grid.
///
/// Beta4 §5 moved this out of Profile. A Draft is an unfinished post,
/// not something you have published -- it never belonged on the surface
/// whose entire job is showing what you *have* published, and it was
/// only reachable there through an unlabelled icon next to "แก้ไข
/// โปรไฟล์". It now lives where a draft is actually resumed: the post
/// composer's own "ร่าง" action (see [DraftsScreen], opened from
/// [CreateDropScreen]). Nothing about the Draft system itself changed --
/// this is the same widget, same repository calls, same tiles; only its
/// entry point and its home directory moved (`profile/` -> `drop/`,
/// where every other piece of the Draft feature already lived).
///
/// Not paginated -- a single `fetchDrafts()` call, same "still a small
/// personal list" reasoning ClubRepository.fetchPopularClubs/
/// HomeRepository.fetchTrending already use elsewhere in this codebase,
/// and unlike Saved/ReDrops there's no reasonable path to a Draft list
/// large enough to need it.
class DraftList extends StatefulWidget {
  const DraftList({
    super.key,
    required this.dropRepository,
    required this.profileRepository,
  });

  final DropRepository dropRepository;
  final ProfileRepository profileRepository;

  @override
  State<DraftList> createState() => _DraftListState();
}

class _DraftListState extends State<DraftList>
    with AutomaticKeepAliveClientMixin {
  List<DropDraft>? _drafts;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final drafts = await widget.dropRepository.fetchDrafts();
      if (!mounted) return;
      setState(() => _drafts = drafts);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดร่างไม่สำเร็จ');
    }
  }

  Future<void> _openDraft(DropDraft draft) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateDropScreen(
          dropRepository: widget.dropRepository,
          profileRepository: widget.profileRepository,
          draft: draft,
        ),
      ),
    );
    // Continuing to edit (re-saved) or publishing (deletes the draft)
    // both need this tab's list refreshed either way -- simpler to
    // always reload than to thread the outcome back through pop(),
    // same posture as ProfileRedropsTab's own _openDrop.
    _load();
  }

  Future<void> _deleteDraft(DropDraft draft) async {
    final previous = _drafts;
    setState(() => _drafts = _drafts?.where((d) => d.id != draft.id).toList());
    try {
      await widget.dropRepository.deleteDraft(draft.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _drafts = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลบร่างไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final drafts = _drafts;

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: WynSpacing.space3),
            TextButton(onPressed: _load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (drafts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (drafts.isEmpty) {
      // Beta4 §18: the shared [EmptyStateBlock] every other empty list
      // in the app uses (Notifications, Chat Inbox, Bookmarks), not the
      // bare centred sentence this screen had while it was a profile
      // tab -- a Draft list is empty far more often than it is full, so
      // this is the state most people will actually see.
      return const Center(
        child: EmptyStateBlock(
          icon: Icons.edit_note_outlined,
          title: 'ยังไม่มีร่าง',
          subtitle: 'เริ่มเขียนโพสต์แล้วกดบันทึกร่างไว้ก่อน '
              'จะกลับมาเขียนต่อที่นี่ได้ทุกเมื่อ',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: drafts.length,
        itemBuilder: (context, index) {
          final draft = drafts[index];
          return DraftGridTile(
            key: ValueKey(draft.id),
            draft: draft,
            onTap: () => _openDraft(draft),
            onDelete: () => _deleteDraft(draft),
          );
        },
      ),
    );
  }
}

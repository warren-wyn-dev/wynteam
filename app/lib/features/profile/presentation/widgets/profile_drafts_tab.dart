import 'package:flutter/material.dart';

import '../../../drop/data/drop_draft.dart';
import '../../../drop/data/drop_repository.dart';
import '../../../drop/presentation/create_drop_screen.dart';
import '../../../drop/presentation/widgets/draft_grid_tile.dart';
import '../../data/profile_repository.dart';
import '../../../../core/design/wyn_spacing.dart';

/// "ร่าง" (Draft) tab on a profile (WYN-036) -- only ever shown for the
/// current user's own profile (see ViewProfileScreen), same
/// own-profile-only posture as ProfileSavedTab. Not paginated -- a
/// single `fetchDrafts()` call, same "still a small personal list"
/// reasoning ClubRepository.fetchPopularClubs/HomeRepository.fetchTrending
/// already use elsewhere in this codebase, and unlike Saved/ReDrops
/// there's no reasonable path to a Draft list large enough to need it.
class ProfileDraftsTab extends StatefulWidget {
  const ProfileDraftsTab({
    super.key,
    required this.dropRepository,
    required this.profileRepository,
  });

  final DropRepository dropRepository;
  final ProfileRepository profileRepository;

  @override
  State<ProfileDraftsTab> createState() => _ProfileDraftsTabState();
}

class _ProfileDraftsTabState extends State<ProfileDraftsTab>
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: WynSpacing.space8),
          child: Text(
            'ยังไม่มีร่าง เริ่มเขียนโพสต์แล้วบันทึกไว้ก่อนได้เลย',
            textAlign: TextAlign.center,
          ),
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

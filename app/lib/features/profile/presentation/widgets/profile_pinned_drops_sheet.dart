import 'package:flutter/material.dart';

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
      final pinnedFuture = widget.dropRepository.fetchPinnedByAuthor(
        authorId: widget.authorId,
      );
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
          content: Text(
            isPinned
                ? 'เลิกปักหมุดไม่สำเร็จ ลองใหม่อีกครั้ง'
                : 'ปักหมุดได้สูงสุด 3 โพสต์ หรือเกิดข้อผิดพลาด กรุณาลองใหม่',
          ),
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
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
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
                      separatorBuilder: (_, __) => const Divider(height: 1),
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
                          subtitle: pinned ? const Text('ปักหมุดอยู่') : null,
                          trailing: TextButton(
                            onPressed: disabled || _busyId == drop.id
                                ? null
                                : () => _toggle(drop, pinned),
                            child: _busyId == drop.id
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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

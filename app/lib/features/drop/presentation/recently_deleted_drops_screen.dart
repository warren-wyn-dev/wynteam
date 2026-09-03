import 'package:flutter/material.dart';

import '../../../core/design/wyn_spacing.dart';
import '../data/drop.dart';
import '../data/drop_repository.dart';
import 'widgets/poll_placeholder_tile.dart';
import 'widgets/text_drop_placeholder_tile.dart';

/// WYN-037, Screen 4 -- the only place a user sees Drops they've
/// soft-deleted and can still restore (within the 30-day window
/// `restore_drop()` enforces server-side). Reached from Settings, not
/// from Profile -- this is account-management, not content browsing.
class RecentlyDeletedDropsScreen extends StatefulWidget {
  const RecentlyDeletedDropsScreen({super.key, required this.dropRepository});

  final DropRepository dropRepository;

  @override
  State<RecentlyDeletedDropsScreen> createState() =>
      _RecentlyDeletedDropsScreenState();
}

class _RecentlyDeletedDropsScreenState
    extends State<RecentlyDeletedDropsScreen> {
  List<Drop>? _drops;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final drops = await widget.dropRepository.fetchDeletedDrops();
      if (!mounted) return;
      setState(() => _drops = drops);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'โหลดรายการที่ลบไม่สำเร็จ');
    }
  }

  Future<void> _restore(Drop drop) async {
    final previous = _drops;
    setState(() => _drops = _drops?.where((d) => d.id != drop.id).toList());
    try {
      await widget.dropRepository.restoreDrop(drop.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _drops = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กู้คืนไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final drops = _drops;

    return Scaffold(
      appBar: AppBar(title: const Text('รายการที่ลบ')),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: WynSpacing.space3),
                  TextButton(onPressed: _load, child: const Text('ลองใหม่')),
                ],
              ),
            )
          : drops == null
              ? const Center(child: CircularProgressIndicator())
              : drops.isEmpty
                  ? const Center(child: Text('ไม่มีโพสต์ที่ลบไว้'))
                  : ListView.separated(
                      itemCount: drops.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final drop = drops[index];
                        return ListTile(
                          key: ValueKey(drop.id),
                          leading: SizedBox(
                            width: 48,
                            height: 48,
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(WynSpacing.radiusSm),
                              child: drop.imageUrl != null
                                  ? Image.network(drop.imageUrl!, fit: BoxFit.cover)
                                  : drop.isPoll
                                      ? const PollPlaceholderTile()
                                      : TextDropPlaceholderTile(
                                          caption: drop.caption ?? ''),
                            ),
                          ),
                          title: Text(
                            drop.caption?.isNotEmpty == true
                                ? drop.caption!
                                : '(ไม่มีแคปชัน)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            drop.deletedAt != null
                                ? 'ลบเมื่อ ${_formatDate(drop.deletedAt!)}'
                                : '',
                          ),
                          trailing: OutlinedButton(
                            onPressed: () => _restore(drop),
                            child: const Text('กู้คืน'),
                          ),
                        );
                      },
                    ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

import 'package:flutter/material.dart';

import '../../../search/presentation/widgets/search_state_message.dart';
import '../../data/store.dart';
import '../../data/zoky_repository.dart';
import '../store_screen.dart';
import 'store_result_card.dart';

/// Search's Store tab (ZOKY-002) -- vertical list of StoreResultCard.
/// Query comes from [query], a prop from the shared search box in
/// ZokySearchScreen, same debounce/pagination pattern as
/// SearchClubResultsTab (WYN-015). No filters here -- stores have no
/// category column, unlike products.
class ZokyStoreResultsTab extends StatefulWidget {
  const ZokyStoreResultsTab({
    super.key,
    required this.query,
    required this.zokyRepository,
  });

  final String query;
  final ZokyRepository zokyRepository;

  @override
  State<ZokyStoreResultsTab> createState() => _ZokyStoreResultsTabState();
}

class _ZokyStoreResultsTabState extends State<ZokyStoreResultsTab>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  final List<Store> _stores = [];
  int _page = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  bool get _queryTooShort => widget.query.trim().length < 2;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (!_queryTooShort) _search(reset: true);
  }

  @override
  void didUpdateWidget(covariant ZokyStoreResultsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query) {
      _stores.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
      if (!_queryTooShort) _search(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoading || !_hasMore || _queryTooShort) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _search(reset: false);
    }
  }

  Future<void> _search({required bool reset}) async {
    setState(() {
      _isLoading = true;
      if (reset) _error = null;
    });
    try {
      final page = reset ? 0 : _page + 1;
      final results = await widget.zokyRepository.searchStores(
        query: widget.query.trim(),
        page: page,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _stores
            ..clear()
            ..addAll(results);
        } else {
          _stores.addAll(results);
        }
        _page = page;
        _hasMore = results.length == ZokyRepository.searchPageSize;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'ค้นหาไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openStore(Store store) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoreScreen(zokyRepository: widget.zokyRepository, storeId: store.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_queryTooShort) {
      return const SearchStateMessage(
        icon: Icons.storefront_outlined,
        text: 'พิมพ์ชื่อร้านค้าเพื่อค้นหา',
      );
    }

    if (_isLoading && _stores.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            TextButton(onPressed: () => _search(reset: true), child: const Text('ลองใหม่')),
          ],
        ),
      );
    }

    if (_stores.isEmpty) {
      return SearchStateMessage(
        icon: Icons.storefront_outlined,
        text: 'ไม่พบร้านค้าสำหรับ "${widget.query.trim()}"',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _stores.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _stores.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final store = _stores[index];
        return StoreResultCard(store: store, onTap: () => _openStore(store));
      },
    );
  }
}

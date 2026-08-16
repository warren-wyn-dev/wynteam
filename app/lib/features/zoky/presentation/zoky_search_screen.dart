import 'dart:async';

import 'package:flutter/material.dart';

import '../data/category.dart';
import '../data/zoky_repository.dart';
import 'widgets/zoky_product_results_tab.dart';
import 'widgets/zoky_store_results_tab.dart';
import '../../../core/design/wyn_zoky_accent.dart';

/// Screen 1 — ZOKY Search (ZOKY-002), opened from ZOKY Home's search bar
/// or a category chip. Deliberately a separate screen from WYN Social's
/// SearchScreen (WYN-009) -- different entry point, different content
/// domain -- but reuses the same shared-query-box-above-a-TabBar pattern.
/// See .wyn/docs/design/zoky-002-search-and-filter.md, Screen 1.
class ZokySearchScreen extends StatefulWidget {
  const ZokySearchScreen({
    super.key,
    required this.zokyRepository,
    this.initialCategory,
  });

  final ZokyRepository zokyRepository;
  final Category? initialCategory;

  @override
  State<ZokySearchScreen> createState() => _ZokySearchScreenState();
}

class _ZokySearchScreenState extends State<ZokySearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounceTimer;

  String _query = '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String text) {
    _debounceTimer?.cancel();
    setState(() {});

    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() => _query = '');
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _query = trimmed);
    });
  }

  void _clear() {
    _debounceTimer?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    return ZokyAccentTheme(child: DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: TextField(
            controller: _controller,
            focusNode: _focusNode,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'ค้นหาสินค้า/ร้านค้า',
              border: InputBorder.none,
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : Semantics(
                      label: 'ล้างคำค้นหา',
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _clear,
                      ),
                    ),
            ),
            onChanged: _onQueryChanged,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.inventory_2_outlined), text: 'สินค้า'),
              Tab(icon: Icon(Icons.storefront_outlined), text: 'ร้านค้า'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ZokyProductResultsTab(
              query: _query,
              zokyRepository: widget.zokyRepository,
              initialCategory: widget.initialCategory,
            ),
            ZokyStoreResultsTab(
              query: _query,
              zokyRepository: widget.zokyRepository,
            ),
          ],
        ),
      ),
    ));
  }
}

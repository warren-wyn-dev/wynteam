import 'package:flutter/material.dart';

import '../data/review.dart';
import '../data/zoky_repository.dart';
import 'widgets/review_tile.dart';
import 'widgets/star_rating.dart';

/// Screen: ProductReviewsScreen (ZOKY-004) -- every review for a single
/// product, opened from ProductDetailScreen's "ดูรีวิวทั้งหมด" once
/// there are more than the 3-review preview shows. See
/// .wyn/docs/design/zoky-004-review.md.
class ProductReviewsScreen extends StatefulWidget {
  const ProductReviewsScreen({
    super.key,
    required this.zokyRepository,
    required this.productId,
    required this.rating,
    required this.reviewCount,
  });

  final ZokyRepository zokyRepository;
  final String productId;
  final double rating;
  final int reviewCount;

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  final _scrollController = ScrollController();
  final List<Review> _reviews = [];
  int _page = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadPage();
    }
  }

  Future<void> _loadPage() async {
    setState(() => _page == 0 ? _isLoading = true : _isLoadingMore = true);
    final offset = _page * ZokyRepository.reviewsPageSize;
    final reviews = await widget.zokyRepository.fetchProductReviews(
      widget.productId,
      limit: ZokyRepository.reviewsPageSize,
      offset: offset,
    );
    if (!mounted) return;
    setState(() {
      _reviews.addAll(reviews);
      _page++;
      _hasMore = reviews.length == ZokyRepository.reviewsPageSize;
      _isLoading = false;
      _isLoadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('รีวิวทั้งหมด')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    StarRatingDisplay(rating: widget.rating),
                    const SizedBox(width: 6),
                    Text('${widget.rating.toStringAsFixed(1)} (${widget.reviewCount} รีวิว)'),
                  ],
                ),
                const Divider(height: 24),
                for (final review in _reviews) ReviewTile(review: review),
                if (_isLoadingMore)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }
}

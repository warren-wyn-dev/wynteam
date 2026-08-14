import 'package:flutter/material.dart';

/// Product image carousel for ProductDetailScreen -- 1:1 aspect ratio,
/// PageView + dot indicator when there's more than one image. Mirrors
/// ClubPostImages (WYN-014) exactly.
class ProductImages extends StatefulWidget {
  const ProductImages({super.key, required this.imageUrls});

  final List<String> imageUrls;

  @override
  State<ProductImages> createState() => _ProductImagesState();
}

class _ProductImagesState extends State<ProductImages> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.length == 1) {
      return AspectRatio(
        aspectRatio: 1,
        child: Image.network(widget.imageUrls.first, fit: BoxFit.cover),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) =>
                Image.network(widget.imageUrls[index], fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.imageUrls.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == _page
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

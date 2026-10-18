import 'package:flutter/material.dart';

import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/widgets/zoky_glossy_surface.dart';
import '../../catalog/domain/catalog_models.dart';
import '../../deals/domain/deal_models.dart';
import '../../deals/widgets/zoky_deal_illustration.dart';

/// A store's cover "photo". Uses the real cover when the store has one
/// ([ZokyStoreSummary.coverUrl]: http(s) URL or bundled asset path) and
/// otherwise the code-drawn "ZOKY Glossy 3D" food art
/// ([ZokyStoreSummary.coverArt]) on a soft tinted glossy background, so a
/// real photo can replace the art without touching the card. Decorative:
/// the card that contains it carries the label.
class ZokyStoreCover extends StatelessWidget {
  const ZokyStoreCover({
    super.key,
    required this.store,
    required this.borderRadius,
  });

  final ZokyStoreSummary store;
  final BorderRadius borderRadius;

  /// Soft background tint per dish (top -> bottom). Ink text never sits on
  /// these; only the white glossy badge/heart controls do.
  static LinearGradient tintFor(ZokyDealArt? art) {
    final (top, bottom) = switch (art) {
      ZokyDealArt.noodleBowl => (Color(0xFFFFF7EF), Color(0xFFFFE4D1)),
      ZokyDealArt.burger => (Color(0xFFFFFBEB), Color(0xFFFFEBC2)),
      ZokyDealArt.somTam => (Color(0xFFF4FBEF), Color(0xFFDDF1D2)),
      ZokyDealArt.bubbleTea => (Color(0xFFFFF1F6), Color(0xFFFFDCEA)),
      ZokyDealArt.friedChicken => (Color(0xFFFFF6EC), Color(0xFFFFE0C4)),
      ZokyDealArt.kaprao => (Color(0xFFF4FBEF), Color(0xFFDDF1D2)),
      ZokyDealArt.dessert => (Color(0xFFFFFBEB), Color(0xFFFFEBC2)),
      null => (ZokyColors.neutral50, ZokyColors.neutral100),
    };
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, bottom],
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = store.coverUrl;
    final art = _art();
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: borderRadius,
        child: url == null
            ? art
            : (url.startsWith('http://') || url.startsWith('https://'))
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => art,
              )
            : Image.asset(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => art,
              ),
      ),
    );
  }

  Widget _art() {
    final art = store.coverArt;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: tintFor(art)),
      child: CustomPaint(
        foregroundPainter: ZokyGlossPainter(
          gradient: null,
          borderRadius: borderRadius,
          glossHeight: 30,
          glossOpacity: 0.5,
          glossInset: 3,
          rimTop: const Color(0xE6FFFFFF),
          rimBottom: const Color(0x40FFFFFF),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            if (art == null) {
              return const Center(
                child: Icon(
                  ZokyIcons.food,
                  size: 30,
                  color: ZokyColors.neutral400,
                ),
              );
            }
            return Stack(
              fit: StackFit.expand,
              children: [
                // Soft light pool behind the dish.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.1, 0.1),
                      radius: 0.75,
                      colors: [Color(0xB3FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(-0.1, 0.7),
                  child: ZokyDealIllustration(art: art, size: h * 1.06),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

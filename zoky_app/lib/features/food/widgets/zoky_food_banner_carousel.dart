import 'package:flutter/material.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/design/zoky_typography.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_3d_icon.dart';
import '../../../core/widgets/zoky_glossy_surface.dart';
import '../../../core/widgets/zoky_skeleton.dart';
import '../../deals/widgets/zoky_deal_card.dart';
import '../../deals/widgets/zoky_deal_illustration.dart';
import '../../home/data/home_content_repository.dart';
import '../../home/domain/home_content_models.dart';
import '../../home/widgets/zoky_store_cover.dart';

/// Food page banner carousel (Founder, 2026-10-18): horizontally paged
/// banner slides with the next one peeking in at the right, and page dots
/// under it (the active dot is a brand-pink pill).
///
/// Shows the banners of [HomeContentRepository.fetchActiveBanners] in the
/// order the repository returns them (the brand hero card stays on Home).
/// A skeleton slide holds the space while they load; nothing shows when
/// there are none or the call fails (web: the banner row is hidden).
///
/// Every slide has the same height: the taller of [aspectRatio] (web
/// banners are wide, ~2.3:1) and the tallest banner text at the current
/// width and text size, so no slide ever clips its text.
class ZokyFoodBannerCarousel extends StatefulWidget {
  const ZokyFoodBannerCarousel({
    super.key,
    required this.repository,
    required this.onOpenBanner,
  });

  final HomeContentRepository repository;

  /// Called for a banner with a target ([ZokyHomeBanner.hasTarget]).
  final ValueChanged<ZokyHomeBanner> onOpenBanner;

  /// Key of the PageView (tests).
  static const Key pagerKey = ValueKey('zoky-banner-pager');

  /// Key of the page dots row (tests).
  static const Key dotsKey = ValueKey('zoky-banner-dots');

  /// Gap between slides; equal to the gutter so the previous slide never
  /// shows a sliver at the left edge.
  static const double gap = ZokySpacing.gutter;

  /// How much of the next slide peeks in at the right.
  static const double peek = 24;

  static const double aspectRatio = 2.3;

  /// Slide width for a viewport [width] wide.
  static double slideWidth(double width) =>
      width - ZokySpacing.gutter - gap - peek;

  @override
  State<ZokyFoodBannerCarousel> createState() => _ZokyFoodBannerCarouselState();
}

class _ZokyFoodBannerCarouselState extends State<ZokyFoodBannerCarousel> {
  /// Null while loading.
  List<ZokyHomeBanner>? _banners;
  PageController? _controller;
  double _fraction = 0;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final banners = await widget.repository.fetchActiveBanners();
      if (!mounted) return;
      setState(() => _banners = banners);
    } catch (_) {
      // Banners are optional: hide the carousel.
      if (!mounted) return;
      setState(() => _banners = const []);
    }
  }

  /// The controller's viewport fraction depends on the width; recreate it
  /// (keeping the page) when the width changes.
  PageController _controllerFor(double fraction) {
    final current = _controller;
    if (current != null && (fraction - _fraction).abs() < 0.0001) {
      return current;
    }
    current?.removeListener(_onScroll);
    final next = PageController(viewportFraction: fraction, initialPage: _page)
      ..addListener(_onScroll);
    if (current != null) {
      // Dispose after this frame: the old PageView still holds it.
      WidgetsBinding.instance.addPostFrameCallback((_) => current.dispose());
    }
    _controller = next;
    _fraction = fraction;
    return next;
  }

  void _onScroll() {
    final page = _controller?.page?.round() ?? 0;
    if (page != _page) setState(() => _page = page);
  }

  @override
  void dispose() {
    _controller?.removeListener(_onScroll);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = _banners;
    if (banners != null && banners.isEmpty) return const SizedBox.shrink();
    final count = banners?.length ?? 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final slide = ZokyFoodBannerCarousel.slideWidth(width);
        final minHeight = slide / ZokyFoodBannerCarousel.aspectRatio;
        final extent = slide + ZokyFoodBannerCarousel.gap;
        final controller = _controllerFor(
          extent / (width - ZokySpacing.gutter),
        );
        final page = _page.clamp(0, count - 1);
        return Semantics(
          container: true,
          label: ZokyStrings.foodBanners,
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: ZokySpacing.s6,
                  bottom: ZokySpacing.s8,
                ),
                child: banners == null
                    ? Padding(
                        padding: const EdgeInsets.only(
                          left: ZokySpacing.gutter,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: ZokySkeleton(
                            width: slide,
                            height: minHeight,
                            borderRadius: ZokyFoodBannerCard.radius,
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          // Invisible copies of every banner's text that give
                          // all slides their height (see the class doc).
                          Padding(
                            padding: const EdgeInsets.only(
                              left: ZokySpacing.gutter,
                            ),
                            child: ExcludeSemantics(
                              child: Visibility(
                                visible: false,
                                maintainSize: true,
                                maintainAnimation: true,
                                maintainState: true,
                                child: SizedBox(
                                  width: slide,
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minHeight: minHeight,
                                    ),
                                    child: Stack(
                                      children: [
                                        for (final banner in banners)
                                          ZokyFoodBannerCard.sizer(
                                            banner,
                                            slide,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            left: ZokySpacing.gutter,
                            child: PageView.builder(
                              key: ZokyFoodBannerCarousel.pagerKey,
                              controller: controller,
                              padEnds: false,
                              // Slides and their soft shadows may draw past
                              // the viewport (into the left gutter while
                              // swiping).
                              clipBehavior: Clip.none,
                              itemCount: count,
                              itemBuilder: (context, index) => Padding(
                                padding: const EdgeInsets.only(
                                  right: ZokyFoodBannerCarousel.gap,
                                ),
                                child: ZokyFoodBannerCard(
                                  banner: banners[index],
                                  index: index,
                                  onTap: () =>
                                      widget.onOpenBanner(banners[index]),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
              if (count > 1)
                ZokyPageDots(
                  key: ZokyFoodBannerCarousel.dotsKey,
                  count: count,
                  active: page,
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Page dots: inactive 6pt gray dots, the active one an 18pt brand-pink
/// pill. Decorative (screen readers page through the slides themselves).
class ZokyPageDots extends StatelessWidget {
  const ZokyPageDots({super.key, required this.count, required this.active});

  final int count;
  final int active;

  static const double size = 6;
  static const double activeWidth = 18;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : ZokyMotion.base;
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: duration,
              curve: ZokyMotion.standard,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: i == active ? activeWidth : size,
              height: size,
              decoration: BoxDecoration(
                color: i == active ? ZokyColors.brand : ZokyColors.neutral200,
                borderRadius: ZokyRadius.full,
              ),
            ),
        ],
      ),
    );
  }
}

/// One admin banner as a "ZOKY Glossy 3D" card: a soft dish tint, the
/// "ตัวอย่าง" badge for sample banners, the title in bold brand pink, the
/// subtitle in ink and the dish illustration on a light pool at the right.
/// With a target it is one button (3D arrow shown); without one it is a
/// plain labelled group and taps do nothing.
///
/// Contrast: the title is >= 20 bold ("large text") in
/// [ZokyColors.brandDeep] on the tint (>= 4:1); small text is ink.
class ZokyFoodBannerCard extends StatelessWidget {
  const ZokyFoodBannerCard({
    super.key,
    required this.banner,
    required this.index,
    required this.onTap,
  });

  final ZokyHomeBanner banner;

  /// Position among the banners (alternates the fallback tint).
  final int index;
  final VoidCallback onTap;

  static const BorderRadius radius = ZokyRadius.xxl;

  static TextStyle get titleStyle => ZokyTextStyles.weight(
    ZokyTextStyles.titleMd.copyWith(
      fontSize: 21,
      height: 1.2,
      color: ZokyColors.brandDeep,
    ),
    FontWeight.w800,
  );

  /// Accessible name ("ตัวอย่างแบนเนอร์: title subtitle").
  static String semanticLabel(ZokyHomeBanner banner) {
    final prefix = banner.isDemo ? '${ZokyStrings.demoBannerPrefix}: ' : '';
    final subtitle = banner.subtitle == null ? '' : ' ${banner.subtitle}';
    return '$prefix${banner.title}$subtitle';
  }

  /// Widest the dish gets, as a fraction of the slide width.
  static const double maxArtFraction = 0.42;

  /// Invisible stand-in with [banner]'s text laid out as in a slide
  /// [slideWidth] wide (dish at its widest, so the text is at its
  /// narrowest): its height is the least a slide needs for this banner.
  static Widget sizer(ZokyHomeBanner banner, double slideWidth) => _text(
    banner,
    artSize: banner.art != null ? slideWidth * maxArtFraction : null,
  );

  /// Badge, title, subtitle and arrow, left of the dish ([artSize] wide,
  /// null without a dish).
  static Widget _text(ZokyHomeBanner banner, {required double? artSize}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ZokySpacing.s10,
        ZokySpacing.s8,
        artSize != null ? artSize + ZokySpacing.s8 : ZokySpacing.s10,
        ZokySpacing.s8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (banner.isDemo) ...[
            const ZokyDemoBadge(),
            const SizedBox(height: ZokySpacing.s4),
          ],
          Text(
            banner.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
          if (banner.subtitle != null) ...[
            const SizedBox(height: ZokySpacing.s2),
            Text(
              banner.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ZokyTextStyles.bodySm.copyWith(
                color: ZokyColors.textPrimary,
                height: 1.35,
              ),
            ),
          ],
          if (banner.hasTarget) ...[
            const SizedBox(height: ZokySpacing.s4),
            const Zoky3DIcon(Zoky3DGlyph.arrowRight, size: 26),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final art = banner.art;
    final gradient = art != null
        ? ZokyStoreCover.tintFor(art)
        : ZokyDealTint.forIndex(index).gradient;
    final tappable = banner.hasTarget;
    final Widget card = DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: ZokyDealCard.shadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(borderRadius: radius, gradient: gradient),
          child: InkWell(
            onTap: tappable ? onTap : null,
            borderRadius: radius,
            child: CustomPaint(
              painter: const ZokyGlossPainter(
                gradient: null,
                borderRadius: radius,
                glossHeight: 52,
                glossOpacity: 0.55,
                rimTop: Color(0xE6FFFFFF),
                rimBottom: Color(0x40FFFFFF),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  final artSize = (h * 0.92).clamp(
                    0.0,
                    constraints.maxWidth * maxArtFraction,
                  );
                  return Stack(
                    children: [
                      // Soft light pool and the dish at the right.
                      if (art != null)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: artSize + ZokySpacing.s8,
                          child: ExcludeSemantics(
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: RadialGradient(
                                  radius: 0.5,
                                  colors: [
                                    Color(0xCCFFFFFF),
                                    Color(0x00FFFFFF),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: ZokyDealIllustration(
                                  art: art,
                                  size: artSize,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: _text(
                            banner,
                            artSize: art != null ? artSize : null,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: tappable,
      container: true,
      label: semanticLabel(banner),
      excludeSemantics: true,
      child: card,
    );
  }
}

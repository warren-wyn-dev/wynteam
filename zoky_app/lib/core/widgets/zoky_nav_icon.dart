import 'package:flutter/cupertino.dart';

import '../design/zoky_colors.dart';
import 'zoky_3d_icon.dart';

/// Icon treatment of the bottom nav tabs.
///
/// [classic3d] is the shipped look (custom-painted line / glossy twins of
/// [Zoky3DIcon]). The Apple styles are PROPOSED (Founder feedback
/// 2026-10-17 "ขอสไตล์ Apple") and only take effect when passed explicitly.
enum ZokyNavIconStyle {
  /// Gray custom line icon, glossy 3D pink when selected (shipped default).
  classic3d,

  /// iOS tab bar convention with the MIT CupertinoIcons font (an SF
  /// Symbols look-alike; no Apple assets): gray outline glyph, flat
  /// brand-deep pink filled glyph when selected.
  apple,

  /// [apple], but the selected filled glyph gets the ZOKY 3D light: pink
  /// vertical gradient, top-left specular highlight, bottom-right shade
  /// and a small soft drop shadow.
  appleSoft3d,
}

/// Outline / filled CupertinoIcons pair of one nav destination.
@immutable
class ZokyAppleNavIcons {
  const ZokyAppleNavIcons(this.outline, this.fill);

  final IconData outline;
  final IconData fill;

  static const home = ZokyAppleNavIcons(
    CupertinoIcons.house,
    CupertinoIcons.house_fill,
  );
  static const homeAlt = ZokyAppleNavIcons(
    CupertinoIcons.house_alt,
    CupertinoIcons.house_alt_fill,
  );
  static const orders = ZokyAppleNavIcons(
    CupertinoIcons.doc_text,
    CupertinoIcons.doc_text_fill,
  );
  static const ordersBag = ZokyAppleNavIcons(
    CupertinoIcons.bag,
    CupertinoIcons.bag_fill,
  );
  static const ordersList = ZokyAppleNavIcons(
    CupertinoIcons.square_list,
    CupertinoIcons.square_list_fill,
  );
  static const messages = ZokyAppleNavIcons(
    CupertinoIcons.chat_bubble,
    CupertinoIcons.chat_bubble_fill,
  );
  static const messagesPair = ZokyAppleNavIcons(
    CupertinoIcons.chat_bubble_2,
    CupertinoIcons.chat_bubble_2_fill,
  );
  static const messagesDots = ZokyAppleNavIcons(
    CupertinoIcons.ellipses_bubble,
    CupertinoIcons.ellipses_bubble_fill,
  );
  static const account = ZokyAppleNavIcons(
    CupertinoIcons.person,
    CupertinoIcons.person_fill,
  );
  static const accountCircle = ZokyAppleNavIcons(
    CupertinoIcons.person_crop_circle,
    CupertinoIcons.person_crop_circle_fill,
  );

  /// Default pair of a nav glyph, or null for non-nav glyphs.
  static ZokyAppleNavIcons? forGlyph(Zoky3DGlyph glyph) => switch (glyph) {
    Zoky3DGlyph.home => home,
    Zoky3DGlyph.receipt => orders,
    Zoky3DGlyph.chat => messages,
    Zoky3DGlyph.person => account,
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is ZokyAppleNavIcons &&
      other.outline == outline &&
      other.fill == fill;

  @override
  int get hashCode => Object.hash(outline, fill);
}

/// One nav tab icon in a [ZokyNavIconStyle]. Decorative: the tab button
/// carries the label.
class ZokyNavIcon extends StatelessWidget {
  const ZokyNavIcon(
    this.glyph, {
    super.key,
    required this.selected,
    this.style = ZokyNavIconStyle.classic3d,
    this.size = 26,
    this.appleIcons,
    this.lineColor = ZokyColors.neutral600,
  });

  /// Flat selected color: brand deep, 4.58:1 on the blush highlight
  /// (#FFEDF4) and the same color as the selected label.
  static const Color appleSelectedColor = ZokyColors.actionPrimary;

  /// Soft 3D gradient (top -> bottom): every stop >= 3.24:1 on the blush
  /// highlight, so the glyph keeps non-text contrast without its sheen.
  static const List<Color> soft3dGradient = [
    ZokyColors.brandLight,
    ZokyColors.brandDeep,
  ];

  final Zoky3DGlyph glyph;
  final bool selected;
  final ZokyNavIconStyle style;
  final double size;

  /// Overrides the CupertinoIcons pair of the Apple styles (alternates).
  final ZokyAppleNavIcons? appleIcons;

  /// Unselected gray (#6B6B76: 5.26:1 on white).
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final pair = appleIcons ?? ZokyAppleNavIcons.forGlyph(glyph);
    if (style == ZokyNavIconStyle.classic3d || pair == null) {
      return Zoky3DIcon(
        glyph,
        size: size,
        style: selected ? Zoky3DIconStyle.glossy : Zoky3DIconStyle.line,
        lineColor: lineColor,
      );
    }
    final Widget icon;
    if (!selected) {
      icon = Icon(pair.outline, size: size, color: lineColor);
    } else if (style == ZokyNavIconStyle.apple) {
      icon = Icon(pair.fill, size: size, color: appleSelectedColor);
    } else {
      icon = _Soft3dGlyph(icon: pair.fill, size: size);
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(child: icon),
      ),
    );
  }
}

/// A filled font glyph lit like [Zoky3DIcon]: light from the top-left.
class _Soft3dGlyph extends StatelessWidget {
  const _Soft3dGlyph({required this.icon, required this.size});

  final IconData icon;
  final double size;

  Widget _layer(Shader Function(Rect) shader) => ShaderMask(
    shaderCallback: shader,
    blendMode: BlendMode.srcIn,
    child: Icon(icon, size: size, color: const Color(0xFFFFFFFF)),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Small soft drop shadow, offset down.
        Icon(
          icon,
          size: size,
          color: const Color(0x00000000),
          shadows: [
            Shadow(
              color: const Color(0x52C2185B),
              offset: Offset(0, size * 0.06),
              blurRadius: size * 0.10,
            ),
          ],
        ),
        // 2. Body: vertical pink gradient.
        _layer(
          (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: ZokyNavIcon.soft3dGradient,
          ).createShader(r),
        ),
        // 3. Soft inner shade bottom-right.
        _layer(
          (r) => const LinearGradient(
            begin: Alignment(-0.2, -0.2),
            end: Alignment.bottomRight,
            colors: [Color(0x00AF1341), Color(0x66991636)],
          ).createShader(r),
        ),
        // 4. Specular highlight top-left (halo + brighter core).
        _layer(
          (r) => const RadialGradient(
            center: Alignment(-0.42, -0.58),
            radius: 0.55,
            colors: [Color(0xCCFFFFFF), Color(0x40FFFFFF), Color(0x00FFFFFF)],
            stops: [0, 0.35, 1],
          ).createShader(r),
        ),
      ],
    );
  }
}

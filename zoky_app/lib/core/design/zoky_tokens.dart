import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

/// Spacing scale (tokens.json `spacing`, 2/4px base).
abstract final class ZokySpacing {
  static const double s1 = 2;
  static const double s2 = 4;
  static const double s3 = 6;
  static const double s4 = 8;
  static const double s5 = 10;
  static const double s6 = 12;
  static const double s7 = 14;
  static const double s8 = 16;
  static const double s10 = 20;
  static const double s12 = 24;
  static const double s16 = 32;
  static const double s24 = 48;

  /// Screen gutter.
  static const double gutter = s8;
  static const double sectionGap = 22;
}

/// Corner radius tokens (tokens.json `radius`).
abstract final class ZokyRadius {
  static const double xsValue = 6;
  static const double smValue = 10;
  static const double mdValue = 14;
  static const double lgValue = 16;
  static const double xlValue = 20;
  static const double xxlValue = 24;
  static const double fullValue = 9999;

  static const BorderRadius xs = BorderRadius.all(Radius.circular(xsValue));
  static const BorderRadius sm = BorderRadius.all(Radius.circular(smValue));
  static const BorderRadius md = BorderRadius.all(Radius.circular(mdValue));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(lgValue));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(xlValue));
  static const BorderRadius xxl = BorderRadius.all(Radius.circular(xxlValue));
  static const BorderRadius full = BorderRadius.all(Radius.circular(fullValue));
}

/// Elevation tokens as BoxShadows (design 6.3: do not rely on
/// Material.elevation, which would tint surfaces pink under M3).
abstract final class ZokyShadows {
  static const List<BoxShadow> e0 = <BoxShadow>[];
  static const List<BoxShadow> e1 = [
    BoxShadow(color: Color(0x1416161A), offset: Offset(0, 2), blurRadius: 12),
  ];
  static const List<BoxShadow> e2 = [
    BoxShadow(color: Color(0x1F16161A), offset: Offset(0, 2), blurRadius: 14),
  ];
  static const List<BoxShadow> e3 = [
    BoxShadow(color: Color(0x1F16161A), offset: Offset(0, 6), blurRadius: 24),
  ];
  static const List<BoxShadow> e4 = [
    BoxShadow(color: Color(0x2416161A), offset: Offset(0, 12), blurRadius: 32),
    BoxShadow(color: Color(0x0F16161A), offset: Offset(0, 2), blurRadius: 6),
  ];
  static const List<BoxShadow> e5 = [
    BoxShadow(color: Color(0x3D16161A), offset: Offset(0, 10), blurRadius: 28),
  ];
  static const List<BoxShadow> brand = [
    BoxShadow(color: Color(0x42D61256), offset: Offset(0, 8), blurRadius: 18),
  ];
}

/// Motion tokens (design section 8). Callers must honor
/// MediaQuery.disableAnimationsOf(context) (reduced motion).
abstract final class ZokyMotion {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration press = Duration(milliseconds: 140);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration sheet = Duration(milliseconds: 240);
  static const Duration enter = Duration(milliseconds: 260);
  static const Duration pop = Duration(milliseconds: 500);
  static const Duration shimmer = Duration(milliseconds: 1200);

  static const Cubic standard = Cubic(0.2, 0.8, 0.2, 1);
  static const Cubic popCurve = Cubic(0.2, 0.9, 0.3, 1.2);
  static const Cubic exit = Cubic(0.4, 0, 1, 1);

  static const double pressScale = 0.97;
}

/// Component size tokens (tokens.json `size`).
abstract final class ZokySizes {
  static const double tapTargetIos = 44;
  static const double tapTargetAndroid = 48;
  static const double buttonSm = 40;
  static const double buttonMd = 48;
  static const double buttonLg = 54;
  static const double input = 52;
  static const double bottomNav = 60;
  static const double cartBar = 60;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;

  /// Max widths on tablet/desktop (design 6.4).
  static const double navMaxWidth = 560;
  static const double cartBarMaxWidth = 540;
  static const double sheetMaxWidth = 720;
}

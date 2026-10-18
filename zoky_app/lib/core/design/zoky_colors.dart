import 'package:flutter/painting.dart';

/// ZOKY color tokens (design-reference/zoky/tokens.json v0.1, PROPOSED).
///
/// Copied by hand from tokens.json -- keep in sync when the tokens change.
/// See .wyn/docs/design/zoky-design-system.md section 3 for which color may
/// carry text. Key rule (D1): white text sits on [brandDeep] (#D61256,
/// 5.15:1), never on [brand] (#F21967, 4.11:1). [brand] is for icons,
/// indicators, focus rings and large text only.
abstract final class ZokyColors {
  // Brand palette (from the logo).
  static const Color brand = Color(0xFFF21967);
  static const Color brandLight = Color(0xFFF4368D);
  static const Color brandSoft = Color(0xFFF880BE);
  static const Color brandDeep = Color(0xFFD61256);
  static const Color berry = Color(0xFFAF1341);
  static const Color wine = Color(0xFF991636);
  static const Color blush = Color(0xFFF1E4F5);
  static const Color brandLine = Color(0xFFF9C0DE);

  // Header gradient stops, measured from the rendered background of the
  // Founder-approved logo (design-reference/zoky/zoky-logo.svg, gloss and
  // edge shading included) so the header reads as the same pink as the logo.
  // Background only: never put body text on these (see D1 above).
  static const Color headerTop = Color(0xFFF93384);
  static const Color headerMid = Color(0xFFF72C7E);
  static const Color headerBottom = Color(0xFFEE226E);

  // Pale blush header (food page, Founder 2026-10-18: "พื้นชมพู ขอเป็นสีที่
  // อ่อนสุดๆ"), fading to white. Light background: ink/textSecondary text,
  // brandDeep icons (contrast in ZokyFoodHeader).
  static const Color headerPale = Color(0xFFFFEFF5);
  static const Color headerPaleMid = Color(0xFFFFF7FA);

  // Neutral scale.
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral25 = Color(0xFFF8FAFE); // Cloud White
  static const Color neutral50 = Color(0xFFF6F6F8);
  static const Color neutral100 = Color(0xFFF3F3F6);
  static const Color neutral150 = Color(0xFFEBEBEF);
  static const Color neutral200 = Color(0xFFDCDCE2);
  static const Color neutral400 = Color(0xFF8A8A94);
  static const Color neutral600 = Color(0xFF6B6B76);
  static const Color neutral900 = Color(0xFF16161A); // Ink

  // Semantic palette (kept separate from brand: pink never means "wrong").
  static const Color error = Color(0xFFB3261E);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFF9DEDC);
  static const Color onErrorContainer = Color(0xFF410E0B);
  static const Color success = Color(0xFF187A43);
  static const Color successContainer = Color(0xFFE9F7EF);
  static const Color warning = Color(0xFF9A5800);
  static const Color warningContainer = Color(0xFFFFF6E5);
  static const Color info = Color(0xFF175CD3);
  static const Color infoContainer = Color(0xFFEAF2FF);
  static const Color rating = Color(0xFFF5A623);

  // Role tokens.
  static const Color canvas = neutral25;
  static const Color surface = neutral0;
  static const Color sunken = neutral50;
  static const Color chip = neutral100;
  static const Color scrim = Color(0x7316161A); // ink 45%
  static const Color textPrimary = neutral900;
  static const Color textSecondary = neutral600;
  static const Color textDisabled = neutral400;
  static const Color textBrand = berry;
  static const Color textLink = brandDeep;
  static const Color onAction = neutral0;
  static const Color actionPrimary = brandDeep;
  static const Color actionPressed = berry;
  static const Color actionAccent = brand;
  static const Color actionDisabledBg = neutral100;
  static const Color actionDisabledText = neutral400;
  static const Color borderSubtle = neutral150;
  static const Color borderDefault = neutral200;
  static const Color borderControl = neutral400;
  static const Color focus = brand;

  // Skeleton shimmer gradient (design 9.12).
  static const Color skeletonBase = Color(0xFFF1F1F4);
  static const Color skeletonHighlight = Color(0xFFF8F8FA);
}

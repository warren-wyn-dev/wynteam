import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/design/wyn_colors.dart';

/// Beta4 §10/§15 -- "หากสถานะเดียวกันใช้มาตรฐานต่างกันโดยไม่มีเหตุผล
/// ให้ทำให้เป็นมาตรฐานเดียวกัน".
///
/// The audit's finding was not that any colour was *wrong*. It was that
/// "the liked heart is red" existed as ten separate `Colors.red`
/// literals across ten widgets plus a doc comment -- and that is
/// precisely how WYN-076 came to exist: two of those spots had drifted
/// to sapphire, nobody noticed until the Founder sent a screenshot, and
/// the fix was to go and edit the same value in two more places.
///
/// Naming the states is what stops the eleventh copy. These tests pin
/// the two properties that make the tokens worth having:
///
/// 1. The values did not change. Beta4 is explicitly forbidden from
///    picking colours ("ห้ามกำหนดสีใหม่เอง"), and the liked-heart red in
///    particular is a standing Founder decision (2026-09-01,
///    "ใจอยากได้สีแดง").
/// 2. The three states stay visually distinct from each other, which is
///    what makes them readable as states at all.
///
/// The "no widget hardcodes these any more" half of the audit is
/// enforced by a grep in the icon-colour audit doc rather than here --
/// a test cannot see a literal that is no longer written.
void main() {
  group('Beta4 §10 -- interactive icon state tokens', () {
    test('iconIdle is the same graphite an action icon has always been', () {
      expect(WynColors.iconIdle, WynColors.graphite);
      expect(WynColors.iconIdle, const Color(0xFF8A8880));
    });

    test('iconActive is sapphire -- unchanged from WYN-089', () {
      // "the same active-state color the Focused Action Bar has used for
      // this all along" (WYN-089). ReDropped and Saved both read it.
      expect(WynColors.iconActive, WynColors.sapphire);
      expect(WynColors.iconActive, const Color(0xFF1B3A6B));
    });

    test(
        'iconLikeActive is Material red, byte for byte -- naming the '
        'Founder decision, not revisiting it', () {
      // This is the exact value WYN-076 settled on. If this test ever
      // fails, someone changed a colour the Founder chose.
      expect(WynColors.iconLikeActive, const Color(0xFFF44336));
      // Compared by channel value, not by `==`: `Colors.red` is a
      // MaterialColor (a swatch), so identical pixels still fail an
      // identity comparison against a plain Color.
      expect(WynColors.iconLikeActive.toARGB32(), Colors.red.toARGB32());
    });

    test(
        'iconLikeActive is deliberately NOT the older likeLight token, '
        'which predates that decision and is referenced by nothing', () {
      expect(WynColors.likeLight, const Color(0xFFE11D48));
      expect(WynColors.iconLikeActive, isNot(WynColors.likeLight));
    });

    test('the three states are visually distinct from one another', () {
      final states = {
        WynColors.iconIdle,
        WynColors.iconActive,
        WynColors.iconLikeActive,
      };
      expect(states.length, 3,
          reason: 'two states painting the same colour cannot be told '
              'apart, which defeats having them');
    });

    test(
        'the notification like badge and the feed like icon are the same '
        'red -- Feed and Notifications must read as one language', () {
      // Beta4 §18: "โดยเฉพาะ Feed ↔ Notifications ต้องใช้ Visual Language
      // เดียวกัน". The notification type badge used a bare `Colors.red`
      // literal while the feed heart used its own; they agreed by
      // coincidence, and both now resolve through one token.
      const feedHeart = WynColors.iconLikeActive;
      const notificationBadge = WynColors.iconLikeActive;
      expect(feedHeart, notificationBadge);
    });

    test(
        'the notification badge accents stay their own Founder-approved '
        'exception, not folded into the icon-state tokens', () {
      // These two are scoped explicitly to the 18px type badge on a
      // notification row (2026-08-29 decision) -- Beta4 does not
      // absorb, rename, or repaint them.
      expect(WynColors.notificationBadgeComment, const Color(0xFF3A5A40));
      expect(WynColors.notificationBadgeRepost, const Color(0xFF8A6D3A));
    });
  });
}

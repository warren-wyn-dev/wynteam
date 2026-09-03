import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../../core/ad_env.dart';

/// WYN-106 -- Native In-Feed Ads (Home feed, "สำหรับคุณ"). One ad-slot's
/// entire AdMob lifecycle: requests exactly one [NativeAd] the moment
/// this widget is first built, and disposes it the moment this widget
/// leaves the tree.
///
/// Renders nothing (`SizedBox.shrink()`, zero height) whenever there is
/// no ad to show -- not yet loaded, no-fill, a load error, or ads not
/// configured for this build at all ([AdEnv.isConfigured]) -- per the
/// design spec's "กติกาแม่บทเดียว: โฆษณาที่ไม่พร้อม = ไม่มีอยู่ ไม่ใช่กล่อง
/// ว่าง ไม่ใช่ spinner ไม่ใช่ placeholder ที่ดูพัง" (section 3). There is
/// deliberately no retry here, and a late [onAdLoaded] callback after
/// this widget has already been disposed (scrolled far enough past that
/// [SliverList] tore the element down) disposes the ad straight away
/// instead of ever calling `setState` -- the design spec explicitly
/// forbids "retroactively" inserting an ad into a position the user has
/// already scrolled past.
///
/// SliverList only builds rows near the current viewport (plus its
/// cacheExtent), so building this widget already happens a little ahead
/// of the user actually scrolling to it -- the same "prefetch a little
/// ahead" cadence [HomeFeedScreen]'s own `_onScroll`/`_loadMore` uses for
/// pagination (design spec section 3, "Prefetch ล่วงหน้า").
///
/// **Why this widget has no headline/body/CTA `Text`/`Column` widgets of
/// its own**, unlike every other card in this feed (`HomeDropCard`,
/// `HomePopCard`): the `google_mobile_ads` Flutter plugin deliberately
/// does not expose a loaded [NativeAd]'s asset strings (headline, body,
/// advertiser, callToAction, icon, mediaContent, starRating, store,
/// price, ...) back to Dart at all. A *custom* Native Advanced Ad (as
/// opposed to Google's built-in template styles) is rendered entirely by
/// platform code: a `NativeAdFactory` registered on Android / an
/// `FLTNativeAdFactory` registered on iOS is the only place those
/// getters exist, and the only place `NativeAdView.setNativeAd()` (which
/// is what actually wires up the SDK's `registerViewForInteraction`
/// tap-through and the AdChoices overlay -- design spec section 5,
/// "ปฏิสัมพันธ์กับ ... registerViewForInteraction ของ AdMob SDK เอง ...
/// ห้ามเขียน custom `onTap`") can be called. [AdWidget] below is
/// therefore an opaque platform view from Flutter's point of view --
/// this widget's own job is entirely the Flutter-side concerns the
/// design spec assigns to it: load/dispose lifecycle, the height cap,
/// collapsing to nothing while unresolved, and never suppressing
/// accessibility (no [ExcludeSemantics] anywhere here).
///
/// The native factory that actually builds the "โฆษณา"-pill header row +
/// AdChoices corner + headline (weight 600) + optional body/media/
/// rating row + full-width CTA layout mirroring `HomeDropCard` (design
/// spec's "Components" section) is intentionally **not** part of this
/// change -- same posture this repo already established for
/// `firebase_core`/`firebase_messaging` in pubspec.yaml (added, and
/// safely no-op'd behind a try/catch in main.dart, before the Founder
/// had real `google-services.json`/`GoogleService-Info.plist` to drop
/// in; see main.dart's own comment on that import). There is no real
/// AdMob App ID or native ad unit id yet ([AdEnv.isConfigured] is false
/// on every build until Founder supplies both), so wiring native
/// Kotlin/Swift factory code now would be unverifiable dead code in a
/// sandboxed environment with no Android/iOS build toolchain. What's
/// here compiles, is wired end to end on the Dart side, and cleanly
/// no-ops until that native follow-up lands -- see this task's own
/// handoff notes for the exact follow-up list.
class HomeNativeAdCard extends StatefulWidget {
  const HomeNativeAdCard({super.key, required this.adSlotIndex});

  /// 0-based ordinal of this ad-slot among ad-slots only (see
  /// [FeedAdSlotRow] in feed_ad_slots.dart). Not sent to AdMob -- kept
  /// only so a future crash/analytics log line can say *which* slot
  /// failed without needing the post index math redone by hand.
  final int adSlotIndex;

  @override
  State<HomeNativeAdCard> createState() => _HomeNativeAdCardState();
}

class _HomeNativeAdCardState extends State<HomeNativeAdCard> {
  NativeAd? _ad;

  /// Guards the async [NativeAdListener] callbacks below against firing
  /// after [dispose] -- `State.mounted` alone would be enough for the
  /// `setState` calls, but the ad itself still needs disposing even when
  /// unmounted (a NativeAd that finishes loading after its slot has
  /// scrolled out of the tree must not leak).
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    // Design spec section 3 / Handoff item 6: an unconfigured build
    // (every CI run, every `flutter test`, a bare local `flutter run`)
    // must never even attempt a network request to AdMob -- this is the
    // single point that guarantees that, since every other AdMob type
    // below is only ever touched once this guard has already passed.
    if (!AdEnv.isConfigured) return;

    NativeAd(
      adUnitId: AdEnv.nativeAdUnitId,
      // Must match the id the native NativeAdFactory/FLTNativeAdFactory
      // is registered under once that follow-up lands -- see this
      // file's own doc comment.
      factoryId: 'homeNativeAdFactory',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          setState(() => _ad = ad as NativeAd);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          // No retry -- design spec section 3: "ไม่มี retry ทันที รอ
          // interval ถัดไป (อีก N โพสต์) แทน". This slot simply stays
          // collapsed; the *next* ad-slot is a fresh widget instance
          // that gets its own attempt.
        },
      ),
    ).load();
  }

  @override
  void dispose() {
    _disposed = true;
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    // Loading / no-fill / error / ads-disabled -- all 4 collapse to the
    // exact same zero-height nothing, per design spec section 3.
    if (ad == null) return const SizedBox.shrink();

    // Height cap -- deliberately narrower than a bare "0.75 of viewport
    // height" (PostImageFrame/WYN-093's own cap): [AdWidget] is an
    // opaque platform view with no intrinsic size of its own (see this
    // file's own doc comment) -- Flutter must be *told* a height before
    // layout, not measure one back from the native content the way it
    // does for an `Image`. PostImageFrame never has this problem: every
    // photo it shows has a real decoded size, so 0.75-of-viewport is
    // only ever a ceiling on genuinely large content. Handing an
    // [AdWidget] the *full* 0.75 fraction on every device would mean a
    // small icon+text-only native ad (no media, no rating row) leaves a
    // large blank platform-view underneath it on a tall screen --
    // exactly the "dead space" the design spec's loading/no-fill states
    // forbid, just for a *loaded* ad instead. 360 is a conservative,
    // still-generous estimate for "header + headline + body + a
    // reasonably-sized media block + CTA" that keeps blank space small
    // on most phones; it has not been measured against a real rendered
    // native ad (no Android/iOS build toolchain in this environment --
    // see this file's own doc comment) and should be tuned once a real
    // AdMob config + native factory exist and QA can see actual ads
    // render on a device.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;
    final height = maxHeight < 360 ? maxHeight : 360.0;

    // Semantics section: "ต้องขึ้นต้นด้วยการประกาศว่าเป็นโฆษณาก่อนเนื้อหา".
    // The fuller "โฆษณา จาก {ชื่อผู้ลงโฆษณา}: {headline}" composition
    // belongs to the native factory's own `contentDescription` (it has
    // the actual strings; Dart does not -- see this file's doc comment),
    // so this wrapper supplies the generic, always-true prefix Dart can
    // guarantee today. Deliberately not [ExcludeSemantics] -- the
    // AdChoices overlay the SDK renders inside [AdWidget] must stay
    // reachable by screen readers (design spec: "ต้อง ไม่ถูก ExcludeSemantics
    // ครอบ").
    return Semantics(
      label: 'โฆษณา',
      container: true,
      child: SizedBox(height: height, child: AdWidget(ad: ad)),
    );
  }
}

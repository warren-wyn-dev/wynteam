import React, { useState } from "react";
import { Pressable, StyleSheet, useWindowDimensions, View } from "react-native";
import Svg, {
  Defs,
  LinearGradient,
  Path,
  Rect,
  Stop
} from "react-native-svg";

/**
 * Zoky iOS Home / Phase 1 — Compact brand header.
 *
 * Logo letterforms are traced from the user-supplied 1254x1254 original JPG,
 * replacing earlier approximated letter shapes. The pin-shaped o, its hole,
 * and the exact smile silhouette are preserved at 1px contour precision.
 * A source JPEG cannot reproduce the true master vector's lighting with 100% fidelity.
 * Gradient and waves are brand-inspired approximations for this UI preview.
 *
 * Only the Home hub/favorites use this header; Food/order flows remain untouched.
 * Padding accounts for the real device safe-area inset (including Dynamic Island).
 */
// Auto-traced from the user-supplied Zoky icon (2026-10-16), not a hand-drawn approximation.
// Six contours retain the Z, map-pin-shaped o and its hole, k, y, and smile.
// White foreground only; the original pink icon tile is intentionally excluded.
// Contours extracted directly from the founder-supplied 1254px JPG logo (IMG_0980 comparison, 2026-10-16).
// Binary mask: G > 140, B > 138, R > 180 inside the wordmark region;
// cv2 RETR_TREE / approxPolyDP(1px) traced 5 foreground contours and the transparent hole in pin-shaped o.
// Preserves actual wordmark silhouette rather than redrawing it by hand.
const WORDMARK_PATH = "M780,434L775,418L764,406L753,401L738,400L725,404L685,430L643,452L599,469L573,476L546,481L513,484L484,484L445,480L401,470L357,454L330,441L302,425L285,423L271,428L262,436L257,444L254,453L254,469L261,485L280,504L321,531L362,550L402,563L440,571L475,575L527,575L573,569L617,558L653,545L701,521L739,495L767,469L774,459L778,450Z M399,97L383,99L360,106L332,122L314,139L301,157L290,180L283,210L283,232L290,263L298,280L308,296L397,410L402,415L407,415L413,409L502,280L512,259L517,242L519,230L519,200L515,180L507,160L494,140L481,126L462,112L445,104L422,98Z M412,170L422,173L432,179L444,192L449,202L452,214L451,231L445,246L431,262L416,270L408,272L393,272L375,265L362,253L356,243L353,234L352,215L355,203L359,195L372,180L389,171L402,169Z M1024,73L1008,69L989,71L973,79L962,90L950,114L923,199L921,209L919,211L917,209L877,115L869,99L858,87L850,82L840,79L819,80L799,90L790,99L783,112L781,121L781,135L786,152L874,326L874,330L868,348L859,365L848,376L824,388L815,395L804,413L802,421L802,437L805,448L811,458L820,467L830,473L845,477L864,477L874,475L892,468L910,456L926,440L937,425L947,407L963,368L1050,126L1051,107L1049,99L1043,88L1033,78Z M273,52L259,47L233,48L176,60L52,91L29,100L20,106L7,121L3,129L0,141L0,151L3,164L9,175L17,183L31,190L60,190L156,163L159,164L157,169L36,335L23,356L17,375L16,387L18,400L28,420L39,430L49,435L57,437L76,437L261,391L281,383L288,378L296,369L300,362L304,348L303,328L300,319L294,309L288,303L278,297L266,294L251,295L155,320L153,318L279,147L292,126L296,115L298,103L296,82L287,64Z M547,8L532,23L526,41L535,348L537,357L542,367L554,378L571,384L586,384L600,380L611,373L617,367L623,357L626,347L625,284L637,271L648,281L694,335L713,355L724,361L732,363L747,363L765,357L780,345L788,332L791,320L788,302L781,291L700,209L700,207L763,142L769,134L772,125L772,114L768,104L760,96L752,92L740,89L718,89L702,94L692,100L623,171L621,137L620,46L617,26L608,12L600,6L591,2L572,0L561,2Z";

function Logo() {
  return (
    <Svg
      width={104}
      height={56}
      viewBox="0 0 1052 576"
      accessible
      accessibilityLabel="โลโก้ Zoky"
      style={styles.logo}
    >
      <Defs>
        <LinearGradient id="wordmarkTint" x1="0%" y1="0%" x2="0%" y2="100%">
          <Stop offset="0%" stopColor="#FFFFFF" />
          <Stop offset="54%" stopColor="#FFFFFF" />
          <Stop offset="100%" stopColor="#F8D9ED" />
        </LinearGradient>
      </Defs>
      <Path d={WORDMARK_PATH} fill="url(#wordmarkTint)" fillRule="evenodd" />
    </Svg>
  );
}

function HeartIcon() {
  return (
    <Svg width={26} height={26} viewBox="0 0 24 24" accessibilityElementsHidden>
      <Path
        d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 1 0-7.78 7.78L12 21.23l8.84-8.84a5.5 5.5 0 0 0 0-7.78Z"
        fill="none"
        stroke="#F70365"
        strokeWidth={1.9}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

export function HomeHeader({
  topInset,
  onOpenFavorites
}: {
  topInset: number;
  onOpenFavorites: () => void;
}) {
  const { width: windowWidth } = useWindowDimensions();
  const [bounds, setBounds] = useState({
    width: windowWidth,
    height: Math.max(topInset, 0) + 68
  });

  return (
    <View
      style={[styles.container, { paddingTop: Math.max(topInset, 0) + 2 }]}
      accessibilityLabel="ส่วนหัวหน้าหลัก"
      onLayout={({ nativeEvent }) => {
        const measured = nativeEvent.layout;
        const width = Math.round(measured.width);
        const height = Math.round(measured.height);
        if (width !== bounds.width || height !== bounds.height) {
          setBounds({ width, height });
        }
      }}
    >
      <Svg
        pointerEvents="none"
        width={bounds.width}
        height={bounds.height}
        viewBox="0 0 390 164"
        preserveAspectRatio="none"
        style={styles.backgroundLayer}
      >
        <Defs>
          <LinearGradient id="zokyHeaderBg" x1="0%" y1="30%" x2="100%" y2="45%">
            <Stop offset="0%" stopColor="#F70365" />
            <Stop offset="43%" stopColor="#FC297F" />
            <Stop offset="75%" stopColor="#FF6CAB" />
            <Stop offset="100%" stopColor="#FFAFD4" />
          </LinearGradient>
        </Defs>
        <Rect x="0" y="0" width="390" height="164" fill="url(#zokyHeaderBg)" />
        <Path
          d="M0 0H300C282 42 268 91 219 113C160 141 92 149 0 145Z"
          fill="#F50060"
          fillOpacity={0.14}
        />
        <Path
          d="M0 162C69 162 120 156 167 144C219 130 257 110 296 91C335 73 362 70 390 71V164H0Z"
          fill="#FFC1DA"
          fillOpacity={0.22}
        />
        <Path
          d="M236 164C286 134 337 107 390 110V164Z"
          fill="#FFE2ED"
          fillOpacity={0.25}
        />
      </Svg>
      <View style={styles.row}>
        <Logo />
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="รายการโปรด"
          accessibilityHint="เปิดหน้ารายการโปรด"
          onPress={onOpenFavorites}
          hitSlop={8}
          style={({ pressed }) => [
            styles.favoriteButton,
            pressed && styles.favoritePressed
          ]}
        >
          <HeartIcon />
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingHorizontal: 22,
    paddingBottom: 10,
    overflow: "hidden",
    backgroundColor: "#FE0D68"
  },
  backgroundLayer: {
    position: "absolute",
    top: 0,
    left: 0
  },
  row: {
    minHeight: 56,
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "space-between"
  },
  logo: {
    flexShrink: 0
  },
  favoriteButton: {
    width: 46,
    height: 46,
    borderRadius: 23,
    backgroundColor: "#FFFFFF",
    justifyContent: "center",
    alignItems: "center",
    shadowColor: "#9A0044",
    shadowOpacity: 0.08,
    shadowOffset: { width: 0, height: 3 },
    shadowRadius: 8,
    elevation: 2
  },
  favoritePressed: {
    opacity: 0.85,
    transform: [{ scale: 0.96 }]
  }
});

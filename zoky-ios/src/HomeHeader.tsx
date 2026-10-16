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
 * The wordmark contours are auto-traced from the user-uploaded logo image.
 * This preserves the distinctive map-pin 'o' and smile shape more faithfully than
 * the earlier hand-drawn approximation. It is not a replacement for an official vector asset.
 * Gradient and waves are brand-inspired approximations for this UI preview.
 *
 * Only the Home hub/favorites use this header; Food/order flows remain untouched.
 * Padding accounts for the real device safe-area inset (including Dynamic Island).
 */
// Auto-traced from the user-supplied Zoky icon (2026-10-16), not a hand-drawn approximation.
// Six contours retain the Z, map-pin-shaped o and its hole, k, y, and smile.
// White foreground only; the original pink icon tile is intentionally excluded.
const WORDMARK_PATH =
  "M780,433L775,418L764,406L749,400L738,400L725,404L695,424L669,439L634,456L608,466L581,474L552,480L511,484L486,484L446,480L401,470L353,452L302,425L294,423L285,423L271,428L259,440L254,452L254,469L261,485L280,504L321,531L362,550L398,562L439,571L474,575L529,575L568,570L614,559L658,543L687,529L730,502L751,485L767,469L777,453L780,441Z" +
  "M398,97L374,101L355,108L332,122L314,139L301,157L291,177L284,202L283,232L290,263L299,282L308,296L396,409L402,415L408,415L489,300L507,271L515,250L518,237L519,199L515,180L506,158L495,141L480,125L467,115L445,104L422,98Z" +
  "M395,170L412,170L432,179L445,194L449,202L452,215L450,234L441,252L428,264L421,268L408,272L389,271L371,262L358,247L352,228L353,210L361,192L375,178L384,173Z" +
  "M1022,72L1009,69L989,71L973,79L962,90L950,114L919,212L873,106L867,96L858,87L850,82L841,79L819,80L808,84L800,89L790,99L783,112L781,120L781,135L786,152L874,326L869,345L858,366L848,376L840,381L827,386L816,394L810,401L803,416L802,438L805,448L810,457L821,468L830,473L844,477L864,477L874,475L894,467L910,456L927,439L939,422L948,405L990,295L1050,126L1051,107L1047,94L1037,81Z" +
  "M275,53L259,47L239,47L150,66L55,90L37,96L21,105L8,119L4,126L0,140L0,152L3,164L9,175L18,184L34,191L56,191L153,164L160,164L27,348L18,369L16,381L18,400L28,420L42,432L57,437L77,437L265,390L276,386L287,379L296,369L301,360L304,349L303,328L300,319L294,309L287,302L276,296L267,294L245,296L159,319L153,319L279,147L293,124L298,104L296,82L287,64Z" +
  "M547,8L532,23L526,40L535,349L542,367L552,377L562,382L570,384L586,384L604,378L618,366L624,355L626,347L625,284L637,271L647,280L702,344L716,357L731,363L748,363L761,359L770,354L780,345L789,330L791,321L789,304L782,292L700,209L700,207L747,159L769,134L772,125L772,113L768,104L757,94L741,89L718,89L704,93L692,100L623,172L621,133L620,41L617,26L613,18L607,11L591,2L571,0L560,2Z";

function Logo() {
  return (
    <Svg
      width={104}
      height={56}
      viewBox="0 0 1049 575"
      accessible
      accessibilityLabel="โลโก้ Zoky"
      style={styles.logo}
    >
      <Defs>
        <LinearGradient id="wordmarkTint" x1="0%" y1="0%" x2="0%" y2="100%">
          <Stop offset="0%" stopColor="#FFFFFF" />
          <Stop offset="54%" stopColor="#FFFFFF" />
          <Stop offset="100%" stopColor="#FFE7F3" />
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

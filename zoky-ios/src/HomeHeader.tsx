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
 * The white wordmark path was traced from the logo supplied by the founder.
 * It is a vector silhouette of the actual lettering and smile, not a system font.
 * Gradient and waves are brand-inspired approximations for this UI preview.
 *
 * Only the Home hub/favorites use this header; Food/order flows remain untouched.
 * Padding accounts for the real device safe-area inset (including Dynamic Island).
 */
const WORDMARK_PATH =
  "M780,434 775,418 764,406 753,401 738,400 725,404 685,430 641,453 599,469 546,481 484,484 445,480 394,468 344,448 302,425 286,423 271,428 262,436 254,453 254,468 261,485 280,504 321,531 362,550 395,561 440,571 476,575 526,575 573,569 610,560 655,544 692,526 735,498 767,469 778,450Z " +
  "M399,97 360,106 332,122 315,138 301,157 290,180 283,210 283,231 290,263 308,296 402,415 407,415 502,280 517,242 519,200 513,174 503,153 481,126 462,112 445,104 421,98Z " +
  "M401,169 416,171 432,179 444,192 452,214 451,231 441,252 430,263 409,272 393,272 372,263 358,247 352,229 354,206 363,189 378,176Z " +
  "M1024,73 1007,69 989,71 973,79 962,90 950,114 919,212 869,99 858,87 840,79 819,80 799,90 784,110 781,134 786,152 874,326 868,348 859,365 847,377 816,394 804,413 802,437 806,450 820,467 830,473 845,477 863,477 897,465 926,440 947,407 1049,130 1049,99 1043,88Z " +
  "M273,52 259,47 233,48 78,84 29,100 7,121 0,141 2,161 9,175 17,183 31,190 60,190 160,164 23,356 17,375 18,400 28,420 39,430 58,437 95,433 261,391 281,383 296,369 303,353 304,333 296,312 278,297 266,294 251,295 153,319 292,126 298,103 296,82 287,64Z " +
  "M547,8 532,23 526,41 535,348 542,367 554,378 571,384 597,381 617,367 626,347 625,284 638,270 716,357 732,363 747,363 765,357 779,346 788,332 791,320 788,302 781,291 700,207 769,134 772,114 768,104 760,96 740,89 718,89 702,94 692,100 623,172 620,46 617,26 608,12 591,2 572,0Z";

function Logo() {
  return (
    <Svg
      width={108}
      height={59}
      viewBox="0 0 1049 575"
      accessible
      accessibilityLabel="โลโก้ Zoky"
      style={styles.logo}
    >
      <Path d={WORDMARK_PATH} fill="#FFFFFF" fillRule="evenodd" />
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
    height: Math.max(topInset, 0) + 84
  });

  return (
    <View
      style={[styles.container, { paddingTop: Math.max(topInset, 0) + 4 }]}
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
          <LinearGradient id="zokyHeaderBg" x1="0%" y1="40%" x2="100%" y2="52%">
            <Stop offset="0%" stopColor="#F70365" />
            <Stop offset="42%" stopColor="#FE4D95" />
            <Stop offset="76%" stopColor="#FF83B8" />
            <Stop offset="100%" stopColor="#FFBADB" />
          </LinearGradient>
          <LinearGradient id="zokySheen" x1="0%" y1="0%" x2="100%" y2="90%">
            <Stop offset="0%" stopColor="#FFFFFF" stopOpacity={0.20} />
            <Stop offset="100%" stopColor="#FFFFFF" stopOpacity={0} />
          </LinearGradient>
        </Defs>
        <Rect x="0" y="0" width="390" height="164" fill="url(#zokyHeaderBg)" />
        <Path
          d="M0 0H390V19C345 3 308 12 272 51C213 115 150 123 0 118Z"
          fill="url(#zokySheen)"
        />
        <Path
          d="M0 164C65 159 116 151 162 134C212 115 258 80 300 65C338 51 360 52 390 57V164Z"
          fill="#FFCAE2"
          fillOpacity={0.22}
        />
        <Path
          d="M133 164C187 145 237 125 285 106C332 87 357 81 390 84V164Z"
          fill="#FFE5F0"
          fillOpacity={0.23}
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
    paddingBottom: 16,
    overflow: "hidden",
    backgroundColor: "#FE0D68"
  },
  backgroundLayer: {
    position: "absolute",
    top: 0,
    left: 0
  },
  row: {
    minHeight: 64,
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

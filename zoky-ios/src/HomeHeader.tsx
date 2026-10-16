import React, { useState } from "react";
import { Image, Pressable, StyleSheet, useWindowDimensions, View } from "react-native";
import Svg, {
  Defs,
  LinearGradient,
  RadialGradient,
  Path,
  Rect,
  Stop
} from "react-native-svg";

/**
 * Zoky iOS Home — Phase 1 only.
 * Phase 1 brand wordmark is cropped directly from the founder's supplied
 * 1256x1256 transparent PNG without resampling or palette/color reduction.
 * The lossless 1066x590 PNG retains original letterforms, white-pink shading,
 * alpha edge and smile. It is not an AI redraw. No tintColor is applied.
 * Header palette follows sampled background pixels from the founder-supplied
 * 1254px pink JPG: #FE529A, #FC2C80, #FB1470, #F60361 and #D10248;
 * glossy berry shadows borrow #A40229 and #B6113C from the same icon.
 * The square source art has curved specular highlights, so this wide header
 * approximates its lighting; it is not claimed to be pixel-identical.
 * The high-resolution 1066x590 wordmark PNG is preserved without tinting.
 */
function Logo() {
  return (
    <Image
      source={require("../assets/zoky-wordmark-original-1066.png")}
      style={styles.logo}
      resizeMode="contain"
      accessible
      accessibilityLabel="โลโก้ Zoky"
    />
  );
}

function HeartIcon() {
  return (
    <Svg width={26} height={26} viewBox="0 0 24 24" accessibilityElementsHidden>
      <Path
        d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 1 0-7.78 7.78L12 21.23l8.84-8.84a5.5 5.5 0 0 0 0-7.78Z"
        fill="none"
        stroke="#F60361"
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
          {/* Match the actual glossy-pink square supplied for Zoky:
              bright upper highlight, saturated magenta body, deep berry shading. */}
          <LinearGradient id="zokyHeaderBg" x1="0%" y1="0%" x2="100%" y2="90%">
            <Stop offset="0%" stopColor="#FE529A" />
            <Stop offset="28%" stopColor="#FC2C80" />
            <Stop offset="57%" stopColor="#FB1470" />
            <Stop offset="82%" stopColor="#F60361" />
            <Stop offset="100%" stopColor="#D10248" />
          </LinearGradient>
          <RadialGradient id="zokyBerryDepth" cx="37%" cy="96%" r="76%">
            <Stop offset="0%" stopColor="#A40229" stopOpacity={0.47} />
            <Stop offset="44%" stopColor="#B6113C" stopOpacity={0.22} />
            <Stop offset="100%" stopColor="#B6113C" stopOpacity={0} />
          </RadialGradient>
          <LinearGradient id="zokyGloss" x1="0%" y1="0%" x2="0%" y2="100%">
            <Stop offset="0%" stopColor="#FFF5FA" stopOpacity={0.30} />
            <Stop offset="55%" stopColor="#FFCDDF" stopOpacity={0.10} />
            <Stop offset="100%" stopColor="#FFF5FA" stopOpacity={0} />
          </LinearGradient>
        </Defs>
        <Rect x="0" y="0" width="390" height="164" fill="url(#zokyHeaderBg)" />
        <Rect x="0" y="0" width="390" height="164" fill="url(#zokyBerryDepth)" />
        <Path
          d="M0 0H390V19C323 23 294 47 240 68C166 98 86 91 0 65Z"
          fill="url(#zokyGloss)"
        />
        <Path
          d="M0 164C73 154 129 149 181 129C229 111 273 83 316 72C346 65 366 64 390 64V164Z"
          fill="#FF6DA9"
          fillOpacity={0.17}
        />
        <Path
          d="M208 164C277 134 335 118 390 114V164Z"
          fill="#FFA9D2"
          fillOpacity={0.16}
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
    backgroundColor: "#F60361"
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
    width: 110,
    height: 61,
    flexShrink: 0
  },
  favoriteButton: {
    width: 46,
    height: 46,
    borderRadius: 23,
    backgroundColor: "#FFFFFF",
    justifyContent: "center",
    alignItems: "center",
    shadowColor: "#A30128",
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

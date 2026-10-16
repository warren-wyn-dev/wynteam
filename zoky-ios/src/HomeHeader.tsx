import React from "react";
import { Image, Pressable, StyleSheet, useWindowDimensions, View } from "react-native";
import Svg, { Path } from "react-native-svg";

/**
 * Zoky iOS Home — Phase 1 ONLY (design review).
 * Original wordmark pixels: assets/zoky-wordmark-original-1066.png
 * The image is a lossless high-resolution crop of the founder's supplied logo.
 * Original-background pixels: assets/zoky-header-from-original-jpg.jpg
 * The background is directly cropped from the founder's 1256px source photo,
 * fitted inside the compact banner while preserving its aspect ratio. The
 * wordmark and backdrop are source-derived, not generated or redrawn.
 * Since square icon art must be adapted to a wide responsive header,
 * this preserves source artwork but does NOT promise pixel-perfect equivalence.
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
  const { width: screenWidth } = useWindowDimensions();
  const safeTop = Math.max(topInset, 0);
  const headerHeight = safeTop + 75;

  return (
    <View
      style={[styles.container, { height: headerHeight }]}
      accessibilityLabel="ส่วนหัวหน้าหลัก"
    >
      <Image
        source={require("../assets/zoky-header-from-original-jpg.jpg")}
        resizeMode="cover"
        style={[styles.backgroundLayer, { width: screenWidth, height: headerHeight }]}
        pointerEvents="none"
        accessible={false}
        importantForAccessibility="no"
      />
      <View style={[styles.row, { top: safeTop + 2 }]}>
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
    width: "100%",
    flexGrow: 0,
    flexShrink: 0,
    overflow: "hidden",
    backgroundColor: "#F60361"
  },
  backgroundLayer: {
    position: "absolute",
    top: 0,
    left: 0,
    zIndex: 0
  },
  row: {
    position: "absolute",
    left: 22,
    right: 22,
    height: 61,
    zIndex: 2,
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

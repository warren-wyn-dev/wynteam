import React from "react";
import { Image, Pressable, StyleSheet, View } from "react-native";
import Svg, { Path } from "react-native-svg";

/**
 * Zoky iOS Home — Phase 1 ONLY (design review).
 * Original wordmark pixels: assets/zoky-wordmark-original-1066.png
 * The image is a lossless high-resolution crop of the founder's supplied logo.
 * Original-background pixels: assets/zoky-header-from-original-jpg.jpg
 * The background is directly cropped from the founder's 1256px source photo,
 * resized as a photographic strip; no AI artwork, SVG gradient, letters or
 * manually traced paths are used to reproduce the wordmark or its backdrop.
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
  return (
    <View
      style={[styles.container, { paddingTop: Math.max(topInset, 0) + 2 }]}
      accessibilityLabel="ส่วนหัวหน้าหลัก"
    >
      <Image
        source={require("../assets/zoky-header-from-original-jpg.jpg")}
        resizeMode="stretch"
        style={styles.backgroundLayer}
        accessible={false}
        importantForAccessibility="no"
      />
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
    ...StyleSheet.absoluteFillObject,
    width: "100%",
    height: "100%"
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

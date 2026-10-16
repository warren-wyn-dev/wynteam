import React, { useState } from "react";
import { Image, Pressable, StyleSheet, useWindowDimensions, View } from "react-native";
import Svg, {
  Defs,
  LinearGradient,
  Path,
  Rect,
  Stop
} from "react-native-svg";

/**
 * Zoky iOS Home — Phase 1 only.
 * Phase 1 brand wordmark is sourced from the founder's supplied transparent
 * PNG (rather than a traced imitation). The 320x177 Retina-ready export
 * preserves the original shape and white-to-pink tone while reducing blur
 * from the old 150x83 low-resolution placeholder. No tintColor is applied.
 * Colors are sampled from the original pink logo JPG (1254 x 1254 px).
 * Exact sampled pixels used: #F20361, #FD1E77, #FC559A, #FD92C0;
 * original photo is a curved glossy square, so the compact header uses
 * matching colour stops rather than pretending the rectangular crop is identical.
 */
function Logo() {
  return (
    <Image
      source={require("../assets/zoky-wordmark-320.png")}
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
        stroke="#F20361"
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
          {/* Brand stops sampled from user's original pink-background JPG, not approximated colours. */}
          <LinearGradient id="zokyHeaderBg" x1="0%" y1="22%" x2="100%" y2="65%">
            <Stop offset="0%" stopColor="#F20361" />
            <Stop offset="28%" stopColor="#FD1E77" />
            <Stop offset="64%" stopColor="#FC559A" />
            <Stop offset="100%" stopColor="#FD92C0" />
          </LinearGradient>
          <LinearGradient id="zokyGloss" x1="0%" y1="0%" x2="0%" y2="100%">
            <Stop offset="0%" stopColor="#FFF1F9" stopOpacity={0.22} />
            <Stop offset="42%" stopColor="#FFC4DD" stopOpacity={0.06} />
            <Stop offset="100%" stopColor="#FD1E77" stopOpacity={0} />
          </LinearGradient>
        </Defs>
        <Rect x="0" y="0" width="390" height="164" fill="url(#zokyHeaderBg)" />
        <Rect x="0" y="0" width="390" height="164" fill="url(#zokyGloss)" />
        <Path
          d="M0 0H300C282 42 268 91 219 113C160 141 92 149 0 145Z"
          fill="#BA023E"
          fillOpacity={0.11}
        />
        <Path
          d="M0 162C69 162 120 156 167 144C219 130 257 110 296 91C335 73 362 70 390 71V164H0Z"
          fill="#FDA9CD"
          fillOpacity={0.22}
        />
        <Path
          d="M236 164C286 134 337 107 390 110V164Z"
          fill="#FFC4DD"
          fillOpacity={0.24}
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
    backgroundColor: "#F20361"
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

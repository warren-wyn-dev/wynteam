"use client";

import { useId } from "react";

/**
 * WYN-204: Wynos Merchant's own 3D icon set, drawn as SVG (no third-party
 * artwork). Each icon is one object lit from the top-left: a light-to-base
 * top face, a base-to-dark body, a soft white highlight and a floor shadow.
 */
export type MerchantIcon3DName = "orders" | "campaign" | "menu" | "store" | "reports" | "bell" | "sound" | "install";

type Tone = "red" | "amber" | "green" | "blue" | "violet";

const TONES: Record<Tone, { light: string; base: string; dark: string }> = {
  red: { light: "#ff8a94", base: "#ef2b3c", dark: "#b3162a" },
  amber: { light: "#ffd480", base: "#ffa31a", dark: "#d97706" },
  green: { light: "#86e5ad", base: "#22b45e", dark: "#12813f" },
  blue: { light: "#94ccff", base: "#2f8cf0", dark: "#1a5cc0" },
  violet: { light: "#c6adff", base: "#8a5cf6", dark: "#5a33c8" },
};

const TONE_OF: Record<MerchantIcon3DName, Tone> = {
  orders: "red",
  campaign: "amber",
  menu: "green",
  store: "blue",
  reports: "violet",
  bell: "red",
  sound: "violet",
  install: "blue",
};

type Paint = { top: string; body: string; light: string; base: string; dark: string };

const SHINE = "rgba(255,255,255,.6)";

const SHAPES: Record<MerchantIcon3DName, (p: Paint) => React.ReactNode> = {
  orders: (p) => (
    <>
      <path d="M15 20c0-10 18-10 18 0" fill="none" stroke={p.dark} strokeWidth="3.6" strokeLinecap="round" />
      <path d="M16.6 17.5c1.6-5 13.2-5 14.8 0" fill="none" stroke={SHINE} strokeWidth="1.3" strokeLinecap="round" />
      <path d="M10 24h28l-3 14a3.4 3.4 0 0 1-3.3 2.7H16.3A3.4 3.4 0 0 1 13 38z" fill={p.body} />
      <path d="M18 28v8M24 28v8M30 28v8" stroke={p.dark} strokeOpacity=".45" strokeWidth="2.2" strokeLinecap="round" />
      <rect x="7" y="18" width="34" height="7" rx="3.5" fill={p.top} />
      <rect x="10" y="19.4" width="15" height="2" rx="1" fill={SHINE} />
    </>
  ),
  campaign: (p) => (
    <>
      <path d="M14.5 26.5 17 36a2 2 0 0 0 2.4 1.4l1.4-.4a2 2 0 0 0 1.4-2.4l-2-7.2z" fill={p.dark} />
      <path d="M12 19.5 31.5 11a2.6 2.6 0 0 1 3.6 2.4v19.2a2.6 2.6 0 0 1-3.6 2.4L12 26.5z" fill={p.top} />
      <rect x="7" y="17.5" width="8" height="11" rx="3" fill={p.body} />
      <ellipse cx="34.6" cy="23" rx="2.6" ry="10.4" fill={p.dark} fillOpacity=".55" />
      <path d="M15.5 19.4 29.5 13.4" stroke={SHINE} strokeWidth="2" strokeLinecap="round" />
      <path d="M39.5 17.5c2.2 3.6 2.2 7.4 0 11" fill="none" stroke={p.base} strokeWidth="2.6" strokeLinecap="round" />
    </>
  ),
  menu: (p) => (
    <>
      <path d="M27 7.5 35.5 21M31.5 6.5l6 13" stroke="#c97b3d" strokeWidth="2.6" strokeLinecap="round" />
      <path d="M10 22.5c1.5-7.5 7-10 14-10s12.5 2.5 14 10z" fill="#fff6e6" />
      <path d="M15 17.5c2-2.4 5-3.4 8-3.4" fill="none" stroke="#fff" strokeWidth="2" strokeLinecap="round" />
      <ellipse cx="24" cy="22.5" rx="17" ry="3.3" fill={p.light} />
      <path d="M7 22.5h34c-.6 9.8-7.4 15.5-17 15.5S7.6 32.3 7 22.5z" fill={p.body} />
      <rect x="17.5" y="36.5" width="13" height="3.5" rx="1.75" fill={p.dark} />
      <path d="M11.5 26.5c1.2 4.4 4 7.4 7.5 8.6" fill="none" stroke={SHINE} strokeWidth="2" strokeLinecap="round" />
    </>
  ),
  store: (p) => (
    <>
      <rect x="10" y="20" width="28" height="20" rx="3" fill={p.body} />
      <rect x="19.5" y="27" width="9" height="13" rx="1.6" fill={p.dark} />
      <rect x="30" y="25.5" width="5.5" height="5" rx="1.2" fill={p.light} />
      <rect x="12.5" y="25.5" width="5" height="5" rx="1.2" fill={p.light} />
      <path d="M7 15.5 10.5 9h27l3.5 6.5v2.3a3.7 3.7 0 0 1-7 1.6 3.7 3.7 0 0 1-6.7 0 3.7 3.7 0 0 1-6.6 0 3.7 3.7 0 0 1-6.7 0 3.7 3.7 0 0 1-7-1.6z" fill={p.top} />
      <path d="M16 10v9.6M24 10v9.6M32 10v9.6" stroke="#fff" strokeOpacity=".7" strokeWidth="3.2" />
      <rect x="9" y="7" width="30" height="3.6" rx="1.8" fill={p.dark} />
    </>
  ),
  reports: (p) => (
    <>
      <rect x="7" y="36" width="34" height="4.5" rx="2.25" fill={p.dark} />
      <rect x="10" y="24" width="7.5" height="13" rx="2.2" fill={p.light} />
      <rect x="20.25" y="16" width="7.5" height="21" rx="2.2" fill={p.top} />
      <rect x="30.5" y="8.5" width="7.5" height="28.5" rx="2.2" fill={p.body} />
      <rect x="11.5" y="25.5" width="2" height="6" rx="1" fill={SHINE} />
      <rect x="21.75" y="17.5" width="2" height="9" rx="1" fill={SHINE} />
      <rect x="32" y="10" width="2" height="11" rx="1" fill={SHINE} />
    </>
  ),
  bell: (p) => (
    <>
      <circle cx="24" cy="37.5" r="4" fill={p.dark} />
      <path d="M24 6.5a2.2 2.2 0 0 1 2.2 2.2v.6c5.4 1.2 8.8 5.8 8.8 11.7v6.5l3.6 4.6c.9 1.2.1 2.9-1.4 2.9H10.8c-1.5 0-2.3-1.7-1.4-2.9l3.6-4.6V21c0-5.9 3.4-10.5 8.8-11.7v-.6A2.2 2.2 0 0 1 24 6.5z" fill={p.top} />
      <path d="M9.6 32.5h28.8" stroke={p.dark} strokeOpacity=".35" strokeWidth="2" />
      <path d="M18.2 14.5c-1.6 1.9-2.4 4.2-2.4 7.2v4" fill="none" stroke={SHINE} strokeWidth="2.2" strokeLinecap="round" />
    </>
  ),
  sound: (p) => (
    <>
      <rect x="7" y="17.5" width="9.5" height="13" rx="2.4" fill={p.dark} />
      <path d="M15 18 26.4 9.6c1.7-1.2 4-.1 4 2v24.8c0 2.1-2.3 3.2-4 2L15 30z" fill={p.top} />
      <path d="M18 18.2 26 12.4" stroke={SHINE} strokeWidth="2" strokeLinecap="round" />
      <path d="M34.5 18.5c2.4 3.4 2.4 7.6 0 11" fill="none" stroke={p.base} strokeWidth="2.6" strokeLinecap="round" />
      <path d="M38.5 14.5c4.4 5.6 4.4 13.4 0 19" fill="none" stroke={p.light} strokeWidth="2.6" strokeLinecap="round" />
    </>
  ),
  install: (p) => (
    <>
      <rect x="13.5" y="5.5" width="21" height="35" rx="5" fill={p.body} />
      <rect x="16.5" y="9.5" width="15" height="25" rx="2.4" fill="#f4f9ff" />
      <path d="M24 14v12.5M19.6 22.2 24 26.6l4.4-4.4" fill="none" stroke={p.base} strokeWidth="2.6" strokeLinecap="round" strokeLinejoin="round" />
      <rect x="21" y="36.4" width="6" height="1.8" rx=".9" fill={p.light} />
      <path d="M15.5 9.5v8" stroke={SHINE} strokeWidth="1.4" strokeLinecap="round" />
    </>
  ),
};

export function MerchantIcon3D({ name, size = 44 }: { name: MerchantIcon3DName; size?: number }) {
  // useId may contain characters that break url(#…) references.
  const id = useId().replace(/[^a-zA-Z0-9_-]/g, "");
  const tone = TONES[TONE_OF[name]];
  // The name is part of the id too, so even icons rendered in separate React
  // roots only ever share an id with an identical gradient.
  const top = `wm3d-${name}-${id}-top`;
  const body = `wm3d-${name}-${id}-body`;
  const shadow = `wm3d-${name}-${id}-shadow`;
  return (
    <svg className="wm-icon-3d" width={size} height={size} viewBox="0 0 48 48" aria-hidden="true" focusable="false">
      <defs>
        <linearGradient id={top} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={tone.light} />
          <stop offset="1" stopColor={tone.base} />
        </linearGradient>
        <linearGradient id={body} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={tone.base} />
          <stop offset="1" stopColor={tone.dark} />
        </linearGradient>
        <radialGradient id={shadow}>
          <stop offset="0" stopColor="#000" stopOpacity=".24" />
          <stop offset="1" stopColor="#000" stopOpacity="0" />
        </radialGradient>
      </defs>
      <ellipse cx="24" cy="43.5" rx="15" ry="3.2" fill={`url(#${shadow})`} />
      {SHAPES[name]({ top: `url(#${top})`, body: `url(#${body})`, ...tone })}
    </svg>
  );
}

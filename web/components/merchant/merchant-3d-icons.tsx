"use client";

import { useId } from "react";

/**
 * WYN-204: Wynos Merchant's own 3D icon set, drawn as SVG (no third-party
 * artwork). Each icon is one object lit from the top-left: a light-to-base
 * top face, a base-to-dark body, a soft white highlight and a floor shadow.
 */
export type MerchantIcon3DName = "orders" | "ads" | "campaign" | "promotion" | "finance" | "menu" | "store" | "reports" | "bell" | "sound" | "install";

type Tone = "red";

const TONES: Record<Tone, { light: string; base: string; dark: string }> = {
  red: { light: "#ff8a94", base: "#ef2b3c", dark: "#b3162a" },
};

// Founder: "ทุกหน้า ต้องคุมโทนสีประจำนะให้เด่นกว่า คือสีแดง" and
// "ถ้ามีสีรุ้ง ตัดทิ้งเลย ไม่ใช้แล้ว": every icon is Wynos red and white.
const TONE_OF: Record<MerchantIcon3DName, Tone> = {
  orders: "red",
  ads: "red",
  campaign: "red",
  promotion: "red",
  finance: "red",
  menu: "red",
  store: "red",
  reports: "red",
  bell: "red",
  sound: "red",
  install: "red",
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
  ads: (p) => (
    <>
      <path d="M14.5 26.5 17 36a2 2 0 0 0 2.4 1.4l1.4-.4a2 2 0 0 0 1.4-2.4l-2-7.2z" fill={p.dark} />
      <path d="M12 19.5 31.5 11a2.6 2.6 0 0 1 3.6 2.4v19.2a2.6 2.6 0 0 1-3.6 2.4L12 26.5z" fill={p.top} />
      <rect x="7" y="17.5" width="8" height="11" rx="3" fill={p.body} />
      <ellipse cx="34.6" cy="23" rx="2.6" ry="10.4" fill={p.dark} fillOpacity=".55" />
      <path d="M15.5 19.4 29.5 13.4" stroke={SHINE} strokeWidth="2" strokeLinecap="round" />
      <path d="M39.5 17.5c2.2 3.6 2.2 7.4 0 11" fill="none" stroke={p.base} strokeWidth="2.6" strokeLinecap="round" />
    </>
  ),
  campaign: (p) => (
    <>
      <rect x="9" y="21" width="30" height="19" rx="3" fill={p.body} />
      <rect x="21" y="21" width="6" height="19" fill="#ffffff" fillOpacity=".92" />
      <rect x="7" y="15" width="34" height="8" rx="3" fill={p.top} />
      <rect x="21" y="15" width="6" height="8" fill="#ffffff" />
      <path d="M24 15c-2.5-6-10-7.5-10.5-3.2C13 15 19 15.5 24 15zM24 15c2.5-6 10-7.5 10.5-3.2C35 15 29 15.5 24 15z" fill="#ffffff" stroke="#ffd8dc" strokeWidth="1.2" />
      <rect x="10" y="16.4" width="10" height="2" rx="1" fill={SHINE} />
      <path d="M12 25v11" stroke={SHINE} strokeWidth="2" strokeLinecap="round" />
    </>
  ),
  promotion: (p) => (
    <>
      <path d="M8 22.5V11a3 3 0 0 1 3-3h11.5a3 3 0 0 1 2.1.9l14.5 14.5a3 3 0 0 1 0 4.2L27.6 39.1a3 3 0 0 1-4.2 0L8.9 24.6a3 3 0 0 1-.9-2.1z" fill={p.top} />
      <path d="M38.6 28.4 27.6 39.4a3 3 0 0 1-4.2 0L9 25l1.2-1.6 14.6 14.4a2 2 0 0 0 2.8 0L39 26.6z" fill={p.dark} fillOpacity=".55" />
      <circle cx="15.5" cy="15.5" r="3" fill="#fff" />
      <path d="m20 30 9.5-9.5" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" />
      <circle cx="21.5" cy="23.5" r="2" fill="#fff" />
      <circle cx="28" cy="29" r="2" fill="#fff" />
      <path d="M11 11.5v7" stroke={SHINE} strokeWidth="1.8" strokeLinecap="round" />
    </>
  ),
  finance: (p) => (
    <>
      <path d="M11 14 30 8.5a2.5 2.5 0 0 1 3.1 1.7L34.5 15H11z" fill={p.dark} />
      <rect x="7" y="14" width="34" height="25" rx="5" fill={p.top} />
      <path d="M7 31h34v3a5 5 0 0 1-5 5H12a5 5 0 0 1-5-5z" fill={p.body} />
      <rect x="29" y="21.5" width="13" height="9" rx="4.5" fill={p.dark} />
      <circle cx="34" cy="26" r="2.2" fill="#ffffff" />
      <rect x="10" y="16.5" width="15" height="2" rx="1" fill={SHINE} />
    </>
  ),
  menu: (p) => (
    <>
      <path d="M27 7.5 35.5 21M31.5 6.5l6 13" stroke="#b3162a" strokeWidth="2.6" strokeLinecap="round" />
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
      <rect x="16.5" y="9.5" width="15" height="25" rx="2.4" fill="#fff6f7" />
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

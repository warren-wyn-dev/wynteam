"use client";

/**
 * ZOKY web — presentational pieces ported from the approved Flutter app
 * (zoky_app/lib/core/widgets, features/home, features/food). Inline SVG/CSS
 * only: no data access, no new dependencies. Numbers follow
 * .wyn/docs/design/zoky-web-home-food-spec.md section 6 (24-unit grid).
 */

import { ShoppingBag } from "lucide-react";
import Image from "next/image";
import { useEffect, useId, type ReactNode } from "react";

/** Food page status-bar tint; the previous theme colours come back on leave. */
export function useZokyThemeColor(color: string) {
  useEffect(() => {
    const metas = Array.from(document.querySelectorAll<HTMLMetaElement>('meta[name="theme-color"]'));
    const previous = metas.map((meta) => meta.content);
    metas.forEach((meta) => { meta.content = color; });
    return () => { metas.forEach((meta, index) => { meta.content = previous[index]; }); };
  }, [color]);
}

/* ---------- 3D icons (Zoky3DIcon) ---------- */

export type Zoky3DGlyph = "heart" | "sparkle" | "star" | "ticket" | "arrowRight";

const PALETTES = {
  pink: { top: "#FF6BAA", bottom: "#E5135D", shade: "#9E0E3E", shadow: "#C2185B" },
  gold: { top: "#FFD45C", bottom: "#F59E0B", shade: "#B45309", shadow: "#C2700A" },
} as const;

type GlyphSpec = {
  d: string;
  /** cx, cy, width, height, rotation (degrees) of the specular highlight. */
  highlight: [number, number, number, number, number];
  rotate?: number;
  round?: boolean;
};

const GLYPHS: Record<Zoky3DGlyph, GlyphSpec> = {
  heart: {
    d: "M12 20.88 C4.8 16.08 1.2 12 1.68 7.92 C2.16 4.08 5.28 2.4 7.92 2.64 C10.08 2.88 11.28 4.08 12 5.52 C12.72 4.08 13.92 2.88 16.08 2.64 C18.72 2.4 21.84 4.08 22.32 7.92 C22.8 12 19.2 16.08 12 20.88Z",
    highlight: [6.96, 6.48, 5.76, 3.12, -25.8],
  },
  sparkle: {
    d: "M12 1.2 Q14.4 9.6 22.8 12 Q14.4 14.4 12 22.8 Q9.6 14.4 1.2 12 Q9.6 9.6 12 1.2Z",
    highlight: [10.32, 9.12, 2.88, 4.8, 28.6],
  },
  star: {
    d: "M12 0.96 L14.96 7.92 L22.5 8.59 L16.79 13.56 L18.49 20.93 L12 17.04 L5.51 20.93 L7.21 13.56 L1.5 8.59 L9.04 7.92Z",
    highlight: [9.6, 8.64, 4.8, 2.88, -25.8],
    round: true,
  },
  ticket: {
    d: "M4.32 6.48 H19.68 A1.92 1.92 0 0 1 21.6 8.4 V9.96 A2.04 2.04 0 0 0 21.6 14.04 V15.6 A1.92 1.92 0 0 1 19.68 17.52 H4.32 A1.92 1.92 0 0 1 2.4 15.6 V14.04 A2.04 2.04 0 0 0 2.4 9.96 V8.4 A1.92 1.92 0 0 1 4.32 6.48Z",
    highlight: [7.2, 9.12, 6.24, 2.4, 0],
    rotate: -14.9,
  },
  arrowRight: {
    d: "M1.44 11.52 A10.56 10.56 0 1 0 22.56 11.52 A10.56 10.56 0 1 0 1.44 11.52Z",
    highlight: [8.16, 5.28, 8.64, 3.84, -25.8],
  },
};

const EMBOSSED: Partial<Record<Zoky3DGlyph, { d: string; width: number }>> = {
  ticket: { d: "M15.36 8.16v1.44 M15.36 11.28v1.44 M15.36 14.4v1.44", width: 1.8 },
  arrowRight: { d: "M7.44 11.52H16.08 M12.48 7.92L16.08 11.52L12.48 15.12", width: 2.64 },
};

export function Zoky3DIcon({
  glyph,
  size = 24,
  palette = "pink",
  className,
}: {
  glyph: Zoky3DGlyph;
  size?: number;
  palette?: keyof typeof PALETTES;
  className?: string;
}) {
  const uid = useId().replace(/:/g, "");
  const p = PALETTES[palette];
  const g = GLYPHS[glyph];
  const emboss = EMBOSSED[glyph];
  const [hx, hy, hw, hh, hr] = g.highlight;
  const id = (name: string) => `zk3d-${uid}-${name}`;
  const roundStroke = g.round ? { stroke: `url(#${id("body")})`, strokeWidth: 1.2, strokeLinejoin: "round" as const } : {};
  return (
    <svg className={className} width={size} height={size} viewBox="0 0 24 24" aria-hidden="true" focusable="false">
      <defs>
        <linearGradient id={id("body")} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={p.top} />
          <stop offset="1" stopColor={p.bottom} />
        </linearGradient>
        <linearGradient id={id("white")} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#FFFFFF" />
          <stop offset="1" stopColor="#FFE0EC" />
        </linearGradient>
        <filter id={id("drop")} x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="0.96" />
        </filter>
        <filter id={id("shade")} x="-10%" y="-10%" width="120%" height="120%">
          <feGaussianBlur stdDeviation="1.08" />
        </filter>
        <filter id={id("rim")} x="-10%" y="-10%" width="120%" height="120%">
          <feGaussianBlur stdDeviation="0.48" />
        </filter>
        <filter id={id("soft")} x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="0.6" />
        </filter>
        <filter id={id("emb")} x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="0.29" />
        </filter>
        <clipPath id={id("clip")}>
          <path d={g.d} />
        </clipPath>
      </defs>
      <g transform={g.rotate ? `rotate(${g.rotate} 12 12)` : undefined}>
        {/* 1. soft drop shadow */}
        <path d={g.d} transform="translate(0.48 1.44)" fill={p.shadow} opacity={0.3} filter={`url(#${id("drop")})`} />
        {/* 2. body */}
        <path d={g.d} fill={`url(#${id("body")})`} {...roundStroke} />
        <g clipPath={`url(#${id("clip")})`}>
          {/* 3. inner shade bottom-right and light rim top-left (outside of a shifted body, blurred) */}
          <path fillRule="evenodd" d={`M-24 -24H48V48H-24Z ${g.d}`} transform="translate(-1.68 -1.92)" fill={p.shade} fillOpacity={0.38} filter={`url(#${id("shade")})`} />
          <path fillRule="evenodd" d={`M-24 -24H48V48H-24Z ${g.d}`} transform="translate(0.72 0.96)" fill="#FFFFFF" fillOpacity={0.55} filter={`url(#${id("rim")})`} />
          {/* 4. specular highlight: halo + core */}
          <g transform={`translate(${hx} ${hy}) rotate(${hr})`}>
            <ellipse rx={hw / 2} ry={hh / 2} fill="#FFFFFF" fillOpacity={0.7} filter={`url(#${id("soft")})`} />
            <ellipse cx={-hw * 0.12} rx={(hw * 0.45) / 2} ry={(hh * 0.45) / 2} fill="#FFFFFF" fillOpacity={0.9} />
          </g>
        </g>
        {emboss ? (
          <g fill="none" strokeLinecap="round" strokeLinejoin="round" strokeWidth={emboss.width}>
            <path d={emboss.d} transform="translate(0 0.84)" stroke="#8E0F38" strokeOpacity={0.35} filter={`url(#${id("emb")})`} />
            <path d={emboss.d} stroke={`url(#${id("white")})`} />
          </g>
        ) : null}
      </g>
    </svg>
  );
}

/* ---------- Nav icons (ZokyNavIcon) ---------- */

export type ZokyNavGlyph = "home" | "orders" | "messages" | "account";

const NAV_STROKE = 1.632;
const HOUSE = "M9.791 3.315 Q12 1 14.209 3.315 L21.779 11.249 Q22.4 11.9 21.5 11.9 L20.6 11.9 Q20.1 11.9 20.1 12.4 L20.1 19 Q20.1 21.4 17.7 21.4 L15 21.4 Q14.1 21.4 14.1 20.5 L14.1 16.8 Q14.1 14.7 12 14.7 Q9.9 14.7 9.9 16.8 L9.9 20.5 Q9.9 21.4 9 21.4 L6.3 21.4 Q3.9 21.4 3.9 19 L3.9 12.4 Q3.9 11.9 3.4 11.9 L2.5 11.9 Q1.6 11.9 2.221 11.249Z";
const BOARD_OPEN = "M9.3 3.4H6.7A3 3 0 0 0 3.7 6.4V19.2A3 3 0 0 0 6.7 22.2H17.3A3 3 0 0 0 20.3 19.2V6.4A3 3 0 0 0 17.3 3.4H14.7";
const BOARD_LINES = "M8.4 10H12.6M8.4 13.4H15.6M8.4 16.8H13.9";
const BUBBLE = "M8.204 19.965A10.1 9.25 0 1 0 4.413 17.396L2.421 20.619Q2 21.3 2.782 21.132Z";
const BUBBLE_DOTS = [7.45, 12.15, 16.85];
const PERSON_BODY = "M9.2 13.5H14.8A5.2 5.6 0 0 1 20 19.1V19.65A2.6 2.6 0 0 1 17.4 22.25H6.6A2.6 2.6 0 0 1 4 19.65V19.1A5.2 5.6 0 0 1 9.2 13.5Z";

function NavOutline({ glyph }: { glyph: ZokyNavGlyph }) {
  const line = { fill: "none", stroke: "#6B6B76", strokeWidth: NAV_STROKE, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  if (glyph === "home") return <path d={HOUSE} {...line} />;
  if (glyph === "orders") {
    return (
      <>
        <path d={BOARD_OPEN} {...line} />
        <rect x="9.3" y="2" width="5.4" height="3.4" rx="1.4" {...line} />
        <path d={BOARD_LINES} {...line} />
      </>
    );
  }
  if (glyph === "messages") {
    return (
      <>
        <path d={BUBBLE} {...line} />
        {BUBBLE_DOTS.map((cx) => <circle key={cx} cx={cx} cy="11.45" r="1.35" fill="#6B6B76" />)}
      </>
    );
  }
  return (
    <>
      <circle cx="12" cy="6.75" r="4.35" {...line} />
      <path d={PERSON_BODY} {...line} />
    </>
  );
}

/** White = filled body, black = cut-outs (same order as the Flutter paint ops). */
function NavMask({ glyph }: { glyph: ZokyNavGlyph }) {
  const solid = { fill: "#fff", stroke: "#fff", strokeWidth: NAV_STROKE, strokeLinecap: "round" as const, strokeLinejoin: "round" as const };
  if (glyph === "home") return <path d={HOUSE} {...solid} />;
  if (glyph === "orders") {
    return (
      <>
        <rect x="3.7" y="3.4" width="16.6" height="18.8" rx="3" {...solid} />
        <rect x="7.634" y="0.334" width="8.732" height="6.732" rx="3.066" fill="#000" />
        <rect x="9.3" y="2" width="5.4" height="3.4" rx="1.4" {...solid} />
        <rect x="10.7" y="3.15" width="2.6" height="1.1" rx="0.55" fill="#000" />
        <path d={BOARD_LINES} fill="none" stroke="#000" strokeWidth={NAV_STROKE} strokeLinecap="round" />
      </>
    );
  }
  if (glyph === "messages") {
    return (
      <>
        <path d={BUBBLE} {...solid} />
        {BUBBLE_DOTS.map((cx) => <circle key={cx} cx={cx} cy="11.45" r="1.35" fill="#000" />)}
      </>
    );
  }
  return (
    <>
      <circle cx="12" cy="6.75" r="4.35" {...solid} />
      <path d={PERSON_BODY} {...solid} />
    </>
  );
}

function NavMarks({ glyph }: { glyph: ZokyNavGlyph }) {
  if (glyph === "orders") {
    return (
      <>
        <rect x="10.7" y="3.15" width="2.6" height="1.1" rx="0.55" fill="#fff" />
        <path d={BOARD_LINES} fill="none" stroke="#fff" strokeWidth={NAV_STROKE} strokeLinecap="round" />
      </>
    );
  }
  if (glyph === "messages") return <>{BUBBLE_DOTS.map((cx) => <circle key={cx} cx={cx} cy="11.45" r="1.35" fill="#fff" />)}</>;
  return null;
}

export function ZokyNavIcon({ glyph, selected, size = 26 }: { glyph: ZokyNavGlyph; selected: boolean; size?: number }) {
  const uid = useId().replace(/:/g, "");
  const id = (name: string) => `zknav-${uid}-${name}`;
  if (!selected) {
    return (
      <svg className="zk-nav-icon" width={size} height={size} viewBox="0 0 24 24" aria-hidden="true" focusable="false">
        <NavOutline glyph={glyph} />
      </svg>
    );
  }
  return (
    <svg className="zk-nav-icon is-selected" width={size} height={size} viewBox="0 0 24 24" aria-hidden="true" focusable="false" overflow="visible">
      <defs>
        <mask id={id("m")} maskUnits="userSpaceOnUse" x="-4" y="-4" width="32" height="32">
          <NavMask glyph={glyph} />
        </mask>
        <linearGradient id={id("body")} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#F4368D" />
          <stop offset="1" stopColor="#D61256" />
        </linearGradient>
        <linearGradient id={id("shade")} x1="0.4" y1="0.4" x2="1" y2="1">
          <stop offset="0" stopColor="#AF1341" stopOpacity="0" />
          <stop offset="1" stopColor="#991636" stopOpacity="0.4" />
        </linearGradient>
        <radialGradient id={id("hl")} cx="0.29" cy="0.21" r="0.55">
          <stop offset="0" stopColor="#fff" stopOpacity="0.8" />
          <stop offset="0.35" stopColor="#fff" stopOpacity="0.25" />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </radialGradient>
        <filter id={id("drop")} x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="1.85" />
        </filter>
      </defs>
      <g transform="translate(0 1.44)" filter={`url(#${id("drop")})`} opacity="0.32">
        <rect x="-2" y="-2" width="28" height="28" fill="#C2185B" mask={`url(#${id("m")})`} />
      </g>
      <g mask={`url(#${id("m")})`}>
        <rect x="0" y="0" width="24" height="24" fill={`url(#${id("body")})`} />
        <rect x="0" y="0" width="24" height="24" fill={`url(#${id("shade")})`} />
        <rect x="0" y="0" width="24" height="24" fill={`url(#${id("hl")})`} />
      </g>
      <NavMarks glyph={glyph} />
    </svg>
  );
}

/* ---------- Glossy surfaces ---------- */

/** Gloss band (ZokyGlossPainter.glossPath): white fading down, lower edge curving up to the right. */
export function ZokyGlossBand({ className, opacity }: { className?: string; opacity: number }) {
  const uid = useId().replace(/:/g, "");
  return (
    <svg className={`zk-gloss ${className ?? ""}`} viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true" focusable="false">
      <defs>
        <linearGradient id={`zkgl-${uid}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity={opacity} />
          <stop offset="1" stopColor="#fff" stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d="M0 100 L0 0 L100 0 L100 72 Q55 50 0 100Z" fill={`url(#zkgl-${uid})`} />
    </svg>
  );
}

/** Light waves over the Home header (ZokyHeaderWavesPainter). */
export function ZokyHeaderWaves() {
  return (
    <svg className="zk-waves" viewBox="0 0 100 100" preserveAspectRatio="none" aria-hidden="true" focusable="false">
      <path d="M52 0 C62 38 80 58 100 50 L100 0Z" fill="#fff" fillOpacity="0.10" />
      <path d="M0 58 C30 40 62 86 100 66 L100 100 L0 100Z" fill="#fff" fillOpacity="0.08" />
    </svg>
  );
}

/** White glossy round control (heart / coupon / cart). The visible disc sits inside a larger tap target. */
export function ZokyGlossyIconButton({
  label,
  onClick,
  children,
  size = "lg",
  badge,
}: {
  label: string;
  onClick: () => void;
  children: ReactNode;
  size?: "lg" | "sm";
  badge?: number;
}) {
  return (
    <button className={`zk-glossy-btn is-${size}`} type="button" aria-label={label} onClick={onClick}>
      <span className="zk-glossy-disc">{children}</span>
      {badge ? <i className="zk-count-badge" aria-hidden="true">{badge > 99 ? "99+" : badge}</i> : null}
    </button>
  );
}

/* ---------- Home ---------- */

export function ZokyHomeHeader({ actions }: { actions: ReactNode }) {
  return (
    <header className="zk-home-header">
      <ZokyGlossBand className="zk-gloss--header" opacity={0.07} />
      <ZokyHeaderWaves />
      <div className="zk-col zk-home-header-row">
        <h1 className="zk-wordmark">
          <Image src="/icons/zoky/wordmark-white-v1.png" width={600} height={331} alt="ZOKY" priority />
        </h1>
        <div className="zk-home-header-actions">{actions}</div>
      </div>
      <span className="zk-home-sheet" aria-hidden="true" />
    </header>
  );
}

export function ZokyFoodHeroCard({ onOpen }: { onOpen: () => void }) {
  return (
    <div className="zk-col zk-hero-wrap">
      {/* The whole card is a pointer target; keyboard/screen readers get the single button below. */}
      <div className="zk-hero" onClick={onOpen}>
        <ZokyGlossBand className="zk-gloss--hero" opacity={0.35} />
        <div className="zk-hero-top">
          <div className="zk-hero-copy">
            <span className="zk-hero-pill"><Zoky3DIcon glyph="sparkle" size={16} /><span lang="en">FOOD DELIVERY</span></span>
            <h2 className="zk-hero-title" aria-label="อยากกินอะไรวันนี้?">
              <span aria-hidden="true">อยากกินอะไร<br />วันนี้?</span>
            </h2>
            <p className="zk-hero-subtitle"><span>ของอร่อยใกล้คุณ</span>{" "}<span>เริ่มที่นี่</span></p>
          </div>
          <span className="zk-hero-disc" aria-hidden="true">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/icons/zoky/bento-v1.svg" alt="" width={112} height={112} decoding="async" />
          </span>
        </div>
        <button className="zk-hero-search" type="button" onClick={(event) => { event.stopPropagation(); onOpen(); }}>
          <span>ค้นหาของอร่อย</span>
          <Zoky3DIcon glyph="arrowRight" size={32} />
        </button>
      </div>
    </div>
  );
}

export function ZokySectionHeader({ title, onAll }: { title: string; onAll?: () => void }) {
  return (
    <div className="zk-section-head">
      <h2>{title}</h2>
      {onAll ? (
        <button type="button" onClick={onAll} aria-label={`ดูทั้งหมด ${title}`}>
          ดูทั้งหมด
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false"><path d="m9 18 6-6-6-6" /></svg>
        </button>
      ) : null}
    </div>
  );
}

/* ---------- Bottom nav ---------- */

export type ZokyNavItem<K extends string> = { key: K; label: string; glyph: ZokyNavGlyph; badge?: number; badgeLabel?: string };

export function ZokyBottomNav<K extends string>({
  items,
  current,
  onSelect,
}: {
  items: Array<ZokyNavItem<K>>;
  current: K | null;
  onSelect: (key: K) => void;
}) {
  const index = Math.max(0, items.findIndex((item) => item.key === current));
  return (
    <nav className="zk-nav" aria-label="เมนูหลัก" style={{ "--zk-nav-index": index, "--zk-nav-count": items.length } as React.CSSProperties}>
      <span className={`zk-nav-highlight${current == null ? " is-hidden" : ""}`} aria-hidden="true" />
      {items.map((item) => {
        const selected = item.key === current;
        const count = item.badge ? (item.badge > 99 ? "99+" : String(item.badge)) : null;
        return (
          <button
            key={item.key}
            type="button"
            className={selected ? "is-active" : ""}
            aria-current={selected ? "page" : undefined}
            onClick={() => onSelect(item.key)}
          >
            <span className="zk-nav-icon-wrap">
              <ZokyNavIcon key={selected ? "on" : "off"} glyph={item.glyph} selected={selected} />
              {count ? <i className="zk-nav-badge" aria-label={item.badgeLabel}>{count}</i> : null}
            </span>
            <small>{item.label}</small>
          </button>
        );
      })}
    </nav>
  );
}

/* ---------- Food ---------- */

/** Floating cart (ZokyFoodCartButton): a circle when empty, a pill with count and total otherwise. */
export function ZokyFoodCartButton({
  count,
  totalLabel,
  totalSpoken,
  onClick,
}: {
  count: number;
  totalLabel: string;
  totalSpoken: string;
  onClick: () => void;
}) {
  const shown = count > 99 ? "99+" : String(count);
  return (
    <>
      <button
        className={`zk-cart-fab${count ? " has-items" : ""}`}
        type="button"
        onClick={onClick}
        aria-label={count ? `ตะกร้า ${count} รายการ รวม ${totalSpoken} บาท` : "ตะกร้า"}
      >
        <ShoppingBag size={26} strokeWidth={2} aria-hidden="true" />
        {count ? <span className="zk-cart-fab-label">{shown} · {totalLabel}</span> : null}
      </button>
      <span className="zk-sr-only" aria-live="polite">{count ? `ตะกร้า ${count} รายการ รวม ${totalSpoken} บาท` : ""}</span>
    </>
  );
}

/* ---------- Delivery scooter (storefront distance, Founder 2026-10-22) ---------- */

export function ZokyScooterIcon({ size = 22 }: { size?: number }) {
  const uid = useId().replace(/:/g, "");
  const body = `zk-scooter-body-${uid}`;
  const box = `zk-scooter-box-${uid}`;
  return (
    <svg className="zk-scooter" width={size} height={(size * 3) / 4} viewBox="0 0 32 24" aria-hidden="true" focusable="false">
      <defs>
        <linearGradient id={body} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#FF6BAA" /><stop offset="1" stopColor="#E5135D" /></linearGradient>
        <linearGradient id={box} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="#FFD45C" /><stop offset="1" stopColor="#F59E0B" /></linearGradient>
      </defs>
      <rect x="1.6" y="3.2" width="9.2" height="7.6" rx="2" fill={`url(#${box})`} />
      <path d="M1.6 5.6h9.2" stroke="#B45309" strokeWidth="1" opacity=".35" />
      <rect x="9.2" y="9.4" width="7.4" height="2.4" rx="1.2" fill="#3A2F38" />
      <path d="M3 12.4h13.6c1.4 0 2.1-1.2 2.7-3l1-3h2.4l1 7.4c.2 1.8-1.2 3.4-3 3.4H7.6A4.6 4.6 0 0 1 3 12.6z" fill={`url(#${body})`} />
      <path d="M5.4 13.6h9.4" stroke="#fff" strokeWidth="1.1" strokeLinecap="round" opacity=".55" />
      <path d="M22.6 13.2 24.9 18.4" stroke="#9E0E3E" strokeWidth="2" strokeLinecap="round" />
      <path d="M21.5 6.4 22.4 2.6" stroke="#3A2F38" strokeWidth="1.6" strokeLinecap="round" />
      <path d="M20.3 2.6h4.2" stroke="#3A2F38" strokeWidth="1.8" strokeLinecap="round" />
      <ellipse cx="23.3" cy="7.6" rx="1.2" ry="1" fill="#FFF3C4" />
      <circle cx="8.2" cy="18.6" r="3.3" fill="#2B2B33" /><circle cx="8.2" cy="18.6" r="1.3" fill="#FF8DBE" />
      <circle cx="24.9" cy="18.6" r="3.3" fill="#2B2B33" /><circle cx="24.9" cy="18.6" r="1.3" fill="#FF8DBE" />
    </svg>
  );
}

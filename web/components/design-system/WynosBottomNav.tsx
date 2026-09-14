import Link from "next/link";
import type { ReactNode } from "react";

import styles from "./WynosBottomNav.module.css";

export type WynosBottomNavItem = {
  key: string;
  href: string;
  ariaLabel: string;
  icon: ReactNode;
  active?: boolean;
  badge?: string | null;
  variant?: "default" | "cta";
};

/**
 * WynosBottomNav — canonical 5-slot bottom navigation with a circular center
 * CTA (WYN-159 design system, `.bottom-nav`/`.nav-btn`/`.post-cta` in the
 * reference). Icon-only, no visible text labels — matches
 * `wynos-home-v2.html` exactly (Founder-confirmed 2026-09-14, see
 * `.wyn/company/DECISIONS.md`). `aria-label` still carries the accessible
 * name per slot. Presentation only: destinations, hrefs, active-state and
 * badge logic all stay owned by `components/bottom-navigation.tsx`.
 */
export function WynosBottomNav({ items }: { items: WynosBottomNavItem[] }) {
  return (
    <nav className={styles.nav} aria-label="เมนูหลัก">
      {items.map((item) =>
        item.variant === "cta" ? (
          <Link key={item.key} className={`${styles.item} ${styles.ctaItem}`} href={item.href} aria-label={item.ariaLabel}>
            <span className={styles.ctaCircle}>{item.icon}</span>
          </Link>
        ) : (
          <Link
            key={item.key}
            className={`${styles.item} ${item.active ? styles.active : ""}`}
            href={item.href}
            aria-label={item.ariaLabel}
          >
            <span className={styles.glyph}>
              {item.icon}
              {item.badge ? (
                <span className={styles.badge} aria-hidden="true">
                  {item.badge}
                </span>
              ) : null}
            </span>
          </Link>
        ),
      )}
    </nav>
  );
}

"use client";

import type { ButtonHTMLAttributes, ReactNode } from "react";

import styles from "./WynosIconButton.module.css";

/**
 * WynosIconButton — canonical ghost icon tap target (WYN-159 design system,
 * `.icon-btn` in the reference). Visually a 22px icon; hit area is padded to
 * the 44x44px accessibility minimum via the button box, not the icon scale.
 */
export function WynosIconButton({
  icon,
  tone = "primary",
  badge,
  className = "",
  ...buttonProps
}: {
  icon: ReactNode;
  /** primary = --text-primary (e.g. Home leading menu icon); secondary = --text-secondary (reference's header-actions icons). */
  tone?: "primary" | "secondary";
  /** Small red count/dot badge, e.g. unread notifications — the one other place color is allowed besides Like. */
  badge?: string | null;
} & ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      type="button"
      className={`${styles.button} ${tone === "secondary" ? styles.secondary : ""} ${className}`.trim()}
      {...buttonProps}
    >
      {icon}
      {badge ? (
        <span className={styles.badge} aria-hidden="true">
          {badge}
        </span>
      ) : null}
    </button>
  );
}

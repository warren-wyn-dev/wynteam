"use client";

import type { ButtonHTMLAttributes } from "react";

import styles from "./WynosPillButton.module.css";

/**
 * WynosPillButton — outlined pill button (WYN-159 design system, `.follow-btn`
 * in the reference). Used for Follow / filter-chip style actions.
 */
export function WynosPillButton({
  muted = false,
  className = "",
  children,
  ...buttonProps
}: {
  muted?: boolean;
  children: React.ReactNode;
} & ButtonHTMLAttributes<HTMLButtonElement>) {
  return (
    <button
      type="button"
      className={`${styles.pill} ${muted ? styles.muted : ""} ${className}`.trim()}
      {...buttonProps}
    >
      {children}
    </button>
  );
}

"use client";

import styles from "./WynosTabs.module.css";

export type WynosTabItem<Key extends string = string> = { key: Key; label: string };

/**
 * WynosTabs — canonical horizontal tab row (WYN-159 design system,
 * `.tabs`/`.tab` in the reference): 14px labels, 18px gap, active tab gets a
 * 2px `--text-primary` underline directly under its own label (not a fixed-
 * width indicator). Horizontally scrollable only if tabs overflow.
 */
export function WynosTabs<Key extends string>({
  items,
  activeKey,
  onSelect,
  ariaLabel,
}: {
  items: WynosTabItem<Key>[];
  activeKey: Key;
  onSelect: (key: Key) => void;
  ariaLabel: string;
}) {
  return (
    <div className={styles.tabs} role="tablist" aria-label={ariaLabel}>
      {items.map((item) => (
        <button
          type="button"
          role="tab"
          aria-selected={activeKey === item.key}
          className={`${styles.tab} ${activeKey === item.key ? styles.active : ""}`}
          onClick={() => onSelect(item.key)}
          key={item.key}
        >
          {item.label}
        </button>
      ))}
    </div>
  );
}

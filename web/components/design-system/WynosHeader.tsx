import type { ReactNode } from "react";

import styles from "./WynosHeader.module.css";

/**
 * WynosHeader — canonical top-bar row (WYN-159 design system, `.header-row`
 * in the reference): leading control, centered brand/title, trailing
 * actions. The bordered container (padding, `border-bottom`) is supplied by
 * the composing screen so screens that pair this row with `WynosTabs`
 * (e.g. Home) can wrap both in one bordered block, matching the reference's
 * `.header` structure exactly.
 */
export function WynosHeader({
  leading,
  center,
  trailing,
}: {
  leading?: ReactNode;
  center?: ReactNode;
  trailing?: ReactNode;
}) {
  return (
    <div className={styles.row}>
      {leading}
      <div className={styles.center}>{center}</div>
      <div className={styles.trailing}>{trailing}</div>
    </div>
  );
}

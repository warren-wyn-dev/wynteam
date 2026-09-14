import type { ReactNode } from "react";

import styles from "./WynosAppShell.module.css";

/**
 * WynosAppShell — canonical page frame (WYN-159 design system, `.app` in the
 * reference): background + centered max-width column that every route's
 * content mounts into.
 *
 * Scope note (this batch): the existing `AppChrome`/`.route-app`/`.route-main`
 * shell (`components/phase3-ui.tsx`) already provides this same frame for
 * every route today, including notification-badge wiring and bottom-nav
 * mounting that ~20 not-yet-migrated screens depend on. Replacing that
 * shared shell outright is out of scope for a Home-only batch. `WynosAppShell`
 * is built here per the design-system doc and used to wrap Home's own
 * content (header block + feed) inside the existing `AppChrome`; full
 * app-wide adoption (retiring `AppChrome` in favor of this component) is
 * deferred to the final WYN-159 cleanup batch once every screen has moved
 * to the new primitives.
 */
export function WynosAppShell({ children }: { children: ReactNode }) {
  return <div className={styles.shell}>{children}</div>;
}

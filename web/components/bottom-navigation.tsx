import Link from "next/link";

/**
 * Root bottom navigation, shared by every top-level route via
 * <AppChrome>. Matches wynos_founder_bottom_navigation.dart /
 * wynos_founder_metrics.dart exactly: 80px content height, 28px
 * Material-rounded glyphs, a 56px center Post action, 11.5px labels
 * (600 selected / 400 unselected). Styled by app/bottom-nav.css, the
 * single canonical stylesheet for this component (see
 * docs/wyn-158-visual-parity-audit.md).
 */

type MaterialNavKind = "home" | "search" | "notifications" | "profile" | "add";

export function MaterialNavGlyph({ kind, selected = false }: { kind: MaterialNavKind; selected?: boolean }) {
  if (kind === "home") {
    return selected ? (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8h5Z" /></svg>
    ) : (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 5.69 17 10.19V18h-3v-6h-4v6H7v-7.81l5-4.5M12 3 2 12h3v8h7v-6h0v6h7v-8l-7-9Z" /></svg>
    );
  }
  if (kind === "search") {
    return <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M9.5 3a6.5 6.5 0 1 0 4.09 11.55L19 19.96 20.41 18.55 15 13.14A6.5 6.5 0 0 0 9.5 3Zm0 2A4.5 4.5 0 1 1 5 9.5 4.505 4.505 0 0 1 9.5 5Z" /></svg>;
  }
  if (kind === "notifications") {
    return selected ? (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 22a2 2 0 0 0 2-2h-4a2 2 0 0 0 2 2Zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4a1.5 1.5 0 0 0-3 0v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2Z" /></svg>
    ) : (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 22a2 2 0 0 0 2-2h-4a2 2 0 0 0 2 2Zm6-6v-5c0-3.07-1.64-5.64-4.5-6.32V4a1.5 1.5 0 0 0-3 0v.68C7.63 5.36 6 7.92 6 11v5l-2 2v1h16v-1l-2-2Zm-2 .5H8V11c0-2.48 1.51-4.5 4-4.5s4 2.02 4 4.5v5.5Z" /></svg>
    );
  }
  if (kind === "profile") {
    return selected ? (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4Z" /></svg>
    ) : (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm0-6a2 2 0 1 1 0 4 2 2 0 0 1 0-4Zm0 8c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4Zm-5.33 4c.73-1.02 3.3-2 5.33-2s4.6.98 5.33 2H6.67Z" /></svg>
    );
  }
  return <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" /></svg>;
}

export function BottomNavigation({
  profileHref,
  isActive,
  notificationLabel,
  notificationBadge,
}: {
  profileHref: string;
  isActive: (href: string) => boolean;
  notificationLabel: string;
  notificationBadge: string | null;
}) {
  return (
    <nav className="route-bottom-nav" aria-label="เมนูหลัก">
      <Link className={`route-nav-link ${isActive("/") ? "active" : ""}`} href="/" aria-label="หน้าหลัก">
        <MaterialNavGlyph kind="home" selected={isActive("/")} />
        <span>หน้าหลัก</span>
      </Link>
      <Link className={`route-nav-link ${isActive("/search") ? "active" : ""}`} href="/search" aria-label="ค้นหา">
        <MaterialNavGlyph kind="search" />
        <span>ค้นหา</span>
      </Link>
      <Link className="route-nav-link route-create-destination" href="/?compose=1" aria-label="สร้างโพสต์ใหม่">
        <span className="route-create-button"><MaterialNavGlyph kind="add" /></span>
        <span>โพสต์</span>
      </Link>
      <Link className={`route-nav-link ${isActive("/notifications") ? "active" : ""}`} href="/notifications" aria-label={notificationLabel}>
        <span className="route-nav-icon-wrap">
          <MaterialNavGlyph kind="notifications" selected={isActive("/notifications")} />
          {notificationBadge ? <span className="route-nav-badge" aria-hidden="true">{notificationBadge}</span> : null}
        </span>
        <span>การแจ้งเตือน</span>
      </Link>
      <Link className={`route-nav-link ${isActive(profileHref) ? "active" : ""}`} href={profileHref} aria-label="โปรไฟล์">
        <MaterialNavGlyph kind="profile" selected={isActive(profileHref)} />
        <span>โปรไฟล์</span>
      </Link>
    </nav>
  );
}

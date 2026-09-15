import Link from "next/link";

/**
 * Root bottom navigation shared by the top-level social routes.
 *
 * The five destinations intentionally use the same column width, glyph size,
 * label treatment, and inactive colour. The Post action is no longer a raised
 * floating button; it is visually equal to Home, Club, Chat, and Profile.
 */
type MaterialNavKind = "home" | "club" | "chat" | "profile" | "add";

export function MaterialNavGlyph({ kind, selected = false }: { kind: MaterialNavKind; selected?: boolean }) {
  if (kind === "home") {
    return selected ? (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8h5Z" /></svg>
    ) : (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 5.69 17 10.19V18h-3v-6h-4v6H7v-7.81l5-4.5M12 3 2 12h3v8h7v-6h0v6h7v-8l-7-9Z" /></svg>
    );
  }
  if (kind === "club") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true">
        <path fill="currentColor" d="M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm0-2a2 2 0 1 1 0-4 2 2 0 0 1 0 4Zm7-1a3 3 0 1 0 0-6 3 3 0 0 0 0 6Zm0-2a1 1 0 1 1 0-2 1 1 0 0 1 0 2ZM9 13c-3.34 0-7 1.67-7 5v2h14v-2c0-3.33-3.66-5-7-5Zm-4.78 5c.45-1.54 2.84-3 4.78-3 1.95 0 4.33 1.46 4.78 3H4.22ZM16.5 10c-1 0-1.96.18-2.78.5.7.5 1.31 1.12 1.78 1.84.33-.21.7-.34 1-.34 1.35 0 3.19 1.01 3.5 2h-2.43c.24.62.39 1.29.42 2H22v-2c0-2.67-2.88-4-5.5-4Z" />
      </svg>
    );
  }
  if (kind === "chat") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true">
        <path fill="currentColor" d="M4 4h16v11H8.83L4 19.83V4Zm2 2v9l2-2h10V6H6Z" />
      </svg>
    );
  }
  if (kind === "profile") {
    return selected ? (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4Z" /></svg>
    ) : (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path fill="currentColor" d="M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8Zm0-6a2 2 0 1 1 0 4 2 2 0 0 1 0-4Zm0 8c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4Zm-5.33 4c.73-1.02 3.3-2 5.33-2s4.6.98 5.33 2H6.67Z" /></svg>
    );
  }
  return <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true"><path d="M12 5v14M5 12h14" fill="none" stroke="currentColor" strokeWidth="2.1" strokeLinecap="round" /></svg>;
}

export function BottomNavigation({
  profileHref,
  isActive,
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
      <Link className={`route-nav-link ${isActive("/clubs") ? "active" : ""}`} href="/clubs" aria-label="คลับ">
        <MaterialNavGlyph kind="club" selected={isActive("/clubs")} />
        <span>คลับ</span>
      </Link>
      <Link className="route-nav-link" href="/?compose=1" aria-label="สร้างโพสต์ใหม่">
        <MaterialNavGlyph kind="add" />
        <span>โพสต์</span>
      </Link>
      <Link className={`route-nav-link ${isActive("/chat") ? "active" : ""}`} href="/chat" aria-label="แชท">
        <MaterialNavGlyph kind="chat" selected={isActive("/chat")} />
        <span>แชท</span>
      </Link>
      <Link className={`route-nav-link ${isActive(profileHref) ? "active" : ""}`} href={profileHref} aria-label="โปรไฟล์">
        <MaterialNavGlyph kind="profile" selected={isActive(profileHref)} />
        <span>โปรไฟล์</span>
      </Link>
    </nav>
  );
}

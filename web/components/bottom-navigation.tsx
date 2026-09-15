import Link from "next/link";

/**
 * Root bottom navigation shared by the top-level social routes.
 *
 * The five destinations use one consistent outline icon system and equal
 * sizing. Selection is communicated by the soft background tile and darker
 * label/icon rather than by enlarging or filling a destination.
 */
type MaterialNavKind = "home" | "club" | "chat" | "profile" | "add";

export function MaterialNavGlyph({ kind, selected = false }: { kind: MaterialNavKind; selected?: boolean }) {
  const strokeWidth = selected ? 2.05 : 1.9;

  if (kind === "home") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <path d="M3.5 10.5 12 3l8.5 7.5V20h-6v-6h-5v6h-6v-9.5Z" />
      </svg>
    );
  }

  if (kind === "club") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <circle cx="9" cy="8" r="3" />
        <circle cx="17" cy="7" r="2.25" />
        <path d="M3.5 19c.35-3.4 2.45-5.2 5.5-5.2s5.15 1.8 5.5 5.2H3.5Z" />
        <path d="M15 12.5c.6-.3 1.3-.45 2.05-.45 2.25 0 3.9 1.25 4.25 3.55h-4.1" />
      </svg>
    );
  }

  if (kind === "chat") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <path d="M5.5 4.5h13A1.5 1.5 0 0 1 20 6v9a1.5 1.5 0 0 1-1.5 1.5H9L4 20v-4.5A1.5 1.5 0 0 1 4 15V6a1.5 1.5 0 0 1 1.5-1.5Z" />
      </svg>
    );
  }

  if (kind === "profile") {
    return (
      <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
        <circle cx="12" cy="7.5" r="3.5" />
        <path d="M5 20c.45-4.05 2.85-6 7-6s6.55 1.95 7 6H5Z" />
      </svg>
    );
  }

  return (
    <svg className="route-nav-glyph" viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
      <rect x="4" y="4" width="16" height="16" rx="4" />
      <path d="M12 8v8M8 12h8" />
    </svg>
  );
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

"use client";

import Link from "next/link";
import type { MouseEvent } from "react";

import { triggerRouteRefresh } from "@/components/route-refresh-runtime";

/**
 * Root bottom navigation shared by the top-level social routes.
 * The five existing destinations stay unchanged; the visual treatment is the
 * approved lightweight app dock with no selected background tile.
 */
type MaterialNavKind = "home" | "club" | "chat" | "profile" | "compose";

export function MaterialNavGlyph({ kind, selected = false }: { kind: MaterialNavKind; selected?: boolean }) {
  const common = {
    className: "route-nav-glyph",
    "aria-hidden": true,
    fill: "currentColor",
    fillRule: "evenodd" as const,
    clipRule: "evenodd" as const,
    "data-selected": selected ? "true" : undefined,
  };

  if (kind === "home") {
    return (
      <svg {...common} viewBox="0 0 122 117">
        <path d="M 5 45 L 3 49 L 3 51 L 2 52 L 2 99 L 3 100 L 3 102 L 4 104 L 9 110 L 15 113 L 18 113 L 19 114 L 35 114 L 36 113 L 39 113 L 43 111 L 46 108 L 48 104 L 48 85 L 49 84 L 49 81 L 54 76 L 56 75 L 65 75 L 67 76 L 71 80 L 72 82 L 72 101 L 73 102 L 73 105 L 74 107 L 79 112 L 81 113 L 84 113 L 85 114 L 101 114 L 102 113 L 106 113 L 110 111 L 112 109 L 113 109 L 117 104 L 118 102 L 118 100 L 119 99 L 119 53 L 118 52 L 118 50 L 116 46 L 114 44 L 114 43 L 111 40 L 110 40 L 101 31 L 100 31 L 92 23 L 91 23 L 72 5 L 66 2 L 57 2 L 51 5 L 50 5 L 42 13 L 41 13 L 32 22 L 31 22 L 22 31 L 21 31 L 12 40 L 11 40 L 8 43 L 8 44 Z M 60 8 L 64 9 L 69 13 L 70 13 L 77 20 L 78 20 L 87 29 L 88 29 L 97 38 L 98 38 L 107 47 L 108 47 L 111 50 L 112 53 L 112 98 L 109 103 L 104 106 L 85 106 L 81 104 L 79 101 L 79 82 L 78 81 L 78 78 L 73 72 L 70 70 L 68 70 L 67 69 L 55 69 L 54 70 L 51 70 L 46 74 L 44 78 L 44 101 L 41 104 L 37 106 L 18 106 L 13 103 L 10 98 L 10 53 L 11 50 L 14 47 L 15 47 L 24 38 L 25 38 L 34 29 L 35 29 L 44 20 L 45 20 L 52 13 L 53 13 L 57 9 Z" />
      </svg>
    );
  }

  if (kind === "club") {
    return (
      <svg {...common} viewBox="0 0 134 107">
        <path d="M 87 70 L 87 72 L 90 75 L 93 75 L 94 74 L 98 74 L 99 73 L 101 73 L 102 74 L 106 74 L 107 75 L 109 75 L 113 77 L 121 85 L 122 87 L 122 89 L 123 90 L 123 93 L 124 94 L 124 102 L 126 104 L 128 104 L 131 101 L 131 94 L 130 93 L 130 88 L 129 87 L 129 85 L 127 81 L 125 79 L 125 78 L 120 73 L 119 73 L 117 71 L 113 69 L 111 69 L 107 67 L 93 67 Z M 2 95 L 2 101 L 5 104 L 7 104 L 9 102 L 9 97 L 10 96 L 10 91 L 11 90 L 11 87 L 13 83 L 15 81 L 15 80 L 22 73 L 23 73 L 25 71 L 31 68 L 33 68 L 34 67 L 37 67 L 38 66 L 54 66 L 55 67 L 59 67 L 60 68 L 62 68 L 66 70 L 68 72 L 69 72 L 77 80 L 79 84 L 80 84 L 81 88 L 82 88 L 82 92 L 83 93 L 83 101 L 85 104 L 88 104 L 90 101 L 90 94 L 89 93 L 89 88 L 88 87 L 88 84 L 86 80 L 84 78 L 84 77 L 78 71 L 77 71 L 75 69 L 71 67 L 69 67 L 65 65 L 61 65 L 60 64 L 33 64 L 32 65 L 28 65 L 27 66 L 24 66 L 23 67 L 21 67 L 19 68 L 18 68 L 14 70 L 8 76 L 8 77 L 5 80 L 3 84 L 3 87 L 2 88 Z M 101 29 L 98 30 L 97 31 L 94 31 L 90 35 L 89 38 L 88 38 L 88 48 L 89 49 L 89 52 L 92 55 L 93 55 L 95 57 L 98 58 L 99 59 L 108 59 L 109 58 L 112 58 L 116 54 L 117 51 L 118 51 L 118 39 L 117 38 L 117 35 L 113 31 L 110 31 L 109 30 Z M 103 36 L 107 36 L 111 40 L 111 47 L 110 48 L 110 51 L 107 53 L 100 53 L 96 49 L 96 40 L 100 36 Z M 47 2 L 42 4 L 40 4 L 35 9 L 35 10 L 32 13 L 31 17 L 30 17 L 30 29 L 31 30 L 31 34 L 33 36 L 33 38 L 39 44 L 41 44 L 43 46 L 47 47 L 48 48 L 58 48 L 59 47 L 63 47 L 69 43 L 72 39 L 72 38 L 75 34 L 75 31 L 76 30 L 76 18 L 75 17 L 75 14 L 73 11 L 73 10 L 68 5 L 66 5 L 63 3 L 59 3 L 58 2 Z M 50 9 L 58 9 L 63 11 L 68 16 L 69 19 L 69 29 L 68 30 L 68 33 L 64 38 L 61 40 L 58 41 L 50 41 L 46 39 L 44 39 L 39 34 L 37 30 L 37 19 L 38 18 L 38 15 L 42 11 L 46 9 Z" />
      </svg>
    );
  }

  if (kind === "compose") {
    return (
      <svg {...common} viewBox="0 0 113 113">
        <path d="M 105 13 L 101 9 L 97 7 L 91 7 L 90 8 L 88 8 L 37 59 L 36 61 L 36 64 L 35 65 L 35 69 L 34 70 L 34 77 L 35 79 L 39 81 L 41 81 L 42 80 L 45 80 L 46 79 L 49 79 L 50 78 L 53 78 L 55 77 L 104 28 L 107 22 L 107 18 L 106 17 L 106 15 Z M 95 14 L 99 18 L 99 22 L 49 72 L 45 72 L 44 73 L 42 73 L 41 71 L 42 70 L 42 65 L 43 63 L 91 15 L 93 14 Z M 14 7 L 7 14 L 3 22 L 3 25 L 2 26 L 2 86 L 3 87 L 4 92 L 7 98 L 14 105 L 20 108 L 22 108 L 23 109 L 27 109 L 28 110 L 83 110 L 84 109 L 89 109 L 90 108 L 92 108 L 98 105 L 105 98 L 108 92 L 108 89 L 109 88 L 109 63 L 108 61 L 106 60 L 103 61 L 102 64 L 102 87 L 101 88 L 101 91 L 98 96 L 94 100 L 89 103 L 85 103 L 84 104 L 27 104 L 26 103 L 22 103 L 17 100 L 13 96 L 10 91 L 10 26 L 11 25 L 11 22 L 14 18 L 18 14 L 22 11 L 26 11 L 27 10 L 66 10 L 68 9 L 69 7 L 68 4 L 65 2 L 25 2 L 24 3 L 20 3 L 19 4 L 17 4 Z" />
      </svg>
    );
  }

  if (kind === "chat") {
    return (
      <svg {...common} viewBox="0 0 125 119">
        <path d="M 103 15 L 102 15 L 96 10 L 86 5 L 84 5 L 80 3 L 76 3 L 75 2 L 54 2 L 53 3 L 49 3 L 48 4 L 45 4 L 44 5 L 42 5 L 30 11 L 23 17 L 22 17 L 17 22 L 17 23 L 11 30 L 6 40 L 6 42 L 4 46 L 4 49 L 3 50 L 3 57 L 2 58 L 2 65 L 3 66 L 3 71 L 4 72 L 4 75 L 5 76 L 5 78 L 6 79 L 6 81 L 8 85 L 10 87 L 10 88 L 13 92 L 13 97 L 12 98 L 12 102 L 11 103 L 11 107 L 10 108 L 10 111 L 13 115 L 15 116 L 20 116 L 21 115 L 24 115 L 25 114 L 27 114 L 28 113 L 30 113 L 34 111 L 37 111 L 38 110 L 44 113 L 47 113 L 48 114 L 53 114 L 54 115 L 75 115 L 76 114 L 80 114 L 81 113 L 84 113 L 85 112 L 88 112 L 89 111 L 92 111 L 93 110 L 95 110 L 96 109 L 98 109 L 99 108 L 101 108 L 102 107 L 104 107 L 105 106 L 107 106 L 108 105 L 109 105 L 115 99 L 115 98 L 118 95 L 120 91 L 120 89 L 121 88 L 121 85 L 122 84 L 122 79 L 123 78 L 123 58 L 122 57 L 122 52 L 121 51 L 121 48 L 120 47 L 120 45 L 118 41 L 116 39 L 116 38 L 111 32 L 110 32 L 105 26 L 104 26 L 101 23 Z M 63 10 L 73 10 L 74 11 L 80 11 L 81 12 L 85 12 L 86 13 L 89 13 L 90 14 L 92 14 L 94 16 L 96 16 L 103 23 L 104 23 L 109 28 L 109 29 L 113 33 L 113 34 L 116 38 L 117 41 L 118 41 L 118 45 L 119 46 L 119 50 L 120 51 L 120 70 L 119 71 L 119 76 L 118 77 L 118 80 L 117 81 L 117 83 L 115 87 L 113 89 L 113 90 L 109 94 L 108 94 L 103 99 L 102 99 L 98 102 L 96 102 L 93 104 L 90 104 L 89 105 L 85 105 L 84 106 L 80 106 L 79 107 L 75 107 L 74 108 L 53 108 L 52 107 L 48 107 L 47 106 L 43 106 L 42 105 L 38 105 L 37 104 L 31 104 L 29 105 L 28 105 L 23 108 L 19 109 L 20 104 L 21 102 L 21 95 L 20 94 L 20 91 L 18 89 L 18 87 L 16 85 L 16 83 L 14 79 L 13 75 L 12 75 L 12 69 L 11 68 L 11 58 L 12 57 L 12 50 L 13 49 L 13 46 L 14 45 L 14 43 L 16 39 L 18 37 L 18 36 L 23 30 L 24 30 L 30 24 L 31 24 L 36 20 L 39 19 L 39 18 L 44 16 L 47 16 L 48 15 L 52 15 L 53 14 L 58 14 L 59 13 L 63 13 Z M 99 84 L 89 84 L 89 96 L 99 96 L 99 84 Z M 76 84 L 66 84 L 66 96 L 76 96 L 76 84 Z M 53 84 L 43 84 L 43 96 L 53 96 L 53 84 Z" />
      </svg>
    );
  }

  return (
    <svg {...common} viewBox="0 0 111 117">
      <path d="M 2 108 L 3 109 L 2 110 L 3 111 L 3 113 L 4 114 L 8 114 L 10 112 L 10 103 L 11 102 L 11 99 L 16 89 L 26 79 L 27 79 L 29 77 L 33 75 L 35 75 L 38 73 L 41 73 L 42 72 L 46 72 L 47 71 L 64 71 L 65 72 L 69 72 L 70 73 L 73 73 L 76 75 L 78 75 L 82 77 L 88 82 L 89 82 L 92 85 L 92 86 L 95 89 L 95 90 L 98 94 L 98 96 L 100 100 L 100 106 L 101 107 L 101 113 L 103 114 L 106 114 L 108 112 L 108 102 L 107 101 L 106 94 L 104 91 L 104 89 L 103 87 L 101 85 L 101 84 L 96 79 L 96 78 L 95 78 L 90 73 L 87 72 L 83 69 L 80 68 L 79 67 L 75 67 L 74 66 L 69 66 L 68 65 L 43 65 L 42 66 L 37 66 L 36 67 L 33 67 L 32 68 L 29 68 L 25 70 L 23 70 L 20 72 L 18 72 L 14 76 L 13 76 L 8 81 L 8 82 L 5 85 L 4 88 L 3 88 L 3 91 L 2 92 Z M 52 2 L 48 3 L 47 4 L 44 4 L 40 8 L 39 11 L 38 11 L 38 15 L 37 16 L 37 25 L 38 26 L 38 30 L 39 31 L 39 34 L 43 38 L 43 39 L 47 42 L 50 43 L 51 44 L 61 44 L 62 43 L 65 43 L 70 38 L 70 37 L 73 34 L 74 31 L 75 31 L 75 27 L 76 26 L 76 16 L 75 15 L 75 12 L 73 9 L 73 8 L 69 4 L 66 4 L 65 3 L 62 3 L 61 2 Z M 54 9 L 61 9 L 66 11 L 69 15 L 69 18 L 70 19 L 70 25 L 69 26 L 69 30 L 65 35 L 62 37 L 53 37 L 48 34 L 46 30 L 46 27 L 45 26 L 45 18 L 46 17 L 46 14 L 49 11 Z" />
    </svg>
  );
}

export function BottomNavigation({
  profileHref,
  isActive,
  chatUnreadCount = 0,
}: {
  profileHref: string;
  isActive: (href: string) => boolean;
  chatUnreadCount?: number;
}) {
  const homeActive = isActive("/");
  const clubActive = isActive("/clubs");
  const chatActive = isActive("/chat");
  const profileActive = isActive(profileHref);
  // A bottom-dock visit is the root profile; content links keep back navigation.
  const profileTabHref = `${profileHref}?from=tab`;

  const handleActiveTabTap = (active: boolean, path: string) => (event: MouseEvent<HTMLAnchorElement>) => {
    if (!active) return;
    if (window.location.pathname !== path || window.location.search || window.location.hash) return;
    event.preventDefault();
    if (window.scrollY <= 2) triggerRouteRefresh();
    else window.scrollTo({ top: 0, behavior: "smooth" });
  };
  const handleHomeClick = handleActiveTabTap(homeActive, "/");
  const handleProfileClick = (event: MouseEvent<HTMLAnchorElement>) => {
    // From a post/search, first switch to root Profile; re-taps refresh there.
    if (!profileActive || window.location.pathname !== profileHref ||
        window.location.search !== "?from=tab" || window.location.hash) return;
    event.preventDefault();
    if (window.scrollY <= 2) triggerRouteRefresh();
    else window.scrollTo({ top: 0, behavior: "smooth" });
  };

  return (
    <nav className="route-bottom-nav" aria-label="เมนูหลัก">
      <Link className={`route-nav-link ${homeActive ? "active" : ""}`} href="/" aria-label="หน้าหลัก" onClick={handleHomeClick}>
        <MaterialNavGlyph kind="home" selected={homeActive} />
        <span>หน้าหลัก</span>
      </Link>
      <Link className={`route-nav-link ${clubActive ? "active" : ""}`} href="/clubs" aria-label="คลับ" onClick={handleActiveTabTap(clubActive, "/clubs")}>
        <MaterialNavGlyph kind="club" selected={clubActive} />
        <span>คลับ</span>
      </Link>
      <Link
        className="route-nav-link route-nav-link--post"
        href="/?compose=1"
        aria-label="สร้างโพสต์ใหม่"
        onPointerDown={() => { void import("@/components/beta4-composer"); }}
      >
        <MaterialNavGlyph kind="compose" />
        <span>โพสต์</span>
      </Link>
      <Link className={`route-nav-link ${chatActive ? "active" : ""}`} href="/chat" aria-label={chatUnreadCount > 0 ? `แชท มี ${chatUnreadCount} บทสนทนาที่ยังไม่อ่าน` : "แชท"} onClick={handleActiveTabTap(chatActive, "/chat")}>
        <span className="route-nav-icon-wrap">
          <MaterialNavGlyph kind="chat" selected={chatActive} />
          {chatUnreadCount > 0 ? <span className="route-nav-badge" aria-hidden="true">{chatUnreadCount > 9 ? "9+" : chatUnreadCount}</span> : null}
        </span>
        <span>แชท</span>
      </Link>
      <Link className={`route-nav-link ${profileActive ? "active" : ""}`} href={profileTabHref} aria-label="โปรไฟล์" onClick={handleProfileClick}>
        <MaterialNavGlyph kind="profile" selected={profileActive} />
        <span>โปรไฟล์</span>
      </Link>
    </nav>
  );
}

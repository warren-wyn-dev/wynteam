"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Bell, ChevronLeft, Home, MessageCircle, Search, Settings, UserRound } from "lucide-react";
import { useState } from "react";

import { relativeTimeTh, type HomeFeedRow } from "@/lib/feed";
import type { ProfileRow } from "@/lib/phase3-data";

export function Avatar({
  src,
  label,
  size = 42,
}: {
  src?: string | null;
  label: string;
  size?: number;
}) {
  const [failed, setFailed] = useState(false);
  const text = label.trim().replace(/^@/, "").slice(0, 1).toUpperCase() || "W";
  if (!src || failed) {
    return <span className="route-avatar fallback" style={{ width: size, height: size }}>{text}</span>;
  }
  // eslint-disable-next-line @next/next/no-img-element
  return <img className="route-avatar" src={src} alt="" width={size} height={size} onError={() => setFailed(true)} />;
}

export function AppChrome({
  title,
  userId,
  backHref,
  actions,
  children,
}: {
  title: string;
  userId: string;
  backHref?: string;
  actions?: React.ReactNode;
  children: React.ReactNode;
}) {
  const pathname = usePathname();
  const nav = [
    { href: "/", label: "หน้าหลัก", icon: Home },
    { href: "/search", label: "ค้นหา", icon: Search },
    { href: "/chat", label: "แชท", icon: MessageCircle },
    { href: "/notifications", label: "การแจ้งเตือน", icon: Bell },
    { href: `/profile/${userId}`, label: "โปรไฟล์", icon: UserRound },
  ];
  return (
    <div className="route-app">
      <main className="route-main">
        <header className="route-header">
          <div className="route-title-row">
            {backHref ? (
              <Link className="route-icon-link" href={backHref} aria-label="ย้อนกลับ"><ChevronLeft /></Link>
            ) : <span className="route-header-slot" />}
            <h1>{title}</h1>
            <div className="route-header-actions">{actions}</div>
          </div>
        </header>
        {children}
      </main>
      <nav className="route-bottom-nav" aria-label="เมนูหลัก">
        {nav.map(({ href, label, icon: Icon }) => {
          const active = href === "/" ? pathname === "/" : pathname === href || pathname.startsWith(`${href}/`);
          return (
            <Link className={`route-nav-link ${active ? "active" : ""}`} href={href} aria-label={label} key={href}>
              <Icon size={23} strokeWidth={active ? 2.2 : 1.8} />
            </Link>
          );
        })}
      </nav>
    </div>
  );
}

export function ProfileRowView({
  profile,
  trailing,
}: {
  profile: ProfileRow;
  trailing?: React.ReactNode;
}) {
  const name = profile.display_name?.trim() || profile.username;
  return (
    <div className="route-person-row">
      <Link href={`/profile/${profile.id}`} className="route-person-main">
        <Avatar src={profile.avatar_url} label={profile.username} />
        <span className="route-person-copy">
          <strong>{name}{profile.is_verified ? <span className="route-verified" aria-label="ยืนยันแล้ว">✓</span> : null}</strong>
          <small>@{profile.username}</small>
        </span>
      </Link>
      {trailing}
    </div>
  );
}

export function DropPreviewCard({ row }: { row: HomeFeedRow }) {
  const name = row.author_display_name?.trim() || row.author_username || "WYNOS";
  return (
    <article className="route-drop-card">
      <Link href={`/profile/${row.author_id}`} className="route-drop-author">
        <Avatar src={row.author_avatar_url} label={row.author_username || name} size={36} />
        <span><strong>{name}{row.author_is_verified ? <span className="route-verified">✓</span> : null}</strong><small>@{row.author_username || "wynos"} · {relativeTimeTh(row.created_at)}</small></span>
      </Link>
      <Link href={`/drop/${row.id}`} className="route-drop-content">
        {row.caption ? <p>{row.caption}</p> : null}
        {row.image_url ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={row.image_url} alt="" loading="lazy" />
        ) : null}
      </Link>
      <div className="route-drop-metrics">
        <span>♡ {row.like_count ?? 0}</span>
        <span>◯ {row.comment_count ?? 0}</span>
        <span>↻ {row.redrop_count ?? 0}</span>
      </div>
    </article>
  );
}

export function SettingsLink() {
  return <Link className="route-icon-link" href="/settings" aria-label="ตั้งค่า"><Settings size={22} /></Link>;
}

export function EmptyState({ children }: { children: React.ReactNode }) {
  return <div className="route-empty">{children}</div>;
}

export function LoadingState() {
  return <div className="route-empty">กำลังโหลด…</div>;
}

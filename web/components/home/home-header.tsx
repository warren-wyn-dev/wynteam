/* eslint-disable @next/next/no-img-element */
import { Bell, Menu, Search } from "lucide-react";

/**
 * Home's header. Matches the supplied 07-home.html reference exactly:
 * menu on the left, wordmark centered, Search + Notifications on the
 * right — chat is reachable from the bottom nav, so it's not duplicated
 * here (Founder direction).
 */
export function HomeHeader({
  notificationBadgeCount,
  onOpenMenu,
  onOpenSearch,
  onOpenNotifications,
}: {
  notificationBadgeCount: number;
  onOpenMenu: () => void;
  onOpenSearch: () => void;
  onOpenNotifications: () => void;
}) {
  return (
    <header className="wyn-home-header">
      <button className="wyn-home-header-action" type="button" aria-label="เมนู" onClick={onOpenMenu}>
        <Menu />
      </button>
      <div className="wyn-home-wordmark">
        <img className="wyn-home-logo" src="/wynos_logo_mark.png" alt="" />
        <strong className="wyn-home-title">WYNOS</strong>
      </div>
      <div className="wyn-home-header-actions">
        <button className="wyn-home-header-action" type="button" aria-label="ค้นหา" onClick={onOpenSearch}>
          <Search />
        </button>
        <button
          className="wyn-home-header-action wyn-home-chat-action"
          type="button"
          aria-label="การแจ้งเตือน"
          onClick={onOpenNotifications}
        >
          <Bell />
          {notificationBadgeCount > 0 ? (
            <span className="wyn-home-chat-badge">{notificationBadgeCount > 9 ? "9+" : notificationBadgeCount}</span>
          ) : null}
        </button>
      </div>
    </header>
  );
}

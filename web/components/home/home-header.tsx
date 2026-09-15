import { Bell, Menu, Search } from "lucide-react";
import Image from "next/image";

/**
 * Home's header. Keeps the same functions and tap targets while refreshing the
 * visual treatment to a tighter, quieter premium layout.
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
  const actionStyle = {
    width: 44,
    height: 44,
    borderRadius: 14,
  } as const;

  return (
    <header
      className="wyn-home-header"
      style={{
        height: 52,
        padding: "0 12px",
        gridTemplateColumns: "44px minmax(0, 1fr) 88px",
        columnGap: 4,
      }}
    >
      <button
        className="wyn-home-header-action"
        style={actionStyle}
        type="button"
        aria-label="เมนู"
        onClick={onOpenMenu}
      >
        <Menu size={24} strokeWidth={2.05} />
      </button>

      <div className="wyn-home-wordmark" style={{ gap: 7 }}>
        <Image className="wyn-home-logo" style={{ width: 18, height: 18 }} src="/wynos_logo_mark.png" alt="" width={18} height={18} priority />
        <strong
          className="wyn-home-title"
          style={{ fontSize: 18, fontWeight: 700, letterSpacing: "1.6px" }}
        >
          WYNOS
        </strong>
      </div>

      <div className="wyn-home-header-actions" style={{ justifyContent: "flex-end", gap: 0 }}>
        <button
          className="wyn-home-header-action"
          style={actionStyle}
          type="button"
          aria-label="ค้นหา"
          onClick={onOpenSearch}
        >
          <Search size={23} strokeWidth={2.05} />
        </button>
        <button
          className="wyn-home-header-action wyn-home-chat-action"
          style={actionStyle}
          type="button"
          aria-label="การแจ้งเตือน"
          onClick={onOpenNotifications}
        >
          <Bell size={23} strokeWidth={2.05} />
          {notificationBadgeCount > 0 ? (
            <span className="wyn-home-chat-badge">{notificationBadgeCount > 9 ? "9+" : notificationBadgeCount}</span>
          ) : null}
        </button>
      </div>
    </header>
  );
}

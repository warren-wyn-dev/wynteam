import { Bell, Menu, Search } from "lucide-react";
import Image from "next/image";

/**
 * Home header from the approved mobile mockup: WYNOS stays centered while
 * the existing menu, search and notifications functions remain unchanged.
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
    width: 40,
    height: 40,
    borderRadius: 12,
  } as const;

  return (
    <header
      className="wyn-home-header"
      style={{
        height: 36,
        padding: "0 8px",
        gridTemplateColumns: "40px minmax(0, 1fr) 80px",
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
        <Menu size={22} strokeWidth={2.05} />
      </button>

      <div className="wyn-home-wordmark" style={{ gap: 7 }}>
        <Image
          className="wyn-home-logo"
          style={{ width: 18, height: 18 }}
          src="/wynos_logo_mark.png"
          alt=""
          width={18}
          height={18}
          priority
        />
        <strong
          className="wyn-home-title"
          style={{ fontSize: 16, fontWeight: 700, letterSpacing: "1.4px" }}
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
          <Search size={22} strokeWidth={2.05} />
        </button>
        <button
          className="wyn-home-header-action wyn-home-chat-action"
          style={actionStyle}
          type="button"
          aria-label={notificationBadgeCount > 0 ? `การแจ้งเตือน ${notificationBadgeCount} รายการที่ยังไม่ได้อ่าน` : "การแจ้งเตือน"}
          onClick={onOpenNotifications}
        >
          <Bell size={22} strokeWidth={2.05} />
          {notificationBadgeCount > 0 ? <span className="wyn-home-chat-badge" aria-hidden="true" /> : null}
        </button>
      </div>
    </header>
  );
}

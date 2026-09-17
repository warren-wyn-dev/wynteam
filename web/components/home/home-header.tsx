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
    width: 44,
    height: 44,
    borderRadius: 14,
  } as const;

  return (
    <header
      className="wyn-home-header"
      style={{
        height: 56,
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
        <Menu size={25} strokeWidth={2.05} />
      </button>

      <div className="wyn-home-wordmark" style={{ gap: 8 }}>
        <Image
          className="wyn-home-logo"
          style={{ width: 19, height: 19 }}
          src="/wynos_logo_mark.png"
          alt=""
          width={19}
          height={19}
          priority
        />
        <strong
          className="wyn-home-title"
          style={{ fontSize: 19, fontWeight: 700, letterSpacing: "1.7px" }}
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
          <Search size={24} strokeWidth={2.05} />
        </button>
        <button
          className="wyn-home-header-action wyn-home-chat-action"
          style={actionStyle}
          type="button"
          aria-label={notificationBadgeCount > 0 ? `การแจ้งเตือน ${notificationBadgeCount} รายการที่ยังไม่ได้อ่าน` : "การแจ้งเตือน"}
          onClick={onOpenNotifications}
        >
          <Bell size={24} strokeWidth={2.05} />
          {notificationBadgeCount > 0 ? <span className="wyn-home-chat-badge" aria-hidden="true" /> : null}
        </button>
      </div>
    </header>
  );
}

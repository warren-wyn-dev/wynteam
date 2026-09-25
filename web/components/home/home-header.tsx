import Image from "next/image";

import { WynosIcon } from "@/components/ui/wynos-icon";

/**
 * Home header from the approved mobile mockup: WYNOS stays screen-centered
 * while the existing menu, search and notifications functions remain unchanged.
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
      <button
        className="wyn-home-header-action wyn-home-menu-action"
        type="button"
        aria-label="เมนู"
        onClick={onOpenMenu}
      >
        <WynosIcon name="menu" size={23} strokeWidth={1.8} />
      </button>

      <div className="wyn-home-wordmark">
        <Image
          className="wyn-home-logo"
          src="/wynos_logo_mark.png"
          alt=""
          width={27}
          height={27}
          priority
        />
        <strong className="wyn-home-title">WYNOS</strong>
      </div>

      <div className="wyn-home-header-actions">
        <button
          className="wyn-home-header-action"
          type="button"
          aria-label="ค้นหา"
          onClick={onOpenSearch}
        >
          <WynosIcon name="search" size={23} strokeWidth={1.8} />
        </button>
        <button
          className="wyn-home-header-action wyn-home-chat-action"
          type="button"
          aria-label={notificationBadgeCount > 0 ? `การแจ้งเตือน ${notificationBadgeCount} รายการที่ยังไม่ได้อ่าน` : "การแจ้งเตือน"}
          onClick={onOpenNotifications}
        >
          <WynosIcon name="notifications" size={23} strokeWidth={1.8} />
          {notificationBadgeCount > 0 ? <span className="wyn-home-chat-badge" aria-hidden="true" /> : null}
        </button>
      </div>
    </header>
  );
}

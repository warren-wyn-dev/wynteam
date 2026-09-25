"use client";

import Image from "next/image";
import { useEffect } from "react";

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
  suspendScrollChrome = false,
}: {
  notificationBadgeCount: number;
  onOpenMenu: () => void;
  onOpenSearch: () => void;
  onOpenNotifications: () => void;
  suspendScrollChrome?: boolean;
}) {
  // The bottom nav is mounted outside the Home page in the root layout.
  // Toggle a root-scoped class so the top Home chrome and that persistent
  // sibling dock animate together; remove it when Home unmounts so other
  // routes never inherit the hidden state.
  useEffect(() => {
    const root = document.documentElement;
    const hiddenClass = "wyn-home-scroll-hidden";
    root.classList.remove(hiddenClass);

    if (suspendScrollChrome) return;

    let lastY = Math.max(0, window.scrollY);
    let direction = 0;
    let distance = 0;

    const onScroll = () => {
      const y = Math.max(0, window.scrollY);
      const delta = y - lastY;
      lastY = y;

      // Keep both bars accessible near the start of every feed tab,
      // including on pull-to-refresh and iOS overscroll bounce.
      if (y <= 112) {
        root.classList.remove(hiddenClass);
        direction = 0;
        distance = 0;
        return;
      }
      if (Math.abs(delta) < 1) return;

      const nextDirection = delta > 0 ? 1 : -1;
      if (nextDirection !== direction) {
        direction = nextDirection;
        distance = 0;
      }
      distance += Math.abs(delta);

      // Hysteresis prevents the bars from flickering during tiny scroll
      // corrections, while bringing them back quickly on an upward swipe.
      if (direction > 0 && distance >= 32) {
        root.classList.add(hiddenClass);
        distance = 0;
      } else if (direction < 0 && distance >= 14) {
        root.classList.remove(hiddenClass);
        distance = 0;
      }
    };

    window.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      window.removeEventListener("scroll", onScroll);
      root.classList.remove(hiddenClass);
    };
  }, [suspendScrollChrome]);

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

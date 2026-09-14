/* eslint-disable @next/next/no-img-element */
import { Menu, MessageCircle } from "lucide-react";

import { WynosHeader } from "@/components/design-system/WynosHeader";
import { WynosIconButton } from "@/components/design-system/WynosIconButton";

/**
 * Home's header (WYN-159 design system, `WynosHeader` — `.header-row` in the
 * reference: leading icon button, centered brand, trailing action).
 *
 * Deviation from the reference/app-shell doc's default assumption: the
 * reference (and the generic app-shell/home design doc) show Search + Bell
 * as the trailing actions. WYNOS's actual shipped product instead already
 * has Search and Notifications as their own bottom-nav destinations, and
 * Home's header trailing action is a single Chat icon with an unread badge
 * (opens `/chat`) — an existing, real, frequently-used behavior. Per
 * "preserve existing behavior exactly, this is a visual migration only",
 * that existing leading-menu + brand + chat-with-badge structure is kept;
 * only the visual language (icon color, sizing, hit area) is restyled to
 * the v2 monochrome tokens. Flagged in the WYN-159 report for Founder
 * awareness since it differs from the design doc's literal assumption.
 */
export function HomeHeader({
  chatBadgeCount,
  onOpenMenu,
  onOpenChat,
}: {
  chatBadgeCount: number;
  onOpenMenu: () => void;
  onOpenChat: () => void;
}) {
  return (
    <WynosHeader
      leading={<WynosIconButton icon={<Menu />} aria-label="เมนู" onClick={onOpenMenu} />}
      center={
        <>
          <img src="/wynos_logo_mark.png" alt="" width={22} height={22} />
          <strong>WYNOS</strong>
        </>
      }
      trailing={
        <WynosIconButton
          icon={<MessageCircle />}
          aria-label="แชท"
          onClick={onOpenChat}
          badge={chatBadgeCount > 0 ? (chatBadgeCount > 9 ? "9+" : String(chatBadgeCount)) : null}
        />
      }
    />
  );
}
